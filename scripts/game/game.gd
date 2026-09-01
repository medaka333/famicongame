extends Node2D
## プレイ画面ルート（M14）。背景・シェイク・ポーズ・BGM・デモ制御。

@onready var _world: Node2D = $World

const QUIT_HOLD_TIME := 3.0

var _trauma: float = 0.0
var _quit_hold_t: float = 0.0
var _quit_triggered: bool = false
var _tutorial: bool = true
var _tut_moved: bool = false
var _tut_shot: bool = false

# --- デバッグ専用(エクスポート版では無効): Backspace長押し=タイトルへ、
# キー「1」「2」「3」長押し=該当ステージへジャンプ(今いるステージのキーは無反応、他はどこからでも可) ---
const DEBUG_HOLD_TIME := 0.8
const DBG_STAGE_KEYS := {1: KEY_1, 2: KEY_2, 3: KEY_3}
var _dbg_title_t := 0.0
var _dbg_stage_t := {1: 0.0, 2: 0.0, 3: 0.0}
var _dbg_cur_stage := 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game")
	$World/EnemyContainer.add_to_group("enemy_container")
	$World/BulletContainer.add_to_group("bullet_container")
	$World/ItemContainer.add_to_group("item_container")
	$World/FXContainer.add_to_group("fx_container")
	GameState.reset_run()
	GameState.game_over.connect(_on_game_over)
	GameState.all_clear.connect(_on_all_clear)
	GameState.stage_changed.connect(func(n): _dbg_cur_stage = n)
	if GameState.is_demo:
		_tutorial = false
		$WaveDirector.start()
		_run_demo()
	else:
		$WaveDirector.process_mode = Node.PROCESS_MODE_DISABLED
		$TutorialOverlay.show()

func _run_demo() -> void:
	await get_tree().create_timer(22.0).timeout
	if GameState.is_demo:
		GameState.is_demo = false
		get_tree().change_scene_to_file("res://scenes/ui/Title.tscn")

func add_shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)

# ヒットストップ: 一瞬スロー → 実時間タイマーで確実に復帰
func hit_stop(dur: float, scale: float = 0.05) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0

func _process(delta: float) -> void:
	if _tutorial:
		if Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down") \
				or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
			_tut_moved = true
			_update_tutorial()
	if _trauma > 0.0:
		_trauma = maxf(_trauma - delta * 1.5, 0.0)
		var amt := _trauma * _trauma * 4.0
		_world.position = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
	elif _world.position != Vector2.ZERO:
		_world.position = Vector2.ZERO

	if Input.is_action_pressed("pause"):
		_quit_hold_t += delta
		if _quit_hold_t >= QUIT_HOLD_TIME and not _quit_triggered:
			_quit_triggered = true
			if SessionClient.is_active():
				SessionClient.consume()
				# HTTPRequestは呼んだフレームでは送信されないため、すぐ遷移すると
				# consumeが届かず中断した1回が消化されない。ゲームオーバー経路と
				# 同様に1拍待ってから戻る。
				await get_tree().create_timer(0.5).timeout
				SessionClient.return_to_shell()
			else:
				get_tree().change_scene_to_file("res://scenes/ui/GameSelect.tscn")
	else:
		_quit_hold_t = 0.0
	if OS.is_debug_build():
		_process_debug_keys(delta)

func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_demo:
		if event.is_pressed():
			GameState.is_demo = false
			get_tree().change_scene_to_file("res://scenes/ui/Title.tscn")
		return
	if _tutorial:
		if event.is_action_pressed("pause"):
			_end_tutorial()
			return
		if event.is_action_pressed("shoot"):
			_tut_shot = true
			_update_tutorial()

# --- チュートリアル(初回操作練習) ---

func _update_tutorial() -> void:
	if not _tutorial:
		return
	$TutorialOverlay/Move.modulate = Color(0.4, 1.0, 0.4) if _tut_moved else Color(1, 1, 1)
	$TutorialOverlay/Shoot.modulate = Color(0.4, 1.0, 0.4) if _tut_shot else Color(1, 1, 1)
	if _tut_moved and _tut_shot:
		_end_tutorial()

func _end_tutorial() -> void:
	_tutorial = false
	$TutorialOverlay.hide()
	_start_stage_after_countdown()

func _start_stage_after_countdown() -> void:
	var c: Label = $HUD/CenterMsg
	for n in [3, 2, 1]:
		c.text = "%d" % n
		c.show()
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2(2.4, 2.4)
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_property(c, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(c, "modulate:a", 1.0, 0.12)
		await get_tree().create_timer(1.0).timeout
	c.scale = Vector2(1.0, 1.0)
	c.modulate.a = 1.0
	c.hide()
	# チュートリアルで撃った弾はここで消し、自機も初期位置に戻してから本編を始める
	var bullet_container := get_tree().get_first_node_in_group("bullet_container") as Node2D
	if bullet_container:
		for b in bullet_container.get_children():
			b.queue_free()
	var player := $World/Player as Node2D
	if player:
		player.position = Vector2(128, 200)
	$WaveDirector.process_mode = Node.PROCESS_MODE_INHERIT
	SessionClient.begin_play()
	$WaveDirector.start()

# --- デバッグ専用ショートカット(OS.is_debug_build()時のみ有効) ---

func _process_debug_keys(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_BACKSPACE):
		_dbg_title_t += delta
		if _dbg_title_t >= DEBUG_HOLD_TIME:
			_dbg_title_t = 0.0
			get_tree().change_scene_to_file("res://scenes/ui/Title.tscn")
	else:
		_dbg_title_t = 0.0
	for n in DBG_STAGE_KEYS:
		if n == _dbg_cur_stage:
			_dbg_stage_t[n] = 0.0
			continue
		if Input.is_physical_key_pressed(DBG_STAGE_KEYS[n]):
			_dbg_stage_t[n] += delta
			if _dbg_stage_t[n] >= DEBUG_HOLD_TIME:
				_dbg_stage_t[n] = 0.0
				if _tutorial:
					_end_tutorial()
				$WaveDirector.jump_to_stage(n)
		else:
			_dbg_stage_t[n] = 0.0

func _on_game_over() -> void:
	AudioManager.stop_bgm()
	if GameState.is_demo:
		GameState.is_demo = false
		get_tree().change_scene_to_file("res://scenes/ui/Title.tscn")
		return
	SessionClient.consume()
	await get_tree().create_timer(1.3).timeout
	if SessionClient.is_active():
		SessionClient.return_to_shell()
		return
	get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")

func _on_all_clear() -> void:
	SessionClient.consume()
	await get_tree().create_timer(5.0).timeout
	AudioManager.stop_bgm()
	if SessionClient.is_active():
		SessionClient.return_to_shell()
		return
	GameState.just_finished_game = true
	get_tree().change_scene_to_file("res://scenes/ui/Title.tscn")
