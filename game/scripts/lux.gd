class_name Lux
extends Node2D
## Люкс — дух Света. Летает рядом с Ноксом, от него можно оттолкнуться один раз в воздухе.
## Заряд восстанавливается, когда Нокс стоит на земле или держится за стену.

@export var follow_offset := Vector2(-34, -46)
@export var follow_speed := 7.0
@export var bob_height := 5.0

var target: Nox
var charged := true

var _time := 0.0
var _kick := Vector2.ZERO
var _trail: CPUParticles2D


func _ready() -> void:
	add_to_group("pushable")
	z_index = 5
	# Шлейф искр остаётся в мире, а не летит вместе с Люксом.
	_trail = CPUParticles2D.new()
	_trail.amount = 24
	_trail.lifetime = 0.7
	_trail.local_coords = false
	_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = 6.0
	_trail.gravity = Vector2(0, -20)
	_trail.initial_velocity_max = 10.0
	_trail.scale_amount_min = 1.0
	_trail.scale_amount_max = 2.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.95, 0.7, 0.9))
	fade.set_color(1, Color(0.97, 0.84, 0.45, 0.0))
	_trail.color_ramp = fade
	add_child(_trail)


func _process(delta: float) -> void:
	if target == null:
		return
	_time += delta
	# Пока Нокс целится, Люкс замирает: от него отталкиваются.
	if not target.is_aiming():
		var offset := Vector2(follow_offset.x * target.facing, follow_offset.y)
		var goal := target.global_position + offset + Vector2(0, sin(_time * 3.0) * bob_height)
		global_position = global_position.lerp(goal + _kick, clampf(follow_speed * delta, 0.0, 1.0))
	_kick = _kick.lerp(Vector2.ZERO, clampf(5.0 * delta, 0.0, 1.0))
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
	# Люкс — цилинь, сейчас бестелесный: в сиянии видна только голова
	# с раздвоенным рогом и гривой из пламени рассвета.
	var glow := Color("F7D774")
	var core := Color("FFF6E0")
	var flame := Color("FFB347")
	if not charged:
		glow = Color(0.6, 0.6, 0.7)
		core = Color(0.8, 0.8, 0.85)
		flame = Color(0.7, 0.7, 0.78)
	for i in range(4, 0, -1):
		draw_circle(Vector2.ZERO, 6.0 + i * 5.0, Color(glow, 0.08))
	var f := float(target.facing) if target else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(f, 1.0))
	# Грива: языки пламени за головой, дрожат.
	for i in 4:
		var base := Vector2(-4 - i * 2.0, -5 + i * 3.5)
		var h := 7.0 + sin(_time * 9.0 + i * 1.7) * 2.0
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(2, -2), base + Vector2(-h, -h * 0.4), base + Vector2(1, 3),
		]), Color(flame, 0.85))
	# Голова оленя-дракона: вытянутая морда вперёд.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -6), Vector2(3, -7), Vector2(10, -3), Vector2(12, 1),
		Vector2(8, 3), Vector2(0, 5), Vector2(-5, 3),
	]), core)
	# Чешуйки на щеке и глаз.
	draw_arc(Vector2(-1, 0), 2.5, 0.0, PI, 6, Color(glow, 0.9), 1.0)
	draw_arc(Vector2(2, 2), 2.5, 0.0, PI, 6, Color(glow, 0.9), 1.0)
	draw_circle(Vector2(4, -3), 1.3, Color("6B4E71"))
	# Раздвоенный светящийся рог.
	draw_line(Vector2(0, -7), Vector2(-2, -15), glow, 2.0)
	draw_line(Vector2(-1, -11), Vector2(3, -15), glow, 1.5)
	draw_line(Vector2(-2, -15), Vector2(-5, -17), glow, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
