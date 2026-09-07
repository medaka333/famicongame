extends Node2D
## ブロック崩し専用タイトル。KIDS/ADULT 選択 → Breakout へ。Esc で GameSelect に戻る。

var _sel := 0
var _input_lock: float = 0.0
var _idle: float = 0.0

func _ready() -> void:
	GameState.is_demo = false
	AudioManager.stop_bgm()
	GameState.difficulty = GameState.Diff.KIDS
	$HiScoreLabel.text = "ハイスコア  %06d" % _load_hi()
	if GameState.just_finished_game:
		GameState.just_finished_game = false
		_input_lock = 2.0
	_refresh()
	_blink()

func _process(delta: float) -> void:
	_input_lock = maxf(_input_lock - delta, 0.0)
	_idle += delta
	if _idle >= 12.0:
		GameState.is_demo = true
		get_tree().change_scene_to_file("res://scenes/breakout/Breakout.tscn")

func _load_hi() -> int:
	var c := ConfigFile.new()
	if c.load("user://save.cfg") == OK:
		return int(c.get_value("breakout", "hi", 0))
	return 0

func _refresh() -> void:
	$KidsLabel.text = ("> " if _sel == 0 else "  ") + "こども（やさしい）"
	$AdultLabel.text = ("> " if _sel == 1 else "  ") + "おとな（むずかしい）"

func _blink() -> void:
	while is_inside_tree():
		$PressStart.modulate.a = 1.0
		await get_tree().create_timer(0.6).timeout
		if not is_inside_tree():
			return
		$PressStart.modulate.a = 0.0
		await get_tree().create_timer(0.4).timeout

func _unhandled_input(event: InputEvent) -> void:
	if _input_lock > 0.0:
		return
	_idle = 0.0
	if event.is_action_pressed("pause"):
		# キオスクモードでは内蔵のGameSelectに落とさず、シェル(受付連携の選択画面)へ戻す。
		# タイトル時点ではbegin-play前なのでプレイ回数は消費されない。
		if SessionClient.is_active():
			SessionClient.return_to_shell()
		else:
			get_tree().change_scene_to_file("res://scenes/ui/GameSelect.tscn")
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		_sel = 1 - _sel
		_refresh()
		AudioManager.play_se("cursor")
	# 以前は or event.is_action_pressed("ui_select_start") が付いていたが、
	# そのアクションは project.godot に存在せず、shoot 以外の入力のたびにエラーが
	# 出ていた(決定自体は shoot の短絡評価で動いていたので気づきにくかった)。
	# パッドのSTARTは pause に割り当てられており、この画面では「戻る」の意味なので
	# 決定と衝突する。STARTでの決定は諦めて参照を消した。
	elif event.is_action_pressed("shoot"):
		GameState.difficulty = _sel
		get_tree().change_scene_to_file("res://scenes/breakout/Breakout.tscn")
