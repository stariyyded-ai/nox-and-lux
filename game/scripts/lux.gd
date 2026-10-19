class_name Lux
extends Node2D
## Люкс — дух Света. Летает рядом с Ноксом, от него можно оттолкнуться один раз в воздухе.
## Заряд восстанавливается, когда Нокс стоит на земле или держится за стену.
## Сейчас Люкс бестелесный цилинь: светящийся огонёк, в котором угадываются рог и грива.

@export var follow_offset := Vector2(-34, -46)
@export var follow_speed := 7.0
@export var bob_height := 5.0

const GOLD := Color("FFE08A")
const CORE := Color("FFFBEA")
const DIM := Color(0.65, 0.68, 0.8)

var target: Nox
var charged := true

var _time := 0.0
var _kick := Vector2.ZERO
var _trail: CPUParticles2D
var _history: Array[Vector2] = []  ## прошлые позиции в мире — для светящегося хвоста


func _ready() -> void:
	add_to_group("pushable")
	z_index = 5
	# Искры остаются в мире, а не летят вместе с Люксом.
	_trail = CPUParticles2D.new()
	_trail.amount = 28
	_trail.lifetime = 0.9
	_trail.local_coords = false
	_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = 5.0
	_trail.gravity = Vector2(0, -15)
	_trail.initial_velocity_max = 8.0
	_trail.scale_amount_min = 1.0
	_trail.scale_amount_max = 2.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.97, 0.8, 0.9))
	fade.set_color(1, Color(1.0, 0.85, 0.5, 0.0))
	_trail.color_ramp = fade
	add_child(_trail)


func _process(delta: float) -> void:
	if target == null:
		return
	_time += delta
	# Пока Нокс целится, Люкс замирает: от него отталкиваются.
	if not target.is_aiming():
		var offset := Vector2(follow_offset.x * target.facing, follow_offset.y)
		var goal := target.global_position + offset + Vector2(sin(_time * 1.7) * 3.0, sin(_time * 3.0) * bob_height)
		global_position = global_position.lerp(goal + _kick, clampf(follow_speed * delta, 0.0, 1.0))
	_kick = _kick.lerp(Vector2.ZERO, clampf(5.0 * delta, 0.0, 1.0))
	_history.push_front(global_position)
	if _history.size() > 14:
		_history.pop_back()
	queue_redraw()


func can_push() -> bool:
	return charged


func on_pushed(direction: Vector2) -> void:
	charged = false
	_kick = direction * 60.0
	_trail.emitting = false


func recharge() -> void:
	charged = true
	_trail.emitting = true


func _draw() -> void:
	var glow := GOLD if charged else DIM
	var pulse := 0.85 + 0.15 * sin(_time * 4.0)
	# Хвост из света тянется за Люксом по его недавнему пути.
	for i in range(_history.size() - 1, 0, -1):
		var t := float(i) / _history.size()
		Fx.glow(self, _history[i] - global_position, lerpf(9.0, 3.0, t), Color(glow, 0.35 * (1.0 - t)))
	Fx.glow(self, Vector2.ZERO, 44.0 * pulse, Color(glow, 0.35))
	Fx.glow(self, Vector2.ZERO, 18.0, Color(glow, 0.8))
	# Внутри огонька угадывается цилинь: раздвоенный рог и языки гривы.
	var f := float(target.facing) if target else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(f, 1.0))
	var horn := Color(CORE, 0.85)
	draw_polyline(PackedVector2Array([Vector2(1, -3), Vector2(-1, -9), Vector2(-4, -12)]), horn, 1.4, true)
	draw_line(Vector2(-0.5, -7), Vector2(2.5, -11), horn, 1.2, true)
	for i in 3:
		var a := 2.3 + i * 0.45 + sin(_time * 7.0 + i) * 0.12
		draw_line(Vector2(-2, 0), Vector2(-2, 0) + Vector2(cos(a), sin(a) * 0.8) * (7.0 - i), Color(glow, 0.7), 1.6, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 4.5, CORE if charged else Color(0.9, 0.9, 0.95))
