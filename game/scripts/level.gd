extends Node2D
## Тестовый уровень из серых блоков. Карту удобно править прямо здесь, символами:
##   #  камень        ^  шипы (возврат к точке сохранения)
##   P  старт Нокса   C  точка сохранения
##   L  фонарь для Толчка света
##   G  финиш прототипа

const TILE := 32

const MAP := [
	"#..............................................................................................#",
	"#..............................................................................................#",
	"#...........................C..................................................................#",
	"#.........................#####................................................................#",
	"#.........................#####................................................................#",
	"#.........................#####..............C.................................................#",
	"#.........................#####...........#########.........L..........L.......................#",
	"#.........................#####...........#########............................................#",
	"#.........................#####...........#########...L...........L.......................G....#",
	"#................##############...........#########........................#####################",
	"#................##############...........#########........................#####################",
	"#................##############...........#########........................#####################",
	"#................##############...........#########........................#####################",
	"#................##############...........#########........................#####################",
	"#............##################...........#########........................#####################",
	"#............##################...........#########........................#####################",
	"#........###.##################...........#########........................#####################",
	"#..P.....###.##################...........#########........................#####################",
	"###############################...........#########........................#####################",
	"###############################^^^^^^^^^^^#########^^^^^^^^^^^^^^^^^^^^^^^^#####################",
	"################################################################################################",
	"################################################################################################",
]

const HINTS := [
	[Vector2i(4, 15), "A/D — бег, Пробел — прыжок"],
	[Vector2i(12, 11), "Прыгни на стену и держи направление к ней.\nЖми Пробел снова и снова — Нокс взбежит по стене"],
	[Vector2i(19, 6), "Отпусти направление и прыгни — Нокс оттолкнётся от стены"],
	[Vector2i(27, 0), "В прыжке зажми K: время замедлится.\nЦелься стрелками и отпусти — Нокс оттолкнётся от Люкса"],
	[Vector2i(45, 3), "От фонарей можно отталкиваться сколько угодно.\nЛюкс заряжается, когда ты на земле или на стене"],
]

var player: Nox
var lux: Lux

var _solid_rects: Array[Rect2] = []
var _spike_rects: Array[Rect2] = []
var _won := false
var _hud: Label


func _ready() -> void:
	InputSetup.ensure()
	_build_map()
	_build_hud()


func _build_map() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	var start := Vector2.ZERO
	for y in MAP.size():
		var row: String = MAP[y]
		var run_start := -1
		for x in row.length() + 1:
			var c := row[x] if x < row.length() else "."
			if c == "#":
				if run_start < 0:
					run_start = x
				continue
			if run_start >= 0:
				_add_solid(body, Rect2(run_start * TILE, y * TILE, (x - run_start) * TILE, TILE))
				run_start = -1
			var center := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			match c:
				"^":
					_add_area(Rect2(x * TILE, y * TILE + TILE / 2.0, TILE, TILE / 2.0), "_on_spikes")
					_spike_rects.append(Rect2(x * TILE, y * TILE, TILE, TILE))
				"P":
					start = center
				"C":
					_add_checkpoint(center)
				"L":
					var lantern := Lantern.new()
					lantern.position = center
					add_child(lantern)
				"G":
					_add_area(Rect2(center - Vector2(TILE, TILE * 2), Vector2(TILE * 2, TILE * 3)), "_on_goal")

	player = Nox.new()
	player.position = start
	add_child(player)
	lux = Lux.new()
	lux.position = start + Vector2(-30, -40)
	lux.target = player
	player.lux = lux
	add_child(lux)

	for hint in HINTS:
		var label := Label.new()
		label.text = hint[1]
		label.position = Vector2(hint[0]) * TILE
		label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.95, 0.85))
		label.add_theme_font_size_override("font_size", 13)
		add_child(label)
	queue_redraw()


func _add_solid(body: StaticBody2D, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
	_solid_rects.append(rect)


func _add_area(rect: Rect2, handler: String) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	area.position = rect.get_center()
	area.add_child(shape)
	area.body_entered.connect(Callable(self, handler))
	add_child(area)
	return area


func _add_checkpoint(at: Vector2) -> void:
	var area := _add_area(Rect2(at - Vector2(TILE, TILE), Vector2(TILE * 2, TILE * 2)), "_on_checkpoint")
	area.set_meta("spawn", at)


func _on_spikes(body: Node2D) -> void:
	if body is Nox:
		body.respawn.call_deferred()


func _on_checkpoint(body: Node2D) -> void:
	if body is Nox:
		for area in get_children():
			if area is Area2D and area.has_meta("spawn") and area.overlaps_body(body):
				body.spawn_point = area.get_meta("spawn")


func _on_goal(body: Node2D) -> void:
	if body is Nox and not _won:
		_won = true
		_hud.text = "Прототип пройден! R — начать с точки сохранения"


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.text = "Нокс и Люкс — прототип движения · R — вернуться к точке сохранения"
	_hud.add_theme_font_size_override("font_size", 14)
	layer.add_child(_hud)


func _draw() -> void:
	for rect in _solid_rects:
		draw_rect(rect, Color("3A3550"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Color("5B5F6B"))
	for rect in _spike_rects:
		for i in 2:
			var x0 := rect.position.x + i * TILE / 2.0
			var base := rect.end.y
			draw_colored_polygon(PackedVector2Array([
				Vector2(x0, base), Vector2(x0 + TILE / 4.0, rect.position.y + 6), Vector2(x0 + TILE / 2.0, base)
			]), Color("7A1E2C"))
	var goal_rows := MAP.size()
	for y in goal_rows:
		var x: int = MAP[y].find("G")
		if x >= 0:
			draw_circle(Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0), 12.0, Color("A8D672"))
