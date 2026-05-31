extends Node2D
## プレイ画面ルート（M2）。

func _ready() -> void:
	$FXContainer.add_to_group("fx_container")
	GameState.reset_run()
	GameState.game_over.connect(_on_game_over)

func _on_game_over() -> void:
	# M3 で GameOver 画面へ遷移。今はリスタートのみ。
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()
