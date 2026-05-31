extends Node2D
## ジョイパッド・ボタン設定画面（M6）。§8.2
## カーソル: 矢印/WASD（上下）、J で該当アクションを「パッド入力待ち」にし、
## 次に押したジョイパッドのボタン/方向を登録。Esc でタイトルへ戻る。

const ACTIONS := ["move_up", "move_down", "move_left", "move_right", "shoot", "special", "pause"]
const NAMES := {
	"move_up": "UP", "move_down": "DOWN", "move_left": "LEFT", "move_right": "RIGHT",
	"shoot": "SHOOT (B)", "special": "SPECIAL (A)", "pause": "PAUSE (START)"
}

var _sel := 0
var _waiting := false
var _rows: Array[Label] = []

func _ready() -> void:
	for i in ACTIONS.size():
		_rows.append(get_node("Row%d" % i))
	_update_pad_name()
	_refresh()

func _update_pad_name() -> void:
	var pads := Input.get_connected_joypads()
	if pads.size() > 0:
		$PadName.text = "PAD: " + Input.get_joy_name(pads[0])
	else:
		$PadName.text = "PAD: NOT CONNECTED"

func _refresh() -> void:
	for i in ACTIONS.size():
		var a: String = ACTIONS[i]
		var cursor := "> " if i == _sel else "  "
		var bind := "PRESS PAD..." if (_waiting and i == _sel) else InputManager.get_pad_label(a)
		_rows[i].text = "%s%s : %s" % [cursor, NAMES[a], bind]

func _input(event: InputEvent) -> void:
	if _waiting:
		if event.is_action_pressed("pause"):
			_waiting = false
			_refresh()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton and event.pressed:
			InputManager.rebind(ACTIONS[_sel], event)
			_waiting = false
			_update_pad_name()
			_refresh()
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
			InputManager.rebind(ACTIONS[_sel], event)
			_waiting = false
			_refresh()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_up"):
		_sel = (_sel - 1 + ACTIONS.size()) % ACTIONS.size()
		_refresh()
	elif event.is_action_pressed("move_down"):
		_sel = (_sel + 1) % ACTIONS.size()
		_refresh()
	elif event.is_action_pressed("shoot"):
		_waiting = true
		_refresh()
	elif event.is_action_pressed("pause"):
		get_tree().change_scene_to_file("res://scenes/ui/Title.tscn")
