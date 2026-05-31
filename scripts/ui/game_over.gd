extends Node2D
## ゲームオーバー画面（M3）。

func _ready() -> void:
	$ScoreLabel.text = "SCORE  %06d" % GameState.score
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/Title.tscn")
