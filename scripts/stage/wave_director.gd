extends Node
## ウェーブ進行・敵スポーン（M2）。§5.7

const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")

@export var spawn_interval: float = 1.2
@export var enemy_defs: Array[EnemyDef] = []

var _t: float = 0.0

func _process(delta: float) -> void:
	if enemy_defs.is_empty():
		return
	_t -= delta
	if _t <= 0.0:
		_t = spawn_interval
		_spawn_one()

func _spawn_one() -> void:
	var d: EnemyDef = enemy_defs.pick_random()
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.setup(d, Vector2(randf_range(16.0, 240.0), -16.0))
	get_parent().get_node("EnemyContainer").add_child(e)
