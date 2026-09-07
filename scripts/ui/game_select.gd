extends Node2D
## ゲーム選択画面。STG とブロックくずしを選んで各タイトルへ。

const DESTS := [
	"res://scenes/ui/Title.tscn",
	"res://scenes/breakout/BreakoutTitle.tscn",
]

var _sel: int = 0

func _ready() -> void:
	GameState.is_demo = false
	AudioManager.stop_bgm()
	$StgIcon.texture = PixelArt.get_tex("player0")
	$StgIcon.scale = Vector2(1.5, 1.5)
	$BreakoutIcon.texture = PixelArt.get_tex("icon_breakout")
	$BreakoutIcon.scale = Vector2(1.5, 1.5)
	_refresh()
	_blink()

func _refresh() -> void:
	$StgLabel.text = ("> " if _sel == 0 else "  ") + "シューティングゲーム"
	$BreakoutLabel.text = ("> " if _sel == 1 else "  ") + "ブロックくずし"

func _blink() -> void:
	while is_inside_tree():
		$PressStart.modulate.a = 1.0
		await get_tree().create_timer(0.6).timeout
		if not is_inside_tree():
			return
		$PressStart.modulate.a = 0.0
		await get_tree().create_timer(0.4).timeout

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		_sel = 1 - _sel
		_refresh()
		AudioManager.play_se("cursor")
	# 以前は or event.is_action_pressed("ui_select_start") が付いていたが、
	# そのアクションは project.godot に存在せず、shoot 以外の入力のたびにエラーが
	# 出ていた(決定自体は shoot の短絡評価で動いていたので気づきにくかった)。
	# パッドのSTARTは pause に割り当てられており、この画面では「戻る」の意味なので
	# 決定と衝突する。STARTでの決定は諦めて参照を消した。
	elif event.is_action_pressed("shoot"):
		get_tree().change_scene_to_file(DESTS[_sel])
