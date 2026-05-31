extends Node
## 入力デバイス検出・リマップ（Autoload 名: InputManager）。§3.3 / §8
## M6 でリマップ画面を実装。今は接続検出のログのみ。

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_changed)
	for d in Input.get_connected_joypads():
		print("[InputManager] joypad %d: %s" % [d, Input.get_joy_name(d)])

func _on_joy_changed(device: int, connected: bool) -> void:
	var state := "connected" if connected else "disconnected"
	print("[InputManager] joypad %d %s" % [device, state])
	# TODO(M6): ファミコンパッド検出時、ボタン番号リマップ画面へ誘導
