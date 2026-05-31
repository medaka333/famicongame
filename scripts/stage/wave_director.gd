extends Node
## ウェーブ進行（M7）。ザコ → WARNING → ボス のフェーズ管理。§5.7

const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/Boss.tscn")

@export var spawn_interval: float = 1.2
@export var enemy_defs: Array[EnemyDef] = []
@export var zako_duration: float = 15.0

enum Phase { ZAKO, WARNING, BOSS }

var _phase: int = Phase.ZAKO
var _spawn_t: float = 0.0
var _elapsed: float = 0.0

func _process(delta: float) -> void:
	if _phase != Phase.ZAKO:
		return
	if enemy_defs.is_empty():
		return
	_elapsed += delta
	if _elapsed >= zako_duration:
		_to_warning()
		return
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = spawn_interval
		_spawn_one()

func _spawn_one() -> void:
	var d: EnemyDef = enemy_defs.pick_random()
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.setup(d, Vector2(randf_range(16.0, 240.0), -16.0))
	var c := get_tree().get_first_node_in_group("enemy_container") as Node2D
	if c:
		c.add_child(e)

func _to_warning() -> void:
	_phase = Phase.WARNING
	GameState.boss_warning.emit()
	await get_tree().create_timer(2.5).timeout
	_spawn_boss()

func _spawn_boss() -> void:
	_phase = Phase.BOSS
	var boss := BOSS_SCENE.instantiate()
	boss.position = Vector2(128, 40)
	var c := get_tree().get_first_node_in_group("enemy_container") as Node2D
	if c:
		c.add_child(boss)
