class_name Lantern
extends Node2D
## Фонарь-светлячок: от него можно отталкиваться сколько угодно раз.

var _time := 0.0
var _flash := 0.0


func _ready() -> void:
	add_to_group("pushable")


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta * 3.0, 0.0)
	queue_redraw()


func on_pushed(_direction: Vector2) -> void:
	_flash = 1.0


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 2.0)
	for i in range(3, 0, -1):
		draw_circle(Vector2.ZERO, 8.0 + i * 6.0, Color(0.96, 0.9, 0.66, 0.06 + 0.04 * pulse + 0.1 * _flash))
	draw_circle(Vector2.ZERO, 6.0, Color("F5E6A8"))
