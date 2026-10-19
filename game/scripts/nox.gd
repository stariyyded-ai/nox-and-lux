class_name Nox
extends CharacterBody2D
## Нокс — управляемый герой. Прототип движения: бег, прыжок, прыжки по стенам и Толчок света.
## Все числа вынесены в @export, чтобы подбирать ощущение прямо в инспекторе Godot.

signal respawned

@export_group("Бег")
@export var max_speed := 260.0
@export var ground_accel := 2400.0
@export var air_accel := 1600.0
@export var ground_friction := 2800.0

@export_group("Прыжок")
@export var jump_velocity := -520.0
@export var gravity := 1500.0
@export var fall_gravity_mult := 1.6
@export var max_fall_speed := 900.0
@export var jump_cut := 0.45  ## во сколько раз гасится скорость, если отпустить прыжок раньше
@export var coyote_time := 0.1  ## можно прыгнуть чуть позже, чем сошёл с края
@export var jump_buffer := 0.12  ## нажатие прыжка чуть раньше приземления засчитывается

@export_group("Стены")
@export var wall_slide_speed := 110.0
@export var wall_jump_push := 320.0  ## отскок от стены, если не держать направление к ней
@export var wall_jump_lock := 0.16  ## время, когда управление по горизонтали не перебивает отскок
@export var wall_climb_push := 140.0  ## прыжок вверх по стене, если держать направление к ней
@export var wall_climb_lock := 0.06

@export_group("Толчок света")
@export var push_radius := 120.0
@export var push_speed := 760.0
@export var push_time_scale := 0.1  ## замедление времени, пока игрок целится
@export var push_max_hold_ms := 1500
@export var push_momentum_time := 0.22

var lux: Node2D
var spawn_point := Vector2.ZERO
var facing := 1
var wall_side := 0  ## -1/1, когда Нокс прижался к стене слева/справа; нужно для анимации

var _coyote := 0.0
var _buffer := 0.0
var _control_lock := 0.0
var _aiming := false
var _aim := Vector2.UP
var _push_target: Node2D
var _push_started_ms := 0


func _ready() -> void:
	add_to_group("player")
	spawn_point = global_position
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 12.0
	capsule.height = 38.0
	shape.shape = capsule
	add_child(shape)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.zoom = Vector2(1.25, 1.25)
	add_child(cam)
	add_child(NoxVisual.new())


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		respawn()
		return
	if _aiming:
		_update_aim()
		return

	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		facing = int(signf(dir))

	_coyote = coyote_time if is_on_floor() else _coyote - delta
	_buffer = jump_buffer if Input.is_action_just_pressed("jump") else _buffer - delta
	_control_lock -= delta

	var on_wall := is_on_wall_only()
	var wall_normal := get_wall_normal() if on_wall else Vector2.ZERO
	var holding_wall := on_wall and dir != 0.0 and signf(dir) == -signf(wall_normal.x)
	wall_side = int(-signf(wall_normal.x)) if holding_wall else 0

	if is_on_floor() or holding_wall:
		_recharge_lux()

	_apply_horizontal(dir, delta)
	_apply_vertical(holding_wall, delta)

	if _buffer > 0.0:
		if _coyote > 0.0:
			velocity.y = jump_velocity
			_buffer = 0.0
			_coyote = 0.0
		elif on_wall:
			# Как в Ori: если держать направление к стене, Нокс прыгает вверх вдоль неё
			# и сразу возвращается, так стену можно быстро «пропрыгать». Иначе — отскок.
			velocity.y = jump_velocity * 0.95
			if holding_wall:
				velocity.x = wall_normal.x * wall_climb_push
				_control_lock = wall_climb_lock
			else:
				velocity.x = wall_normal.x * wall_jump_push
				facing = int(signf(wall_normal.x))
				_control_lock = wall_jump_lock
			_buffer = 0.0
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

	if Input.is_action_just_pressed("light_push"):
		_try_start_push()

	move_and_slide()
	queue_redraw()


func _apply_horizontal(dir: float, delta: float) -> void:
	if _control_lock > 0.0:
		return
	var accel := ground_accel if is_on_floor() else air_accel
	if dir == 0.0 and is_on_floor():
		accel = ground_friction
	velocity.x = move_toward(velocity.x, dir * max_speed, accel * delta)


func _apply_vertical(holding_wall: bool, delta: float) -> void:
	if holding_wall and velocity.y > 0.0:
		velocity.y = minf(velocity.y + gravity * delta, wall_slide_speed)
		return
	var g := gravity * (fall_gravity_mult if velocity.y > 0.0 else 1.0)
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


# --- Толчок света -------------------------------------------------------------

func _try_start_push() -> void:
	var best: Node2D = null
	var best_dist := push_radius
	for node in get_tree().get_nodes_in_group("pushable"):
		if node.has_method("can_push") and not node.can_push():
			continue
		var d := global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	if best == null:
		return
	_aiming = true
	_push_target = best
	_push_started_ms = Time.get_ticks_msec()
	_aim = Vector2.UP
	velocity = Vector2.ZERO
	Engine.time_scale = push_time_scale


func _update_aim() -> void:
	var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if stick.length() > 0.3:
		_aim = stick.normalized()
	queue_redraw()
	var held := Time.get_ticks_msec() - _push_started_ms
	if not Input.is_action_pressed("light_push") or held > push_max_hold_ms:
		_release_push()


func _release_push() -> void:
	Engine.time_scale = 1.0
	_aiming = false
	velocity = _aim * push_speed
	_control_lock = push_momentum_time
	if absf(_aim.x) > 0.1:
		facing = int(signf(_aim.x))
	if is_instance_valid(_push_target) and _push_target.has_method("on_pushed"):
		_push_target.on_pushed(-_aim)
	_push_target = null
	queue_redraw()


func _recharge_lux() -> void:
	if lux and lux.has_method("recharge"):
		lux.recharge()


func is_aiming() -> bool:
	return _aiming


func respawn() -> void:
	Engine.time_scale = 1.0
	_aiming = false
	_push_target = null
	velocity = Vector2.ZERO
	global_position = spawn_point
	respawned.emit()


# --- Линия прицела Толчка света (самого Нокса рисует NoxVisual) ------------------

func _draw() -> void:
	if _aiming and is_instance_valid(_push_target):
		var from := _push_target.global_position - global_position
		draw_line(from, from + _aim * 70.0, Color("F7D774"), 3.0)
		draw_circle(from + _aim * 70.0, 5.0, Color("F7D774"))
