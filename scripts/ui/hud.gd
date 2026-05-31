extends CanvasLayer
## HUD（M3）。スコア・ハイスコア・残機を GameState シグナルで更新。§5.9

@onready var _score_label: Label = $Score
@onready var _hi_label: Label = $HiScore
@onready var _lives_label: Label = $Lives

func _ready() -> void:
	GameState.score_changed.connect(func(v): _score_label.text = "SCORE %06d" % v)
	GameState.hiscore_changed.connect(func(v): _hi_label.text = "HI %06d" % v)
	GameState.lives_changed.connect(func(v): _lives_label.text = "SHIP x%d" % v)
	_score_label.text = "SCORE %06d" % GameState.score
	_hi_label.text   = "HI %06d" % GameState.hi_score
	_lives_label.text = "SHIP x%d" % GameState.lives
