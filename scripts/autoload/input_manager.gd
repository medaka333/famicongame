extends Node
## 入力デバイス検出・ジョイパッドリマップ（Autoload 名: InputManager）。§3.3 / §8
## キーボードはそのまま。ジョイパッド（USB ファミコンパッド含む）のボタン割当を
## 画面から再設定でき、user:// に保存して次回も復元する。

const SAVE_PATH := "user://input_config.cfg"
const REBINDABLE := ["move_up", "move_down", "move_left", "move_right", "shoot", "special", "pause"]

# 機種依存の配置差の吸収: 名前にこれを含むパッドは「ファミコン風パッド」として
# 十字キーを軸(アナログ相当)入力、ショット/戻るのボタンをProコン等の標準配置と
# 逆に扱う（機体ごとにdeviceを指定して個別設定）。
const FAMICOM_NAME_HINT := "BUFFALO"

# 標準パッド(Proコン等)の十字キー = ボタン11〜14
const DPAD_BUTTONS := {"move_up": 11, "move_down": 12, "move_left": 13, "move_right": 14}
# ファミコン風パッドの十字キー = 軸0/1（過去の実機キャリブレーションで確認済み）
const DPAD_AXES := {
	"move_up": [1, -1.0], "move_down": [1, 1.0],
	"move_left": [0, -1.0], "move_right": [0, 1.0],
}

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_changed)
	load_bindings()
	for d in Input.get_connected_joypads():
		print("[InputManager] joypad %d: %s" % [d, Input.get_joy_name(d)])
		_apply_device_bindings(d)

func _on_joy_changed(device: int, connected: bool) -> void:
	var state := "connected" if connected else "disconnected"
	print("[InputManager] joypad %d %s (%s)" % [device, state, Input.get_joy_name(device)])
	if connected:
		_apply_device_bindings(device)

# 接続デバイスの名前でファミコン風パッドかどうかを判定し、
# 十字キー / ショット(決定) / 戻る を、そのデバイスだけに個別割当する。
func _apply_device_bindings(device: int) -> void:
	var famicom := Input.get_joy_name(device).findn(FAMICOM_NAME_HINT) != -1
	var shoot := InputEventJoypadButton.new()
	shoot.button_index = 0 if famicom else 1
	_scope("shoot", device, shoot)
	var pause := InputEventJoypadButton.new()
	pause.button_index = 1 if famicom else 0
	_scope("pause", device, pause)
	for action in DPAD_BUTTONS.keys():
		if famicom:
			var pair: Array = DPAD_AXES[action]
			var m := InputEventJoypadMotion.new()
			m.axis = pair[0]
			m.axis_value = pair[1]
			_scope(action, device, m)
		else:
			var b := InputEventJoypadButton.new()
			b.button_index = DPAD_BUTTONS[action]
			_scope(action, device, b)

# 指定デバイスにだけ適用されるジョイパッド入力として、既存のこのデバイス分/
# 全デバイス共通(wildcard)分のジョイパッドイベントを消してから新しいものを追加する。
func _scope(action: String, device: int, event: InputEvent) -> void:
	for e in InputMap.action_get_events(action):
		if (e is InputEventJoypadButton or e is InputEventJoypadMotion) \
				and (e.device == device or e.device == -1):
			InputMap.action_erase_event(action, e)
	event.device = device
	InputMap.action_add_event(action, event)

# 指定アクションの現在のジョイパッドバインドを表示用文字列で返す
func get_pad_label(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			return "BTN %d" % e.button_index
		elif e is InputEventJoypadMotion:
			var s := "+" if e.axis_value > 0.0 else "-"
			return "AXIS %d%s" % [e.axis, s]
	return "---"

# リマップ: アクションの既存ジョイパッドイベントを新イベントで置換
func rebind(action: String, event: InputEvent) -> void:
	var ev := event.duplicate()
	ev.device = -1   # 全ジョイパッドに適用
	_apply(action, ev)
	save_bindings()

func _apply(action: String, event: InputEvent) -> void:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			InputMap.action_erase_event(action, e)
	InputMap.action_add_event(action, event)

func save_bindings() -> void:
	var cfg := ConfigFile.new()
	for a in REBINDABLE:
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton:
				cfg.set_value("pad", a, {"t": "b", "i": e.button_index})
				break
			elif e is InputEventJoypadMotion:
				cfg.set_value("pad", a, {"t": "m", "a": e.axis, "v": e.axis_value})
				break
	cfg.save(SAVE_PATH)

func load_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for a in REBINDABLE:
		if not cfg.has_section_key("pad", a):
			continue
		var v: Dictionary = cfg.get_value("pad", a)
		var ev: InputEvent
		if v.get("t", "") == "b":
			var b := InputEventJoypadButton.new()
			b.button_index = int(v["i"])
			ev = b
		else:
			var m := InputEventJoypadMotion.new()
			m.axis = int(v["a"])
			m.axis_value = float(v["v"])
			ev = m
		ev.device = -1
		_apply(a, ev)
