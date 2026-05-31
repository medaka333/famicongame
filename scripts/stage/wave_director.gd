extends Node
## ウェーブ進行（M13）。難易度で ザコ時間・湧き間隔・ボスHP・面数を調整。§5.7

const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/Boss.tscn")

@export var stages: Array[StageDef] = []

enum Phase { ZAKO, WARNING, BOSS }

var _stage: int = 0
var _phase: int = Phase.ZAKO
var _spawn_t: float = 0.0
var _elapsed: float = 0.0

func _ready() -> void:
	GameState.boss_defeated.connect(_on_boss_defeated)
	call_deferred("_start_stage")

func _stage_count() -> int:
	return mini(stages.size(), GameState.max_stages())

func _start_stage() -> void:
	if _stage >= _stage_count():
		return
	var s := stages[_stage]
	_phase = Phase.ZAKO
	_elapsed = 0.0
	_spawn_t = 0.0
	var bg := get_parent().get_node_or_null("BG") as ColorRect
	if bg:
		bg.color = s.bg_color
	GameState.stage_changed.emit(_stage + 1)
	AudioManager.play_bgm("stage")

func _process(delta: float) -> void:
	if _phase != Phase.ZAKO or _stage >= _stage_count():
		return
	var s := stages[_stage]
	if s.enemy_defs.is_empty():
		return
	_elapsed += delta
	if _elapsed >= s.zako_duration * GameState.zako_mul():
		_to_warning()
		return
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = s.spawn_interval * GameState.spawn_mul()
		_spawn_one(s)

func _spawn_one(s: StageDef) -> void:
	var d: EnemyDef = s.enemy_defs.pick_random()
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
	AudioManager.play_bgm("boss")
	var s := stages[_stage]
	var boss := BOSS_SCENE.instantiate()
	boss.setup(int(s.boss_hp * GameState.boss_hp_mul()), s.boss_sprite)
	boss.position = Vector2(128, 40)
	var c := get_tree().get_first_node_in_group("enemy_container") as Node2D
	if c:
		c.add_child(boss)

func _on_boss_defeated() -> void:
	_stage += 1
	if _stage >= _stage_count():
		GameState.all_clear.emit()
	else:
		GameState.stage_cleared.emit()
		await get_tree().create_timer(3.5).timeout
		_start_stage()
