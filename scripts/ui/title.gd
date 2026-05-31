extends Node2D
## タイトル画面（M6）。J/START でゲーム開始、C で パッド設定画面へ。

func _ready() -> void:
	$HiScoreLabel.text = "HI-SCORE  %06d" % GameState.hi_score
	_blink()

func _blink() -> void:
	while is_inside_tree():
		$PressStart.modulate.a = 1.0
		await get_tree().create_timer(0.6).timeout
		if not is_inside_tree():
			return
		$PressStart.modulate.a = 0.0
		await get_tree().create_timer(0.4).timeout

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_C:
		get_tree().change_scene_to_file("res://scenes/ui/KeyConfig.tscn")
	elif event.is_action_pressed("shoot") or event.is_action_pressed("ui_select_start"):
		get_tree().change_scene_to_file("res://scenes/game/Game.tscn")
