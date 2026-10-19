class_name NoxVisual
extends Node2D
## Рисованный Нокс в духе Ori: маленький юный баку с большой головой и светящимися глазами,
## коротким мягким хоботком, рожками, пушистым хвостом и обломком маски на лбу.
## Сам ничего не решает: только смотрит на состояние Нокса и подбирает позу.
## Позже его легко заменить спрайтами или скелетной анимацией художника.

const BODY := Color("3B2F5C")
const SHADE := Color("281F42")
const RIM := Color("8C7BD6")
const SOFT := Color("5A4A8C")
const EYE := Color("FFD36B")
const MASK := Color("F1ECFF")
const AURA := Color(0.55, 0.45, 0.95, 0.35)
const FEET_Y := 19.0  ## низ капсулы столкновений

var nox: Nox

var _time := 0.0
var _run_phase := 0.0
var _squash := 0.0  ## >0 — сплющен (приземление), <0 — вытянут (прыжок)
var _was_on_floor := true
var _prev_vy := 0.0
var _blink := 0.0
var _next_blink := 2.5
var _lag := Vector2.ZERO  ## насколько хвост и уши отстают от движения
var _dust: CPUParticles2D


func _ready() -> void:
	nox = get_parent() as Nox
	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = 12
	_dust.lifetime = 0.6
	_dust.explosiveness = 0.9
	_dust.local_coords = false
	_dust.position = Vector2(0, FEET_Y)
	_dust.direction = Vector2.UP
	_dust.spread = 75.0
	_dust.initial_velocity_min = 25.0
	_dust.initial_velocity_max = 60.0
	_dust.gravity = Vector2(0, 60)
	_dust.scale_amount_min = 1.5
	_dust.scale_amount_max = 3.0
	var fade := Gradient.new()
	fade.set_color(0, Color(0.8, 0.9, 1.0, 0.7))
	fade.set_color(1, Color(0.6, 0.8, 1.0, 0.0))
	_dust.color_ramp = fade
	add_child(_dust)


func _process(delta: float) -> void:
	if nox == null:
		return
	_time += delta
	var v := nox.velocity
	var on_floor := nox.is_on_floor()

	if on_floor:
		_run_phase += absf(v.x) / nox.max_speed * delta * 13.0
	if on_floor and not _was_on_floor and _prev_vy > 250.0:
		_squash = clampf(_prev_vy / 1000.0, 0.12, 0.28)
		_dust.restart()
	elif v.y < -300.0 and _prev_vy >= -50.0:
		_squash = -0.18
		if on_floor or _was_on_floor:
			_dust.restart()
	_squash = lerpf(_squash, 0.0, clampf(10.0 * delta, 0.0, 1.0))
	_was_on_floor = on_floor
	_prev_vy = v.y

	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.12
		_next_blink = randf_range(2.0, 4.5)
	_blink -= delta

	var lag_goal := Vector2(-absf(v.x), -v.y * 0.5) * 0.025
	_lag = _lag.lerp(lag_goal.limit_length(10.0), clampf(8.0 * delta, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	if nox == null:
		return
	var v := nox.velocity
	var on_floor := nox.is_on_floor()
	var sliding := nox.wall_side != 0 and not on_floor
	var running := on_floor and absf(v.x) > 20.0
	var speed01 := clampf(absf(v.x) / nox.max_speed, 0.0, 1.0)

	# Мягкое сияние вокруг Нокса; при Толчке света оно золотое и ярче.
	Fx.glow(self, Vector2(0, -2), 38.0, AURA)
	if nox.is_aiming():
		Fx.glow(self, Vector2(0, -2), 60.0, Color(1.0, 0.85, 0.45, 0.45))

	var bob := 0.0
	if running:
		bob = -absf(sin(_run_phase)) * 2.0
	elif on_floor:
		bob = sin(_time * 2.2) * 0.7  # дыхание
	var lean := clampf(v.x / nox.max_speed, -1.0, 1.0) * 0.14 if on_floor else 0.0
	var sx := 1.0 + _squash * 0.6
	var sy := 1.0 - _squash
	draw_set_transform(Vector2(0, FEET_Y), lean, Vector2(sx * nox.facing, sy))

	var hip := Vector2(-1, -10 + bob)
	var chest := Vector2(1, -18 + bob)
	var head := Vector2(3, -29 + bob)
	if not on_floor:
		head.y += clampf(v.y / 900.0, -1.0, 1.0) * 1.5

	_draw_tail(hip, v, on_floor)
	_draw_limbs(hip, chest, v, on_floor, sliding, running, speed01, true)
	draw_colored_polygon(Fx.ellipse(chest + Vector2(-0.5, 3.5), Vector2(6.0, 8.5), 0.2), SOFT)
	draw_colored_polygon(Fx.ellipse(chest + Vector2(0, 3.5), Vector2(5.5, 8.0), 0.2), BODY)
	draw_colored_polygon(Fx.ellipse(chest + Vector2(2.2, 5), Vector2(2.6, 5.0), 0.2), SOFT)  # светлое брюшко
	_draw_limbs(hip, chest, v, on_floor, sliding, running, speed01, false)
	_draw_head(head, v)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tail(hip: Vector2, v: Vector2, on_floor: bool) -> void:
	# Пушистый хвост одной плавной лентой, к кончику толще и светлее.
	var lift := 0.0 if on_floor else clampf(v.y / 700.0, -0.6, 0.7)
	var sway := sin(_time * 2.6) * 0.18
	var pts: Array[Vector2] = []
	for i in 9:
		var t := i / 8.0
		var ang := PI * 1.05 - t * (1.0 + lift) + sway * t
		pts.append(hip + Vector2(-4, 1) + Vector2(cos(ang), -sin(ang)) * (t * 19.0) + _lag * t)
	var tip := pts[pts.size() - 1]
	draw_colored_polygon(Fx.ribbon(pts, 4.0, 9.0), SOFT)
	draw_circle(tip, 4.6, SOFT)
	draw_colored_polygon(Fx.ribbon(pts, 3.0, 7.0), BODY)
	draw_circle(tip, 3.6, RIM)
	Fx.glow(self, tip, 11.0, Color(RIM, 0.7))


func _draw_limbs(hip: Vector2, chest: Vector2, v: Vector2, on_floor: bool, sliding: bool, running: bool, speed01: float, back: bool) -> void:
	# back = дальние лапы: темнее и за телом.
	var col := SHADE if back else BODY
	var phase := _run_phase + (PI if back else 0.0)
	# Задняя лапа (нога).
	var leg_hip := hip + Vector2(-1.5 if back else 1.5, 0)
	var foot := Vector2(leg_hip.x, 0)
	var knee := (leg_hip + foot) * 0.5 + Vector2(2, 0)
	if sliding:
		foot = leg_hip + Vector2(6, 5 if back else 8)
		knee = leg_hip + Vector2(7, 0)
	elif not on_floor:
		if v.y < 0.0:
			foot = leg_hip + Vector2(-3 if back else 1, 6)
			knee = leg_hip + Vector2(4, 3)
		else:
			foot = leg_hip + Vector2(-2 if back else 1, 10 + sin(_time * 9.0 + (1.0 if back else 0.0)))
			knee = leg_hip + Vector2(1, 5)
	elif running:
		foot = Vector2(leg_hip.x + sin(phase) * 8.0 * speed01, -maxf(cos(phase), 0.0) * 5.0 * speed01)
		knee = (leg_hip + foot) * 0.5 + Vector2(3, -1)
	draw_polyline(PackedVector2Array([leg_hip, knee, foot]), col, 3.6, true)
	draw_colored_polygon(Fx.ellipse(foot + Vector2(1.5, -1), Vector2(3.0, 1.8)), col)
	# Передняя лапка (как ручка у Ori).
	var shoulder := chest + Vector2(2 if back else 4, -1)
	var paw := shoulder + Vector2(2, 7)
	if sliding:
		paw = shoulder + Vector2(9, -4 if back else 0)
	elif not on_floor:
		paw = shoulder + (Vector2(4, -6) if v.y < 0.0 else Vector2(6, 2))
	elif running:
		paw = shoulder + Vector2(-sin(phase) * 5.0 * speed01 + 2, 6)
	draw_line(shoulder, paw, col, 3.0, true)
	draw_circle(paw, 1.9, col)


func _draw_head(head: Vector2, v: Vector2) -> void:
	# Круглые ушки отстают при беге и прыжке.
	var ear_lag := _lag * 0.25
	draw_colored_polygon(Fx.ellipse(head + Vector2(-8, -7) + ear_lag, Vector2(3.2, 4.6), -0.6), SHADE)
	draw_colored_polygon(Fx.ellipse(head + Vector2(-6, -9) + ear_lag, Vector2(3.4, 4.8), -0.5), BODY)
	draw_colored_polygon(Fx.ellipse(head + Vector2(-5.6, -8.6) + ear_lag, Vector2(1.6, 2.6), -0.5), SOFT)
	# Маленькие светлые рожки.
	draw_colored_polygon(Fx.teardrop(head + Vector2(0, -9), head + Vector2(-2, -16), 2.0), MASK.darkened(0.15))
	draw_colored_polygon(Fx.teardrop(head + Vector2(4, -9), head + Vector2(4, -16), 2.0), MASK)
	# Голова: светлая кромка сзади сверху, как у Ori.
	draw_circle(head + Vector2(-1.2, -1.2), 10.4, RIM)
	draw_circle(head + Vector2(0.3, 0.3), 10.4, BODY)
	draw_colored_polygon(Fx.ellipse(head + Vector2(4, 3), Vector2(6, 4.5)), SOFT)  # мордочка
	# Короткий мягкий хоботок с завитком на конце.
	var swing := sin(_time * 3.0) * 0.12 + clampf(v.y / 900.0, -0.5, 0.5) * 0.4
	var trunk: Array[Vector2] = []
	for i in 7:
		var t := i / 6.0
		var ang := -0.1 + t * (1.9 + swing)
		trunk.append(head + Vector2(9, 1) + Vector2(cos(ang), sin(ang)) * (2.0 + t * 6.0) + Vector2(t * 2.0, 0))
	draw_colored_polygon(Fx.ribbon(trunk, 6.0, 2.6), SOFT)
	draw_circle(trunk[trunk.size() - 1], 1.6, SOFT)
	# Большой светящийся глаз без зрачка.
	var eye := head + Vector2(4.5, -1.5)
	Fx.glow(self, eye, 11.0, Color(EYE, 0.55))
	var open := 0.15 if _blink > 0.0 else 1.0
	draw_colored_polygon(Fx.ellipse(eye, Vector2(3.0, 3.9 * open), -0.15), EYE)
	if open > 0.5:
		draw_circle(eye + Vector2(1.0, -1.4), 1.0, Color.WHITE)
	# Обломок маски на лбу: гладкий сверху, с неровным краем скола снизу.
	var shard := PackedVector2Array([
		head + Vector2(-5, -6), head + Vector2(-1, -9.5), head + Vector2(5, -9.2), head + Vector2(8.5, -6),
		head + Vector2(6, -5.2), head + Vector2(4, -6.4), head + Vector2(1.5, -4.6), head + Vector2(-1.5, -6), head + Vector2(-3.5, -4.8),
	])
	Fx.glow(self, head + Vector2(1.5, -7), 10.0, Color(MASK, 0.3))
	draw_colored_polygon(shard, MASK)
	draw_line(head + Vector2(2, -9.3), head + Vector2(1.2, -6.5), SOFT, 0.8, true)
