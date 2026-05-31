extends Node2D
## プレイ画面ルート（M3）。

func _ready() -> void:
	$FXContainer.add_to_group("fx_container")
	$ItemContainer.add_to_group("item_container")
	GameState.reset_run()
	GameState.game_over.connect(_on_game_over)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused

func _on_game_over() -> void:
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
