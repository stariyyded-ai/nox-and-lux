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
	# Светящийся бутон на тонком стебле, свисающем сверху.
	var pulse := 0.5 + 0.5 * sin(_time * 2.0)
	draw_line(Vector2(0, -60), Vector2(sin(_time) * 1.5, -9), Color("17313D"), 2.0, true)
	Fx.glow(self, Vector2.ZERO, 46.0 + 6.0 * pulse + 30.0 * _flash, Color(0.6, 0.95, 1.0, 0.35 + 0.3 * _flash))
	Fx.glow(self, Vector2.ZERO, 16.0, Color(0.85, 1.0, 1.0, 0.9))
	for i in 3:
		var a := -PI * 0.5 + (i - 1) * 0.7
		draw_colored_polygon(Fx.teardrop(Vector2.ZERO, Vector2(cos(a), sin(a)) * 11.0, 3.5), Color("2C6E78"))
	draw_circle(Vector2(0, 1), 4.5, Color("E8FFFF"))
