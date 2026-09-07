extends Node
## スコア・残機・パワー・難易度（Autoload 名: GameState）。§5.2 / §M13

signal score_changed(value: int)
signal hiscore_changed(value: int)
signal lives_changed(value: int)
signal ship_mode_changed(mode: int)
signal game_over

signal boss_warning
signal boss_appeared
signal boss_hp_changed(cur: int, max_hp: int)
signal boss_defeated

signal stage_changed(stage_num: int)
signal stage_cleared
signal all_clear

enum Diff { KIDS, ADULT }

## 船のモード(#10)。以前は power_level 0/1/2 の直線的な強化ラダーだったが、
## Lv2がLv1の上位互換になり「火力の倍率」でしか調整できなかった。
## 「どちらかを選ぶ」形にして、火力ではなく性質で差をつける。
##   FOCUS = 正面集中。ボスに強いが移動が遅い
##   WIDE  = 広角(北前船)。ザコ掃討が速いが当たり判定が大きい
enum ShipMode { NORMAL, FOCUS, WIDE }

var difficulty: int = Diff.KIDS
var is_demo: bool = false
var just_finished_game: bool = false   # ゲームオーバー/オールクリア直後のタイトル遷移フラグ（連打誤爆防止の入力ロック判定用）
var score: int = 0
var hi_score: int = 0
var lives: int = 3
var ship_mode: int = ShipMode.NORMAL

# --- 難易度パラメータ（KIDS=子供向けにやさしく）---
func start_lives() -> int:
	return 5 if difficulty == Diff.KIDS else 3

func bullet_speed_mul() -> float:
	return 0.6 if difficulty == Diff.KIDS else 1.0

func boss_hp_mul() -> float:
	# こどものボス戦は9〜16秒しかなく山場として短すぎたため 0.55 -> 0.75 に上げた。
	# 自機の火力を下げる前は「HPを上げてもLv2には効かずLv0だけ苦しくなる」状態だったが、
	# Lv2の火力を Lv0比 4.7倍 -> 1.6倍 に是正したことで素直に効くようになった。
	return 0.75 if difficulty == Diff.KIDS else 1.0

func spawn_mul() -> float:
	return 1.3 if difficulty == Diff.KIDS else 1.0

func zako_mul() -> float:
	return 0.7 if difficulty == Diff.KIDS else 1.0

func player_hitbox() -> float:
	return 4.0 if difficulty == Diff.KIDS else 8.0

func max_stages() -> int:
	# こどもは以前2面だったが、回避AIによる実測で1プレイ42秒とすぐ終わってしまい
	# 物足りなかったため3面に揃えた(ブロック崩しは約210秒)。難易度差は残機・敵弾速度・
	# ボスHP・ザコ時間など他の8項目でついている。
	return 3

func reset_run() -> void:
	score = 0
	lives = start_lives()
	ship_mode = ShipMode.NORMAL
	score_changed.emit(score)
	lives_changed.emit(lives)
	ship_mode_changed.emit(ship_mode)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)
	if score > hi_score:
		hi_score = score
		hiscore_changed.emit(hi_score)

## アイテム取得。同じモードを取り直しても変化はない(段階の概念をなくしたため)。
func set_ship_mode(mode: int) -> void:
	if ship_mode == mode:
		return
	ship_mode = mode
	ship_mode_changed.emit(ship_mode)

## 被弾時。難易度によらずノーマルに戻る(段階がないので1段ダウンは存在しない)。
func lose_ship_mode() -> void:
	if ship_mode == ShipMode.NORMAL:
		return
	ship_mode = ShipMode.NORMAL
	ship_mode_changed.emit(ship_mode)

func lose_life() -> void:
	if lives <= 0:
		return
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		game_over.emit()

# --- ハイスコア永続保存（§M9）---

const SAVE_PATH := "user://save.cfg"

func _ready() -> void:
	_load()
	game_over.connect(_save)
	boss_defeated.connect(_save)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		hi_score = int(cfg.get_value("score", "hi", 0))

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "hi", hi_score)
	cfg.save(SAVE_PATH)
