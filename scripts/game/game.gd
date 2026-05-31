extends Node2D
## プレイ画面ルート（M1）。今は実行開始でラン状態を初期化するだけ。

func _ready() -> void:
	GameState.reset_run()
