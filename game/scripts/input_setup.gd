class_name InputSetup
## Назначает клавиши прототипа. Позже это можно перенести в настройки проекта.

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],
	"light_push": [KEY_K, KEY_SHIFT],
	"restart": [KEY_R],
}

const PAD := {
	"jump": JOY_BUTTON_A,
	"light_push": JOY_BUTTON_X,
	"restart": JOY_BUTTON_BACK,
}


static func ensure() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		if PAD.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = PAD[action]
			InputMap.action_add_event(action, jb)
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)


static func _add_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
