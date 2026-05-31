extends CanvasLayer
## HUD（M14・日本語）。スコア・残機 ＋ ボス HP ゲージ・各種表示。

@onready var _score_label: Label = $Score
@onready var _hi_label: Label = $HiScore
@onready var _lives_label: Label = $Lives
@onready var _boss_bar: ColorRect = $BossBar
@onready var _boss_bar_back: ColorRect = $BossBarBack
@onready var _center: Label = $CenterMsg

func _ready() -> void:
	GameState.score_changed.connect(func(v): _score_label.text = "スコア %06d" % v)
	GameState.hiscore_changed.connect(func(v): _hi_label.text = "ハイ %06d" % v)
	GameState.lives_changed.connect(func(v): _lives_label.text = "のこり %d" % v)
	GameState.boss_warning.connect(_on_warning)
	GameState.boss_appeared.connect(_on_boss_appeared)
	GameState.boss_hp_changed.connect(_on_boss_hp)
	GameState.boss_defeated.connect(_on_boss_defeated)
	GameState.stage_changed.connect(_on_stage)
	GameState.stage_cleared.connect(_on_stage_cleared)
	GameState.all_clear.connect(_on_all_clear)
	_score_label.text = "スコア %06d" % GameState.score
	_hi_label.text = "ハイ %06d" % GameState.hi_score
	_lives_label.text = "のこり %d" % GameState.lives
	$DemoLabel.visible = GameState.is_demo

func _on_warning() -> void:
	_flash("けいかい！！")

func _on_boss_appeared() -> void:
	_boss_bar_back.show()
	_boss_bar.show()

func _on_boss_hp(cur: int, max_hp: int) -> void:
	_boss_bar.size.x = 240.0 * float(cur) / float(max_hp)

func _on_boss_defeated() -> void:
	_boss_bar.hide()
	_boss_bar_back.hide()

func _on_stage_cleared() -> void:
	_center.text = "ステージクリア"
	_center.show()

func _on_stage(n: int) -> void:
	_flash("ステージ %d" % n)

func _on_all_clear() -> void:
	_boss_bar.hide()
	_boss_bar_back.hide()
	_center.text = "ぜんめんクリア！"
	_center.show()

func _flash(t: String) -> void:
	_center.text = t
	_center.show()
	await get_tree().create_timer(2.2).timeout
	if _center.text == t:
		_center.hide()
