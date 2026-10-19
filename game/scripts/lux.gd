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


func _ready() -> void:
	add_to_group("pushable")
	z_index = 5


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


func recharge() -> void:
	charged = true


func _draw() -> void:
	var glow := Color("F7D774")
	var core := Color("FFF6E0")
	if not charged:
		glow = Color(0.6, 0.6, 0.7)
		core = Color(0.8, 0.8, 0.85)
	for i in range(4, 0, -1):
		draw_circle(Vector2.ZERO, 6.0 + i * 5.0, Color(glow, 0.08))
	draw_circle(Vector2.ZERO, 7.0, core)
