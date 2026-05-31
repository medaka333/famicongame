extends Node
## 弾オブジェクトプール（Autoload 名: BulletPool）。§6
## M1 でプレイヤー弾、M4 で増量に備え本実装。今はスタブ。

# TODO(M1): bullet_scene を prewarm して使い回す
func spawn_player_bullet(_pos: Vector2, _vel: Vector2) -> void:
	pass

func spawn_enemy_bullet(_pos: Vector2, _vel: Vector2) -> void:
	pass
