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
	var bg := ForestBackground.new()
	bg.level_size = Vector2(MAP[0].length(), MAP.size()) * TILE
	add_child(bg)
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
		label.add_theme_color_override("font_color", Color(0.86, 0.96, 0.95, 0.9))
		label.add_theme_color_override("font_shadow_color", Color(0.02, 0.08, 0.12, 0.8))
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


func _is_solid(x: int, y: int) -> bool:
	if y < 0 or y >= MAP.size() or x < 0 or x >= MAP[y].length():
		return true
	return MAP[y][x] == "#"


func _draw() -> void:
	# Земля — тёмные силуэты переднего плана, сверху мох и травинки, как в Ori.
	for rect in _solid_rects:
		draw_rect(rect, Color("0C1A24"))
	for y in MAP.size():
		for x in MAP[y].length():
			if not _is_solid(x, y):
				continue
			var pos := Vector2(x * TILE, y * TILE)
			if not _is_solid(x - 1, y):
				draw_rect(Rect2(pos, Vector2(3, TILE)), Color("17313D"))
			if not _is_solid(x + 1, y):
				draw_rect(Rect2(pos + Vector2(TILE - 3, 0), Vector2(3, TILE)), Color("17313D"))
			if not _is_solid(x, y - 1):
				draw_rect(Rect2(pos, Vector2(TILE, 7)), Color("173A40"))
				draw_line(pos, pos + Vector2(TILE, 0), Color("5FBF98"), 3.0)
				for k in 5:
					var h := 3.0 + float((x * 7 + k * 13 + y * 3) % 6)
					var gx := pos.x + 3 + k * 6.5
					draw_line(Vector2(gx, pos.y), Vector2(gx + 1.5, pos.y - h), Color("4FA88A"), 1.5, true)
	for rect in _spike_rects:
		Fx.glow(self, rect.get_center() + Vector2(0, 8), 26.0, Color(0.85, 0.2, 0.35, 0.25))
		for i in 3:
			var x0 := rect.position.x + i * TILE / 3.0
			var base := rect.end.y
			draw_colored_polygon(PackedVector2Array([
				Vector2(x0, base), Vector2(x0 + TILE / 6.0 + 2, rect.position.y + 4 + i % 2 * 5), Vector2(x0 + TILE / 3.0, base)
			]), Color("2A0F22"))
	for y in MAP.size():
		var x: int = MAP[y].find("G")
		if x >= 0:
			var c := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			Fx.glow(self, c, 70.0, Color(0.75, 1.0, 0.7, 0.5))
			Fx.glow(self, c, 20.0, Color(0.95, 1.0, 0.9, 1.0))
