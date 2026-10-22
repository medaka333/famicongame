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

## TODDLER(ちびっこ)は末尾に足す。KIDS=0/ADULT=1 の値はブロック崩しのタイトルが
## 選択位置をそのまま代入しているので動かさない。
enum Diff { KIDS, ADULT, TODDLER }

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

# --- 難易度パラメータ（KIDS=子供向けにやさしく・TODDLER=さらにやさしく）---
## モードごとの値の表。3モードになり「こどもでなければおとな」の書き方では
## TODDLERがおとなの値になってしまうため、モードごとに全項目を書く。
##   lives=残機 bullet=敵弾速度の倍率 boss=ボスHPの倍率 spawn=ザコ出現間隔の倍率
##   zako=ザコ時間の倍率 hitbox=自機の当たり判定(px)
##   shot_size=自機の弾の大きさの倍率 fire=自機の連射間隔の倍率(小さいほど速い)
##   zako_size=ザコの大きさの倍率(見た目と当たり判定) boss_size=ボスの大きさの倍率(同)
##   boss_fire=ボスの攻撃間隔の倍率(大きいほどゆるい)
##   zako_max_hp=ザコのHPの上限 boss_max_phase=ボスの攻撃が何段階目まで上がるか
## boss: こどものボス戦は9〜16秒しかなく山場として短すぎたため 0.55 -> 0.75 に上げた。
## 自機の火力を下げる前は「HPを上げてもLv2には効かずLv0だけ苦しくなる」状態だったが、
## Lv2の火力を Lv0比 4.7倍 -> 1.6倍 に是正したことで素直に効くようになった。
var diff_params := {
	Diff.KIDS:    {"lives": 5, "bullet": 0.6, "boss": 0.75, "spawn": 1.3, "zako": 0.7, "hitbox": 4.0,
			"shot_size": 1.0, "fire": 1.0, "zako_size": 1.0, "boss_size": 1.0, "boss_fire": 1.0,
			"zako_max_hp": 99, "boss_max_phase": 3},
	Diff.ADULT:   {"lives": 3, "bullet": 1.0, "boss": 1.0,  "spawn": 1.0, "zako": 1.0, "hitbox": 8.0,
			"shot_size": 1.0, "fire": 1.0, "zako_size": 1.0, "boss_size": 1.0, "boss_fire": 1.0,
			"zako_max_hp": 99, "boss_max_phase": 3},
	## ちびっこ: 子どもは「敵に弾を当てる」のが難しそうだった(河村さんの観察)ので、自機の弾を
	## 大きく・連射を速く・ザコとボスを大きくして当てやすくし、ボスはHPと攻撃の頻度でゆるめる。
	## 紫のザコも一撃で倒せ、ボスは3段階目(全方向にばらまく一番激しい攻撃)に進まない。
	## 河村さんが候補3つを遊び比べて決めた(2026-10-22)。それ以外はこどもと同じ。
	Diff.TODDLER: {"lives": 5, "bullet": 0.6, "boss": 0.6, "spawn": 1.3, "zako": 0.7, "hitbox": 4.0,
			"shot_size": 1.5, "fire": 0.85, "zako_size": 1.5, "boss_size": 1.5, "boss_fire": 1.5,
			"zako_max_hp": 1, "boss_max_phase": 2},
}

func _param(key: String) -> Variant:
	return diff_params[difficulty][key]

func start_lives() -> int:
	return _param("lives")

func bullet_speed_mul() -> float:
	return _param("bullet")

func boss_hp_mul() -> float:
	return _param("boss")

func spawn_mul() -> float:
	return _param("spawn")

func zako_mul() -> float:
	return _param("zako")

func player_hitbox() -> float:
	return _param("hitbox")

func shot_size() -> float:
	return _param("shot_size")

func fire_cooldown_mul() -> float:
	return _param("fire")

func zako_size() -> float:
	return _param("zako_size")

func boss_size() -> float:
	return _param("boss_size")

func zako_max_hp() -> int:
	return _param("zako_max_hp")

func boss_max_phase() -> int:
	return _param("boss_max_phase")

func boss_fire_mul() -> float:
	return _param("boss_fire")

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
	# 放置デモの得点はハイスコアに入れない(屋台で、誰も遊んでいないのにハイスコアが出てしまうため)
	if score > hi_score and not is_demo:
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
