extends Node2D
## タイトル画面（M3）。

func _ready() -> void:
	$PressStart.visible = true
	_blink()

func _blink() -> void:
	while true:
		$PressStart.modulate.a = 1.0
		await get_tree().create_timer(0.6).timeout
		$PressStart.modulate.a = 0.0
		await get_tree().create_timer(0.4).timeout

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot") or event.is_action_pressed("ui_select_start"):
		get_tree().change_scene_to_file("res://scenes/game/Game.tscn")
