extends Node
## スコア・残機・パワー等のゲーム状態（Autoload 名: GameState）。§5.2

signal score_changed(value: int)
signal hiscore_changed(value: int)
signal lives_changed(value: int)
signal power_changed(value: int)
signal game_over

const MAX_POWER := 2
const START_LIVES := 3

var score: int = 0
var hi_score: int = 0
var lives: int = START_LIVES
var power_level: int = 0

func reset_run() -> void:
	score = 0
	lives = START_LIVES
	power_level = 0
	score_changed.emit(score)
	lives_changed.emit(lives)
	power_changed.emit(power_level)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)
	if score > hi_score:
		hi_score = score
		hiscore_changed.emit(hi_score)

func add_power() -> void:
	power_level = mini(power_level + 1, MAX_POWER)
	power_changed.emit(power_level)

func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		game_over.emit()
