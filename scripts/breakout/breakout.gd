extends Node2D
## ブロック崩し ルート。進行・状態・HUD更新・shake・衝突集約。
## STG 非干渉: GameState は読むだけ(difficulty/is_demo/start_lives/bullet_speed_mul)。
## score/lives/hi は自前管理。ハイスコアは user://save.cfg [breakout] に保存。計画書 docs/BREAKOUT_PLAN.md

const Paddle := preload("res://scripts/breakout/bk_paddle.gd")
const Ball := preload("res://scripts/breakout/bk_ball.gd")
const Block := preload("res://scripts/breakout/bk_block.gd")
const Item := preload("res://scripts/breakout/bk_item.gd")
@warning_ignore("shadowed_global_identifier")
const Boss := preload("res://scripts/breakout/bk_boss.gd")

const SAVE_PATH := "user://save.cfg"

const COLORS := {
	"R": Color8(248, 56, 0),
	"O": Color8(252, 160, 68),
	"Y": Color8(248, 216, 0),
	"G": Color8(0, 184, 0),
	"C": Color8(60, 188, 252),
	"B": Color8(0, 120, 248),
	"P": Color8(152, 80, 248),
}

# STAGE1: 松葉ガニ。R/O=甲羅と脚、Y=目、左右対称。14列。
const STAGE1 := {
	"layout": [
		"..R........R..",
		"..RR.OOOO.RR..",
		"...ROORROOR...",
		".OOORRYYRROOO.",
		"OO..ORRRRO..OO",
		"..O..OOOO..O..",
		".O..O....O..O.",
		"O..O......O..O",
	],
	"bg": Color(0.04, 0.04, 0.10),
}
const STAGE2 := {
	"layout": [
		"..HHHHHHHHHH..",
		".RRRRRRRRRRRR.",
		"O.O.O.O.O.O.O.",
		"GGGGGGGGGGGGGG",
		".CC.CC.CC.CC..",
	],
	"bg": Color(0.07, 0.03, 0.10),
}
const STAGE3 := {
	"layout": [
		"K.RRRRRRRRRR.K",
		"K.RRRRRRRRRR.K",
		"K.RRHHHHHHRR.K",
		"K.RRRRRRRRRR.K",
		"..............",
		"KK..KK..KK..KK",
	],
	"bg": Color(0.02, 0.07, 0.07),
}
const STAGE4 := {
	"layout": [
		"R.R.R.R.R.R.R.",
		".O.O.O.O.O.O.O",
		"H.H.H.H.H.H.H.",
		".G.G.G.G.G.G.G",
		"C.C.C.C.C.C.C.",
		".B.B.B.B.B.B.B",
	],
	"bg": Color(0.09, 0.05, 0.02),
}
const STAGE_BOSS := {
	"layout": [
		"OO..........OO",
		"..HHHHHHHHHH..",
		"OO..........OO",
	],
	"boss": true,
	"bg": Color(0.12, 0.02, 0.04),
}

var score := 0
var hi := 0
var lives := 3
var combo := 1
var stage := 1
var balls: Array = []
var blocks: Array = []
var boss = null
var _remaining := 0
var _ball_speed := 116.0
var _trauma := 0.0
var _trans := false
var _paddle = null
const QUIT_HOLD_TIME := 3.0
var _quit_hold_t: float = 0.0
var _quit_triggered: bool = false
var _tutorial := true
var _tut_moved := false
var _tut_shot := false

# --- デバッグ専用(エクスポート版では無効): Backspace長押し=タイトルへ、
# キー「1」「2」「3」長押し=該当ステージへジャンプ(今いるステージのキーは無反応、他はどこからでも可) ---
const DEBUG_HOLD_TIME := 0.8
const DBG_STAGE_KEYS := {1: KEY_1, 2: KEY_2, 3: KEY_3}
var _dbg_title_t := 0.0
var _dbg_stage_t := {1: 0.0, 2: 0.0, 3: 0.0}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_ball_speed = 116.0 * 1.2 * GameState.bullet_speed_mul() # ゲームスピード1.2倍
	lives = GameState.start_lives()
	_load_hi()
	_update_score()
	_update_lives()
	if GameState.is_demo:
		_tutorial = false
		_start_stage(1)
		_run_demo()
	else:
		# チュートリアル中はパドル/ボールだけ練習用に出し、ブロック配置(ステージ1本編)は
		# チュートリアル終了後(_end_tutorial)まで待つ。
		_ensure_paddle()
		_spawn_ball()
		$HUD/Tutorial.show()

func _stage_list() -> Array:
	# 5ステージ(STAGE3/STAGE4含む)は長すぎるため3ステージ構成に短縮。
	# STAGE3/STAGE4は後で使うかもしれないので定義自体は残してある。
	return [STAGE1, STAGE2, STAGE_BOSS]

func _run_demo() -> void:
	await get_tree().create_timer(22.0).timeout
	if GameState.is_demo:
		GameState.is_demo = false
		get_tree().change_scene_to_file("res://scenes/breakout/BreakoutTitle.tscn")

# --- ステージ進行 ---

func _start_stage(n: int) -> void:
	stage = n
	_trans = false
	combo = 1
	_update_combo()
	for b in blocks:
		if is_instance_valid(b):
			b.queue_free()
	blocks.clear()
	for b in balls:
		if is_instance_valid(b):
			b.queue_free()
	balls.clear()
	for it in get_tree().get_nodes_in_group(Const.G_ITEMS):
		it.queue_free()
	if boss and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	_hide_boss_bar()
	var data: Dictionary = _stage_list()[n - 1]
	$BG.color = data["bg"]
	_spawn_blocks(data["layout"])
	_ensure_paddle()
	if data.get("boss", false):
		_spawn_boss()
		AudioManager.play_bgm("boss")
	else:
		AudioManager.play_bgm("stage")
	_spawn_ball()
	_update_stage()
	_flash("ステージ %d" % n)

func _spawn_blocks(layout: Array) -> void:
	_remaining = 0
	var rows := layout.size()
	for row in rows:
		var line: String = layout[row]
		var cols := line.length()
		var sx := (256.0 - cols * 16.0) / 2.0 + 8.0
		for col in cols:
			var ch := line[col]
			if ch == ".":
				continue
			var b = Block.new()
			$World.add_child(b)
			b.position = Vector2(sx + col * 16.0, 40.0 + row * 8.0)
			var seg := rows - 1 - row
			if ch == "K":
				b.setup(Color(0.62, 0.62, 0.68), 0, 1, false)
			elif ch == "H":
				b.setup(Color(0.82, 0.82, 0.88), 30 + seg * 10, 2, true)
				_remaining += 1
			else:
				var hp_ := 1
				if stage == 1 and ch == "R":
					hp_ = 2
				elif stage == 1 and ch == "Y":
					hp_ = 3
				b.setup(COLORS.get(ch, Color.WHITE), 10 + seg * 10, hp_, true)
				_remaining += 1
			blocks.append(b)

func _ensure_paddle() -> void:
	if _paddle == null or not is_instance_valid(_paddle):
		_paddle = Paddle.new()
		var bh := 22.0 if GameState.difficulty == GameState.Diff.KIDS else 16.0
		_paddle.setup(bh, self)
		$World.add_child(_paddle)
		_paddle.position = Vector2(128, 212)

func _spawn_ball() -> void:
	if _paddle == null or not is_instance_valid(_paddle):
		return
	_paddle.reset_size()
	var b = Ball.new()
	b.setup(self, _paddle, _ball_speed)
	# 生成直後、最初の_physics_processが走る前に1フレーム(0,0)(画面左上)に
	# 描画されてしまうのを防ぐため、パドル直上の位置を最初から明示的に設定する。
	b.position = Vector2(_paddle.position.x, _paddle.position.y - 8.0)
	$World.add_child(b)
	b.lost.connect(_on_ball_lost)
	balls.append(b)
	if GameState.is_demo:
		b.launch(0.0) # デモ中は誰も発射ボタンを押さないので自動発射する

func _spawn_boss() -> void:
	boss = Boss.new()
	var hp := 40 if GameState.difficulty == GameState.Diff.ADULT else 22 # ボスHPを2倍に
	boss.setup(self, hp)
	$World.add_child(boss)
	boss.position = Vector2(128, 50)
	_show_boss_bar(hp)
	boss_spawn_block_burst(10) # ボス出現時にもまとめて10個射出

# --- 衝突(ボール → ブロック/ボス) §6 ---

func ball_collide(ball) -> void:
	var best = null
	var best_depth := -1.0
	var best_n := Vector2.ZERO
	var best_closest := Vector2.ZERO
	var best_is_boss := false
	for b in blocks:
		if not is_instance_valid(b) or not b.alive:
			continue
		var r: Rect2 = b.rect()
		var closest: Vector2 = ball.position.clamp(r.position, r.end)
		var delta: Vector2 = ball.position - closest
		var dist := delta.length()
		if dist >= ball.R:
			continue
		var depth: float = ball.R - dist
		if depth > best_depth:
			best_depth = depth
			best = b
			best_closest = closest
			best_n = _aabb_normal(ball.position, r, delta, dist)
			best_is_boss = false
	if boss != null and is_instance_valid(boss):
		var br: Rect2 = boss.rect()
		var bclosest: Vector2 = ball.position.clamp(br.position, br.end)
		var bdelta: Vector2 = ball.position - bclosest
		var bdist := bdelta.length()
		if bdist < ball.R:
			var bdepth: float = ball.R - bdist
			if bdepth > best_depth:
				best_depth = bdepth
				best = boss
				best_closest = bclosest
				best_n = _aabb_normal(ball.position, br, bdelta, bdist)
				best_is_boss = true
	if best == null:
		return
	if best_is_boss:
		ball.position = best_closest + best_n * ball.R
		ball.bounce(best_n)
		add_score(50)
		AudioManager.play_se("boss_hit")
		best.take_hit(3 if ball.is_big() else 1) # でかボールはボスへのダメージ3倍
		return
	if ball.is_thru() and best.breakable:
		_destroy_block(best)
		return
	ball.position = best_closest + best_n * ball.R
	ball.bounce(best_n)
	if best.breakable:
		if ball.is_big():
			# でかボール: 当たったブロック + 近くの1個 = 2個破壊
			_destroy_block(best)
			_destroy_extra(ball, best)
		elif best.hit():
			_destroy_block(best)
		else:
			AudioManager.play_se("cursor")
	else:
		AudioManager.play_se("cursor")

func _aabb_normal(c: Vector2, r: Rect2, delta: Vector2, dist: float) -> Vector2:
	if dist > 0.001:
		return delta / dist
	var to_left := c.x - r.position.x
	var to_right := r.end.x - c.x
	var to_top := c.y - r.position.y
	var to_bottom := r.end.y - c.y
	var m := minf(minf(to_left, to_right), minf(to_top, to_bottom))
	if m == to_left:
		return Vector2(-1, 0)
	elif m == to_right:
		return Vector2(1, 0)
	elif m == to_top:
		return Vector2(0, -1)
	return Vector2(0, 1)

func _destroy_block(b) -> void:
	if not b.alive:
		return
	b.alive = false
	if b.breakable:
		_remaining -= 1
	add_score(b.score * combo)
	combo += 1
	_update_combo()
	_spark(b.position)
	_debris(b.position, b.color)
	AudioManager.play_se("explosion")
	add_shake(0.1)
	_maybe_drop(b.position)
	blocks.erase(b)
	b.queue_free()
	_check_clear()

func _maybe_drop(at: Vector2) -> void:
	if get_tree().get_nodes_in_group(Const.G_ITEMS).size() >= 3:
		return
	var is_boss_stage := boss != null and is_instance_valid(boss)
	var drop_chance := 0.21 * 1.5 if is_boss_stage else 0.21 # ボス面はアイテム出現率1.5倍
	if randf() < drop_chance:
		var kind: String
		if is_boss_stage:
			# 最終ステージ(ボス戦)はマルチボール/でかボール/ワイドパドルのみ出す
			kind = ["M", "B", "E"].pick_random()
		else:
			# 通常パワーアップは出やすく、1UP(U)は超レア（ドロップの3%）
			kind = "U" if randf() < 0.03 else ["E", "M", "T", "B"].pick_random()
		var it = Item.new()
		it.setup(self, kind)
		$World.add_child(it)
		it.position = at

# --- アイテム効果 ---

func apply_item(kind: String) -> void:
	AudioManager.play_se("powerup")
	match kind:
		"E":
			if _paddle and is_instance_valid(_paddle):
				_paddle.expand()
		"M":
			_multiball()
		"T":
			for b in balls:
				b.set_thru(8.0)
		"B":
			for b in balls:
				b.set_big(8.0)
		"U":
			lives += 1
			_update_lives()
	_powerup_fx(kind)

func _multiball() -> void:
	var src := balls.duplicate()
	for b in src:
		if b.stuck:
			continue
		for ang in [-0.45, 0.45]:
			if balls.size() >= 8:
				return
			var nb = Ball.new()
			nb.setup(self, _paddle, b.speed)
			nb.position = b.position # add_childより前に設定(1フレーム(0,0)に出るのを防ぐ)
			$World.add_child(nb)
			nb.launch_dir(b.velocity.rotated(ang))
			nb.lost.connect(_on_ball_lost)
			balls.append(nb)

func notify_paddle_touch() -> void:
	if combo != 1:
		combo = 1
		_update_combo()

func add_score(v: int) -> void:
	score += v
	if score > hi:
		hi = score
		_update_hi()
	_update_score()

# --- ミス / クリア / ゲームオーバー ---

func _on_ball_lost(b) -> void:
	balls.erase(b)
	if is_instance_valid(b):
		b.queue_free()
	if _trans:
		return
	if balls.is_empty():
		lives -= 1
		_update_lives()
		add_shake(0.4)
		AudioManager.play_se("miss")
		if lives > 0:
			_spawn_ball()
		else:
			_game_over()

func _check_clear() -> void:
	if _trans:
		return
	if boss != null and is_instance_valid(boss):
		return
	if _remaining > 0:
		return
	_stage_clear()

func _stage_clear() -> void:
	_trans = true
	for b in balls:
		if is_instance_valid(b):
			b.queue_free()
	balls.clear()
	_save_hi()
	if stage < _stage_list().size():
		add_shake(0.3)
		_flash("ステージクリアー！")
		await _fireworks(4, 1.4)
		await get_tree().create_timer(0.6).timeout
		$HUD/CenterMsg.hide()
		_start_stage(stage + 1)
	else:
		_all_clear()

func _all_clear() -> void:
	SessionClient.consume()
	AudioManager.stop_bgm()
	add_shake(0.5)
	_flash("オールクリアー！")
	await get_tree().create_timer(0.8).timeout
	var bonus := lives * 1000 # 残機ボーナス
	if bonus > 0:
		_popup("残機ボーナス +%d" % bonus, Vector2(128.0, 150.0), Color(1.0, 0.9, 0.3))
		add_score(bonus)
		await get_tree().create_timer(0.8).timeout
	_save_hi()
	await _fireworks(8, 2.5)
	await get_tree().create_timer(0.7).timeout
	if SessionClient.is_active():
		SessionClient.return_to_shell()
		return
	GameState.just_finished_game = true
	get_tree().change_scene_to_file("res://scenes/breakout/BreakoutTitle.tscn")

func _game_over() -> void:
	_trans = true
	AudioManager.stop_bgm()
	AudioManager.play_se("miss")
	_save_hi()
	for b in balls:
		if is_instance_valid(b):
			b.queue_free()
	balls.clear()
	if GameState.is_demo:
		GameState.is_demo = false
		get_tree().change_scene_to_file("res://scenes/breakout/BreakoutTitle.tscn")
		return
	SessionClient.consume()
	$HUD/CenterMsg.text = "ゲームオーバー"
	$HUD/CenterMsg.show()
	await get_tree().create_timer(1.0).timeout
	if SessionClient.is_active():
		SessionClient.return_to_shell()
		return
	GameState.just_finished_game = true
	get_tree().change_scene_to_file("res://scenes/breakout/BreakoutTitle.tscn")

# --- ボス通知 ---

const BOSS_BLOCK_LIMIT := 50 ## ボスの増援ブロックが際限なく増えないための上限
const BOSS_BLOCK_ROW_OFFSET := 5 ## 増援ブロックは通常の配置より5ブロック(=40px)下に出す
const FESTIVAL_COLORS := [
	Color8(224, 32, 16),   # 提灯の赤
	Color8(255, 200, 40),  # 金
	Color8(255, 255, 255), # 白(紅白)
]

func boss_spawn_block() -> void:
	if not (boss and is_instance_valid(boss)):
		return
	_launch_boss_block()

func boss_spawn_block_burst(n: int) -> void:
	# HP半分/4分の1到達時のまとめ射出(演出を派手に)。
	if not (boss and is_instance_valid(boss)):
		return
	add_shake(0.3)
	for i in n:
		if not _launch_boss_block():
			break

func _launch_boss_block() -> bool:
	# ボスは弾を撃たず、代わりに空いている棚にブロックを増援として射出する(危険物ではなく補充演出)。
	if blocks.size() >= BOSS_BLOCK_LIMIT:
		return false
	var layout: Array = _stage_list()[stage - 1]["layout"]
	var rows := layout.size()
	var cols: int = layout[0].length()
	var sx := (256.0 - cols * 16.0) / 2.0 + 8.0
	var y0 := 40.0 + BOSS_BLOCK_ROW_OFFSET * 8.0
	var occupied := {}
	for b in blocks:
		if is_instance_valid(b):
			occupied[b.position] = true
	var candidates: Array = []
	for row in rows:
		for col in cols:
			var pos := Vector2(sx + col * 16.0, y0 + row * 8.0)
			if not occupied.has(pos):
				candidates.append(pos)
	if candidates.is_empty():
		return false
	var pos: Vector2 = candidates.pick_random()
	var seg := rows - 1 - int((pos.y - y0) / 8.0)
	var b = Block.new()
	$World.add_child(b)
	b.position = boss.position
	b.alive = false # 飛んでいる間はボールと衝突しない
	b.setup(FESTIVAL_COLORS.pick_random(), 10 + seg * 10, 1, true)
	blocks.append(b)
	_remaining += 1
	var tw := b.create_tween()
	tw.tween_property(b, "position", pos, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_land_boss_block.bind(b, pos))
	return true

func _land_boss_block(b, pos: Vector2) -> void:
	if not is_instance_valid(b):
		return
	b.alive = true
	_spark(pos)
	AudioManager.play_se("cursor")

func boss_hp_changed(cur: int, mx: int) -> void:
	_update_boss_bar(cur, mx)

func boss_defeated() -> void:
	if boss and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	_hide_boss_bar()
	add_score(5000)
	add_shake(0.8)
	AudioManager.play_se("explosion")
	for i in 6:
		_explode(Vector2(randf_range(96, 160), randf_range(32, 72)), i % 3)
	for b in blocks:
		if is_instance_valid(b):
			b.queue_free()
	blocks.clear()
	_remaining = 0
	_check_clear()

# --- 演出 ---

func _destroy_extra(ball, skip) -> void:
	var nearest = null
	var nearest_dist := 24.0
	for b in blocks:
		if not is_instance_valid(b) or not b.alive or not b.breakable or b == skip:
			continue
		var d: float = ball.position.distance_to(b.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = b
	if nearest:
		_destroy_block(nearest)

func _spark(at: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = PixelArt.get_tex("spark")
	s.position = at
	$World/FX.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2(2, 2), 0.18)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.2)
	tw.tween_callback(s.queue_free)

func _debris(at: Vector2, col: Color) -> void:
	# ブロックの色のカケラを放射状+重力落下風に飛ばす(破壊の手応えを強化)。
	var n := 5
	for i in n:
		var ang := randf_range(0.0, TAU)
		var spd := randf_range(10.0, 24.0)
		var s := Sprite2D.new()
		s.texture = PixelArt.get_tex("spark")
		s.position = at
		s.modulate = col
		s.scale = Vector2(0.7, 0.7)
		$World/FX.add_child(s)
		var dst := at + Vector2(cos(ang), sin(ang)) * spd + Vector2(0, randf_range(8.0, 16.0))
		var tw := s.create_tween()
		tw.tween_property(s, "position", dst, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "modulate:a", 0.0, 0.45)
		tw.tween_callback(s.queue_free)

# --- パワーアップ取得演出（何を取ったか分かりやすく）---

const ITEM_NAME := {
	"E": "ワイド！",
	"M": "ボール＋２！",
	"T": "つらぬき！",
	"B": "でかボール！",
	"U": "残機１ＵＰ！",
}

func _powerup_fx(kind: String) -> void:
	var col: Color = Item.COL.get(kind, Color.WHITE)
	var at := Vector2(128.0, 196.0)
	if _paddle and is_instance_valid(_paddle):
		at = Vector2(_paddle.position.x, _paddle.position.y - 14.0)
		_paddle.flash(col)
	_burst(at, col)
	_popup(ITEM_NAME.get(kind, "パワーアップ！"), at, col)
	add_shake(0.12)

func _burst(at: Vector2, col: Color) -> void:
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var s := Sprite2D.new()
		s.texture = PixelArt.get_tex("spark")
		s.position = at
		s.modulate = col
		$World/FX.add_child(s)
		var dst := at + Vector2(cos(ang), sin(ang)) * 15.0
		var tw := s.create_tween()
		tw.tween_property(s, "position", dst, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "modulate:a", 0.0, 0.35)
		tw.tween_callback(s.queue_free)

func _popup(text: String, at: Vector2, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = Vector2(at.x - 64.0, at.y - 12.0)
	l.size = Vector2(128.0, 16.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	$HUD.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 24.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.55).set_delay(0.25)
	tw.tween_callback(l.queue_free)

func _explode(at: Vector2, variant: int) -> void:
	var s := Sprite2D.new()
	s.texture = PixelArt.get_tex("exp%d" % (variant % 3))
	s.position = at
	$World/FX.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2(2.5, 2.5), 0.3)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.35)
	tw.tween_callback(s.queue_free)

func add_shake(a: float) -> void:
	_trauma = minf(_trauma + a, 1.0)

func _process(delta: float) -> void:
	if _tutorial:
		if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
			_tut_moved = true
			_update_tutorial()
	if _trauma > 0.0:
		_trauma = maxf(_trauma - delta * 1.5, 0.0)
		var amt := _trauma * _trauma * 5.0
		$World.position = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
	elif $World.position != Vector2.ZERO:
		$World.position = Vector2.ZERO

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
			get_tree().change_scene_to_file("res://scenes/breakout/BreakoutTitle.tscn")
		return
	if _tutorial and event.is_action_pressed("pause"):
		_end_tutorial()
		return
	if event.is_action_pressed("shoot"):
		if _tutorial:
			_tut_shot = true
			_update_tutorial()
		# チュートリアルを終えるシュートは、そのまま練習用ボールを実際に発射する
		# シュートでもある(プレイヤーに「発射される瞬間」を必ず見せる)。
		for b in balls:
			if is_instance_valid(b) and b.stuck:
				b.launch(0.0)

# --- チュートリアル(初回操作練習) ---

func _update_tutorial() -> void:
	if not _tutorial:
		return
	$HUD/Tutorial/Move.modulate = Color(0.4, 1.0, 0.4) if _tut_moved else Color(1, 1, 1)
	$HUD/Tutorial/Shoot.modulate = Color(0.4, 1.0, 0.4) if _tut_shot else Color(1, 1, 1)
	if _tut_moved and _tut_shot:
		_end_tutorial()

func _end_tutorial() -> void:
	_tutorial = false
	$HUD/Tutorial.hide()
	# _start_stage(1)は呼ばない: それだと練習用のパドル/ボールを破棄して新しいボールを
	# 作り直すため、発射の瞬間が見せられない(または再生成直後の未確定位置から発射される)。
	# 練習用のパドル/ボールをそのまま使い、3秒カウントダウンの後にブロックを出す。
	_start_stage_after_countdown()

func _start_stage_after_countdown() -> void:
	_trans = true # カウントダウン中にボールが落ちても残機を減らさない
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
	_trans = false
	# チュートリアルで撃ったボールはここで消し、パドルも中央の初期位置に戻してから
	# 新しいボールをパドル上に乗せ直す(本編はいつも同じ状態で始まる)。
	for b in balls:
		if is_instance_valid(b):
			b.queue_free()
	balls.clear()
	if _paddle and is_instance_valid(_paddle):
		_paddle.position = Vector2(128, 212)
	_spawn_ball()
	var data: Dictionary = STAGE1
	$BG.color = data["bg"]
	_spawn_blocks(data["layout"])
	AudioManager.play_bgm("stage")
	_update_stage()
	_flash("ステージ %d" % stage)
	SessionClient.begin_play()

# --- デバッグ専用ショートカット(OS.is_debug_build()時のみ有効) ---

func _process_debug_keys(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_BACKSPACE):
		_dbg_title_t += delta
		if _dbg_title_t >= DEBUG_HOLD_TIME:
			_dbg_title_t = 0.0
			get_tree().change_scene_to_file("res://scenes/breakout/BreakoutTitle.tscn")
	else:
		_dbg_title_t = 0.0
	for n in DBG_STAGE_KEYS:
		if _trans or n == stage:
			_dbg_stage_t[n] = 0.0
			continue
		if Input.is_physical_key_pressed(DBG_STAGE_KEYS[n]):
			_dbg_stage_t[n] += delta
			if _dbg_stage_t[n] >= DEBUG_HOLD_TIME:
				_dbg_stage_t[n] = 0.0
				_start_stage(n)
		else:
			_dbg_stage_t[n] = 0.0

# --- HUD ---

func _update_score() -> void:
	$HUD/Score.text = "スコア %06d" % score

func _update_hi() -> void:
	$HUD/HiScore.text = "ハイスコア %06d" % hi

func _update_lives() -> void:
	$HUD/Lives.text = "残機 %d" % lives

func _update_stage() -> void:
	$HUD/Stage.text = "ステージ %d" % stage

func _update_combo() -> void:
	if combo > 1:
		$HUD/Combo.text = "コンボ x%d" % combo
		$HUD/Combo.show()
	else:
		$HUD/Combo.hide()

func _show_boss_bar(mx: int) -> void:
	$HUD/BossBarBack.show()
	$HUD/BossBar.show()
	_update_boss_bar(mx, mx)

func _update_boss_bar(cur: int, mx: int) -> void:
	$HUD/BossBar.size.x = 180.0 * float(cur) / float(mx)

func _hide_boss_bar() -> void:
	$HUD/BossBar.hide()
	$HUD/BossBarBack.hide()

func _flash(t: String) -> void:
	var c: Label = $HUD/CenterMsg
	c.text = t
	c.show()
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(2.0, 2.0)
	c.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(c, "modulate:a", 1.0, 0.12)
	await get_tree().create_timer(2.0).timeout
	if c.text == t and not _trans:
		c.hide()

const FIREWORK_COLORS := [
	Color(1.0, 0.3, 0.3), Color(1.0, 0.8, 0.2), Color(0.3, 0.8, 1.0),
	Color(0.4, 1.0, 0.4), Color(1.0, 0.4, 1.0),
]

func _fireworks(count: int, duration: float) -> void:
	# クリア演出用: 画面の色々な場所で爆発+カラフルなバーストを連発する。
	var interval := duration / float(count)
	for i in count:
		var at := Vector2(randf_range(24.0, 232.0), randf_range(30.0, 180.0))
		_explode(at, randi() % 3)
		_burst(at, FIREWORK_COLORS.pick_random())
		add_shake(0.15)
		AudioManager.play_se("explosion")
		await get_tree().create_timer(interval).timeout

# --- ハイスコア(STG 非干渉: [breakout] セクション) ---

func _load_hi() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) == OK:
		hi = int(c.get_value("breakout", "hi", 0))
	_update_hi()

func _save_hi() -> void:
	var c := ConfigFile.new()
	c.load(SAVE_PATH)
	c.set_value("breakout", "hi", hi)
	c.save(SAVE_PATH)
