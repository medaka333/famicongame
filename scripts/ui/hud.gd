extends CanvasLayer
## HUD（M14・レトロ日本語）。当時の FC STG 風: 漢字+カタカナ表記。

@onready var _score_label: Label = $Score
@onready var _hi_label: Label = $HiScore
@onready var _lives_label: Label = $Lives
@onready var _boss_bar: ColorRect = $BossBar
@onready var _boss_bar_back: ColorRect = $BossBarBack
@onready var _center: Label = $CenterMsg
## 終了画面で中央メッセージの下に出す補助行(スコア・残機ボーナス)。
## scene には置かず実行時に作る。
var _sub: Label

func _ready() -> void:
	GameState.score_changed.connect(func(v): _score_label.text = "スコア %06d" % v)
	GameState.hiscore_changed.connect(func(v): _hi_label.text = "ハイスコア %06d" % v)
	GameState.lives_changed.connect(func(v): _lives_label.text = "残機 %d" % v)
	GameState.boss_warning.connect(_on_warning)
	GameState.boss_appeared.connect(_on_boss_appeared)
	GameState.boss_hp_changed.connect(_on_boss_hp)
	GameState.boss_defeated.connect(_on_boss_defeated)
	GameState.stage_changed.connect(_on_stage)
	GameState.stage_cleared.connect(_on_stage_cleared)
	GameState.all_clear.connect(_on_all_clear)
	_score_label.text = "スコア %06d" % GameState.score
	_hi_label.text = "ハイスコア %06d" % GameState.hi_score
	_lives_label.text = "残機 %d" % GameState.lives
	$DemoLabel.visible = GameState.is_demo
	_sub = Label.new()
	_sub.offset_left = 8.0
	_sub.offset_top = 122.0
	_sub.offset_right = 248.0
	_sub.offset_bottom = 164.0
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_sub.add_theme_constant_override("outline_size", 5)
	_sub.add_theme_color_override("font_outline_color", Color.BLACK)
	_sub.hide()
	add_child(_sub)

func _on_warning() -> void:
	_flash("ワーニング！！")

func _on_boss_appeared() -> void:
	_boss_bar_back.show()
	_boss_bar.show()

func _on_boss_hp(cur: int, max_hp: int) -> void:
	_boss_bar.size.x = 240.0 * float(cur) / float(max_hp)

func _on_boss_defeated() -> void:
	_boss_bar.hide()
	_boss_bar_back.hide()

func _on_stage_cleared() -> void:
	_center.text = "ステージクリアー！"
	_center.show()

func _on_stage(n: int) -> void:
	_flash("ステージ %d" % n)

func _on_all_clear() -> void:
	_boss_bar.hide()
	_boss_bar_back.hide()
	_center.text = "オールクリアー！"
	_center.show()

## ゲームオーバーの中央表示。以前はキオスクモードだと何も出ないまま消えていた。
## スコアはHUD左上に小さく出ているだけなので、ここで画面中央に重ねて見せる。
func show_game_over() -> void:
	_boss_bar.hide()
	_boss_bar_back.hide()
	_center.text = "ゲームオーバー"
	_center.show()
	_sub.text = "スコア %06d" % GameState.score
	_sub.show()

## オールクリアの残機ボーナスとスコア。中央メッセージの下に2行で出す。
func show_all_clear_bonus(bonus: int) -> void:
	_center.text = "オールクリアー！"
	_center.show()
	_sub.text = "残機ボーナス +%d\nスコア %06d" % [bonus, GameState.score]
	_sub.show()

func _flash(t: String) -> void:
	_center.text = t
	_center.show()
	await get_tree().create_timer(2.2).timeout
	if _center.text == t:
		_center.hide()
