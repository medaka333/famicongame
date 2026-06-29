extends Node2D
## ブロック崩し専用タイトル。KIDS/ADULT 選択 → Breakout へ。STG の Title には戻らない。

var _sel := 0

func _ready() -> void:
	GameState.is_demo = false
	AudioManager.stop_bgm()
	GameState.difficulty = GameState.Diff.KIDS
	$HiScoreLabel.text = "ハイスコア  %06d" % _load_hi()
	_refresh()
	_blink()

func _load_hi() -> int:
	var c := ConfigFile.new()
	if c.load("user://save.cfg") == OK:
		return int(c.get_value("breakout", "hi", 0))
	return 0

func _refresh() -> void:
	$KidsLabel.text = ("> " if _sel == 0 else "  ") + "こども（やさしい）"
	$AdultLabel.text = ("> " if _sel == 1 else "  ") + "おとな（むずかしい）"

func _blink() -> void:
	while is_inside_tree():
		$PressStart.modulate.a = 1.0
		await get_tree().create_timer(0.6).timeout
		if not is_inside_tree():
			return
		$PressStart.modulate.a = 0.0
		await get_tree().create_timer(0.4).timeout

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		_sel = 1 - _sel
		_refresh()
		AudioManager.play_se("cursor")
	elif event.is_action_pressed("shoot") or event.is_action_pressed("pause"):
		GameState.difficulty = _sel
		get_tree().change_scene_to_file("res://scenes/breakout/Breakout.tscn")
