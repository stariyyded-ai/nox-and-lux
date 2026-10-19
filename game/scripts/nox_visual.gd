class_name NoxVisual
extends Node2D
## Рисованный Нокс — юный баку: хоботок, тигриные лапы, рожки, полосатый хвост,
## обломок маски и шарф. Рисуется кодом, поэтому позже его легко заменить спрайтами художника.
## Сам ничего не решает: только смотрит на состояние Нокса и подбирает позу.

const BODY := Color("2B2440")
const FUR := Color("4A3F6B")
const RIM := Color("8E7CC3")
const PALE := Color("E9E4F5")
const EYE := Color("F2C14E")
const SCARF := Color("6B4E71")
const FEET_Y := 19.0  ## низ капсулы столкновений

var nox: Nox

var _time := 0.0
var _run_phase := 0.0
var _squash := 0.0  ## >0 — сплющен (приземление), <0 — вытянут (прыжок)
var _was_on_floor := true
var _prev_vy := 0.0
var _blink := 0.0
var _next_blink := 2.5
var _scarf_lag := Vector2.ZERO
var _dust: CPUParticles2D


func _ready() -> void:
	nox = get_parent() as Nox
	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = 10
	_dust.lifetime = 0.45
	_dust.explosiveness = 0.9
	_dust.local_coords = false
	_dust.position = Vector2(0, FEET_Y)
	_dust.direction = Vector2.UP
	_dust.spread = 80.0
	_dust.initial_velocity_min = 30.0
	_dust.initial_velocity_max = 70.0
	_dust.gravity = Vector2(0, 120)
	_dust.scale_amount_min = 2.0
	_dust.scale_amount_max = 4.0
	_dust.color = Color(0.75, 0.7, 0.85, 0.5)
	add_child(_dust)


func _process(delta: float) -> void:
	if nox == null:
		return
	_time += delta
	var v := nox.velocity
	var on_floor := nox.is_on_floor()

	if on_floor:
		_run_phase += absf(v.x) / nox.max_speed * delta * 14.0
	if on_floor and not _was_on_floor and _prev_vy > 250.0:
		_squash = clampf(_prev_vy / 900.0, 0.15, 0.35)
		_dust.restart()
	elif v.y < -300.0 and _prev_vy >= -50.0:
		_squash = -0.22
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

	# Шарф и хвост отстают от движения, как будто их тянет ветер.
	var lag_goal := Vector2(-v.x, -v.y * 0.5) * 0.03
	_scarf_lag = _scarf_lag.lerp(lag_goal.limit_length(14.0), clampf(8.0 * delta, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	if nox == null:
		return
	var v := nox.velocity
	var on_floor := nox.is_on_floor()
	var sliding := nox.wall_side != 0 and not on_floor
	var speed01 := clampf(absf(v.x) / nox.max_speed, 0.0, 1.0)
	var f := float(nox.facing)

	# Подсветка при Толчке света рисуется в мировых осях, до поворота.
	if nox.is_aiming():
		for i in 3:
			draw_circle(Vector2(0, -2), 26.0 + i * 8.0, Color(0.97, 0.84, 0.45, 0.10))

	var bob := 0.0
	if on_floor and speed01 > 0.1:
		bob = -absf(sin(_run_phase)) * 2.5
	elif on_floor:
		bob = sin(_time * 2.2) * 0.8  # дыхание
	var lean := clampf(v.x / nox.max_speed, -1.0, 1.0) * 0.12 if on_floor else 0.0
	var sx := 1.0 + _squash * 0.6
	var sy := 1.0 - _squash
	draw_set_transform(Vector2(0, FEET_Y), lean, Vector2(sx * f, sy))

	var breathe := sin(_time * 2.2) * 0.6 if speed01 < 0.1 else 0.0
	var body_c := Vector2(0, -14 + bob)
	var head_c := Vector2(11, -27 + bob + breathe * 0.5)
	if sliding:
		head_c += Vector2(-1, 2)

	_draw_scarf_tails(head_c)
	_draw_tail(body_c, v, on_floor)
	_draw_legs(body_c, v, on_floor, sliding, speed01, true)
	_draw_ellipse(body_c, Vector2(14, 9.5 + breathe * 0.4), BODY)
	_draw_ellipse(body_c + Vector2(2, 3), Vector2(10, 5), FUR)
	# Тигриные полоски на спине.
	for i in 3:
		var sx0 := body_c.x - 7.0 + i * 5.0
		draw_line(Vector2(sx0, body_c.y - 9), Vector2(sx0 + 2, body_c.y - 4), FUR, 2.0)
	_draw_legs(body_c, v, on_floor, sliding, speed01, false)
	draw_circle(head_c + Vector2(-6, 6), 5.0, SCARF)  # узел шарфа на шее
	_draw_head(head_c, v)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tail(body_c: Vector2, v: Vector2, on_floor: bool) -> void:
	var base := body_c + Vector2(-12, -3)
	var lift := 0.0 if on_floor else clampf(v.y / 600.0, -0.5, 0.8)
	var sway := sin(_time * 3.0) * 0.25 + _scarf_lag.x * 0.04
	var pts: Array[Vector2] = []
	for i in 6:
		var t := i / 5.0
		var ang := PI + 0.9 + t * (1.3 + lift) + sway * t
		pts.append(base + Vector2(cos(ang), sin(ang)) * (4.0 + t * 12.0) + Vector2(-t * 5.0, 0))
	for i in pts.size():
		var r := 5.0 - i * 0.45
		var c := FUR if i % 2 == 0 else BODY
		if i == pts.size() - 1:
			c = PALE
		draw_circle(pts[i], r, c)


func _draw_legs(body_c: Vector2, v: Vector2, on_floor: bool, sliding: bool, speed01: float, back: bool) -> void:
	# back = дальние лапы (темнее, рисуются за телом).
	var col := BODY.darkened(0.25) if back else BODY
	var hips := [Vector2(-8, 3), Vector2(7, 3)]
	for k in 2:
		var hip: Vector2 = body_c + hips[k]
		var foot := Vector2(hip.x, 0)
		var phase := _run_phase + (PI if (k == 0) != back else 0.0) + (0.6 if back else 0.0)
		if sliding:
			# Передние лапы упираются в стену, задние поджаты.
			foot = hip + (Vector2(10, -6) if k == 1 else Vector2(3, 6))
		elif not on_floor:
			if v.y < 0.0:
				foot = hip + Vector2(-2 + k * 3, 5)  # поджал лапы
			else:
				foot = hip + Vector2(k * 3 - 1, 9 + sin(_time * 10.0 + k) * 1.0)
		elif speed01 > 0.1:
			foot = Vector2(hip.x + sin(phase) * 7.0 * speed01, -maxf(cos(phase), 0.0) * 5.0 * speed01)
		draw_line(hip, foot, col, 6.0)
		draw_circle(foot, 3.5, col)
		if not back:
			draw_circle(foot + Vector2(1.5, -0.5), 1.2, RIM)


func _draw_scarf_tails(head_c: Vector2) -> void:
	# Концы шарфа рисуются за телом и развеваются назад и вверх.
	var neck := head_c + Vector2(-6, 6)
	var flap := sin(_time * 8.0) * 2.0
	var end1 := neck + Vector2(-16, -4 + flap) + _scarf_lag
	var end2 := neck + Vector2(-13, 1 - flap) + _scarf_lag * 0.7
	draw_colored_polygon(PackedVector2Array([neck + Vector2(0, -3), end1, end1 + Vector2(1, 4), neck + Vector2(1, 2)]), SCARF)
	draw_colored_polygon(PackedVector2Array([neck + Vector2(0, 0), end2, end2 + Vector2(2, 3), neck + Vector2(2, 4)]), SCARF.darkened(0.2))


func _draw_head(head_c: Vector2, v: Vector2) -> void:
	# Рожки и ушко.
	draw_colored_polygon(PackedVector2Array([head_c + Vector2(-5, -6), head_c + Vector2(-8, -14), head_c + Vector2(-2, -8)]), PALE)
	draw_colored_polygon(PackedVector2Array([head_c + Vector2(0, -8), head_c + Vector2(1, -16), head_c + Vector2(4, -8)]), PALE)
	draw_colored_polygon(PackedVector2Array([head_c + Vector2(-8, -3), head_c + Vector2(-12, -9), head_c + Vector2(-4, -6)]), FUR)
	draw_circle(head_c, 9.5, RIM)
	draw_circle(head_c + Vector2(-0.8, 0.6), 9.0, BODY)
	# Хоботок: изогнутая линия, качается при беге и тянется вверх в прыжке.
	var swing := sin(_time * 4.0) * 0.15 + clampf(v.y / 900.0, -0.5, 0.5) * 0.6
	var trunk := PackedVector2Array()
	for i in 6:
		var t := i / 5.0
		var ang := 0.3 + t * (1.4 + swing)
		trunk.append(head_c + Vector2(7, 2) + Vector2(cos(ang), sin(ang)) * (t * 10.0) + Vector2(t * 4.0, 0))
	draw_polyline(trunk, BODY, 5.0)
	draw_polyline(trunk, FUR, 2.0)
	draw_circle(trunk[trunk.size() - 1], 2.5, BODY)
	# Обломок маски: светлый полумесяц с трещиной.
	var mask := PackedVector2Array([
		head_c + Vector2(-3, -8), head_c + Vector2(6, -8), head_c + Vector2(9, -3),
		head_c + Vector2(8, 1), head_c + Vector2(4, -1), head_c + Vector2(2, -4), head_c + Vector2(-1, -3),
	])
	draw_colored_polygon(mask, PALE)
	draw_polyline(PackedVector2Array([head_c + Vector2(2, -8), head_c + Vector2(3, -5), head_c + Vector2(1, -3)]), FUR, 1.0)
	# Глаз в прорези маски, иногда моргает.
	var eye := head_c + Vector2(5, -3.5)
	if _blink > 0.0:
		draw_line(eye + Vector2(-2, 0), eye + Vector2(2, 0), EYE, 1.5)
	else:
		draw_circle(eye, 2.2, EYE)
		draw_circle(eye + Vector2(0.7, -0.6), 0.7, Color.WHITE)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
