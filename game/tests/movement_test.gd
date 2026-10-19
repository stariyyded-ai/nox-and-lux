extends SceneTree
## Быстрая проверка без окна:
##   godot --headless --path game -s res://tests/movement_test.gd
## Загружает тестовый уровень и проверяет бег, прыжок, Толчок света и прыжки по стене.

var _level: Node2D
var _frame := 0
var _failed := false
var _start := Vector2.ZERO
var _jump_peak := INF
var _climb_peak := INF


func _initialize() -> void:
	_level = load("res://scenes/main.tscn").instantiate()
	root.add_child(_level)


func _physics_process(_delta: float) -> bool:
	_frame += 1
	var nox: Nox = _level.player
	match _frame:
		60:
			_check(nox.is_on_floor(), "Нокс стоит на земле после старта")
			_start = nox.global_position
			Input.action_press("move_right")
		90:
			Input.action_release("move_right")
			_check(nox.global_position.x > _start.x + 60.0, "Нокс бежит вправо")
		120:
			_start = nox.global_position
			Input.action_press("jump")
		150:
			Input.action_release("jump")
		200:
			_check(_jump_peak < _start.y - 40.0, "Нокс прыгает")
			_check(nox.is_on_floor(), "Нокс приземлился")
			_check(_level.lux.global_position.distance_to(nox.global_position) < 120.0, "Люкс держится рядом")
		210:
			Input.action_press("light_push")
		215:
			_check(nox.is_aiming(), "Толчок света начинается рядом с Люксом")
			Input.action_release("light_push")
		225:
			_check(not nox.is_aiming() and Engine.time_scale == 1.0, "Толчок света завершается")
			# Ставим Нокса у стены высотой в шесть клеток (столбцы 26–30, верх на строке 3).
			nox.global_position = Vector2(24 * 32 + 16, 8 * 32 + 10)
			nox.velocity = Vector2.ZERO
			Input.action_press("move_right")
		420:
			Input.action_release("move_right")
			Input.action_release("jump")
			_check(_climb_peak < 3 * 32, "Нокс взбегает по стене прыжками")
			print("FAILED" if _failed else "ALL OK")
			quit(1 if _failed else 0)
	if _frame > 120:
		_jump_peak = minf(_jump_peak, nox.global_position.y)
	if _frame > 240 and _frame < 420:
		_climb_peak = minf(_climb_peak, nox.global_position.y)
		# Жмём прыжок каждые 18 кадров, как игрок, который «пропрыгивает» стену.
		if _frame % 18 == 0:
			Input.action_press("jump")
		elif _frame % 18 == 6:
			Input.action_release("jump")
	return false


func _check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		_failed = true
