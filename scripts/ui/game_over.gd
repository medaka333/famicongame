extends Node2D
## ゲームオーバー画面（M3）。

func _ready() -> void:
	$ScoreLabel.text = "スコア  %06d" % GameState.score
	await get_tree().create_timer(1.0).timeout
	GameState.just_finished_game = true
	get_tree().change_scene_to_file("res://scenes/ui/Title.tscn")
