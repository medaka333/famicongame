extends Node2D
## ブロック崩し ルート。進行・状態・HUD更新・shake・衝突集約。
## STG 非干渉: GameState は difficulty / is_demo しか読まない。
## 残機とボール速度は START_LIVES / KIDS_BALL_SPEED_MUL としてこちらに持つ
## (GameState の start_lives / bullet_speed_mul は STG と共用のため触らない)。
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

# 松葉ガニ。R/O=甲羅と脚、Y=目、左右対称。14列。
# 硬さ(R=2HP / Y=3HP)はこのレイアウト固有。以前はステージ番号(stage == 1)で判定していたが、
# 順番を入れ替えると硬さだけ取り残されるため、レイアウト側に持たせた。
const STAGE_CRAB := {
	"block_hp": {"R": 2, "Y": 3},
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
const STAGE_STRIPE := {
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
# --- 1プレイの所要時間の調整(issue #5) ---
## こどもモードで、残りブロックがこの数以下になったらステージクリアにする。
## ブロック崩しは残り数個を追いかける時間が一番長く(計測でステージ所要時間の33〜54%)、
## そこを飛ばすためのもの。実測でこども1プレイの中央値が282秒→217秒に縮んだ。
const KIDS_AUTO_CLEAR_REMAIN := 5
## 開始残機。GameState.start_lives() は STG と共用で こども5 / おとな3 だが、
## ブロック崩しではこどもが残機をほとんど失わず簡単すぎたため、両モードとも3に統一した。
## (STG側の残機は変えていない)
const START_LIVES := 3
## こどもモードのボール速度倍率。GameState.bullet_speed_mul() は STG の敵弾速度と共用で
## こども0.6倍だが、ブロック崩しではこどもが簡単すぎた(デモAIのノーミス率90%・残機をほぼ
## 失わない)ため 0.7倍に上げた。所要時間も 239 → 199秒 (-17%) に縮む。
## (STG側の弾速は変えていない)
const KIDS_BALL_SPEED_MUL := 0.7
## 実際に使うしきい値。0=無効(おとなモードは従来どおり最後の1個まで壊す)。
var auto_clear_remain := 0
var _clearing := false

# --- ボスの増援ブロック(issue #2). 数値は _spawn_boss でボスに渡す ---
# ボス戦の速さは「ボールが何本あるか」でほぼ決まり、ボールを増やすマルチボールは
# ブロックを壊したときしか落ちてこない。つまり増援ブロックは壁であると同時に
# アイテムの供給源でもあり、単純に減らすとボス戦は逆に長くなる(計測で+44%)。
# そこで「増援は減らす。そのかわり増援ブロックは必ずアイテムを落とす」に変更した。
## ボス出現時にまとめて出す個数(旧10 -> 6 -> 8)
var boss_spawn_burst := 8
## 定期召喚の間隔(秒)(旧 2.0〜3.0)
var boss_spawn_min := 5.0
var boss_spawn_max := 7.0
## 定期召喚1回で出す個数(旧1個)
var boss_spawn_count := 3
## HP半分 / 4分の1 到達時にまとめて出す個数。0 = 出さない(旧 各10)
var boss_burst_half := 0
var boss_burst_quarter := 0
## ボスが召喚したブロックを壊したときのアイテムドロップ率。0未満 = 通常のボス面ドロップ率。
## 増援を減らしたぶんのアイテム供給を保つため一度100%にしたが、出過ぎだったので
## 100% -> 70% -> 60% -> 45% と試したが、45%は減り方が小さい割にボス戦が
## 58→65秒(こども)/72→86秒(おとな)と伸びたため60%に戻した。
var boss_block_drop_chance := 0.6

# --- ボス戦の歯ごたえ(issue #8) ---
## ボス面で落ちるアイテムの構成
var boss_item_pool: Array = ["M", "B", "E"]

# --- アイテムの出現率 ---
## 通常ステージでブロックを1個壊したときにアイテムが落ちる確率
var drop_chance := 0.21
## ボス面での倍率。以前は1.5倍にしていたが、ボス面だけでアイテムが16個(1プレイ33個の
## 約半分)降っておりマルチボールで同時7本まで増えていたため、倍率をやめて通常と同率にした。
var boss_drop_mul := 1.0
## 画面に同時に存在できるアイテム数の上限(これを超えると抽選自体を行わない)
var item_limit := 3
## 画面に同時に存在できるボールの上限。多いほどボスが一瞬で溶ける。
var max_balls := 8
## ボスHP(難易度別)。
## おとなは元々40だったが、バリア導入でボス戦が83→113秒に伸びたため30に下げた。
## HP30+バリアあり(ボス戦86秒/通し259秒)は、HP40+バリアなし(83秒/260秒)とほぼ同じ時間で、
## バリアの利点(閉じ込めの解除・ボスが自分から行動する)だけが乗る。
var kids_boss_hp := 22
var adult_boss_hp := 30
## ボスが連続でこのダメージを受けるとバリアを張る。
## 固定値にするとHPの多いおとな(40)でバリア回数が増えすぎ、ボス戦が68秒→132秒に
## 倍増した。max_hp の約1/6にして、どちらの難易度でも6回程度に揃える。
## (こども HP22 -> 4 / おとな HP40 -> 7)
const BARRIER_DAMAGE_RATIO := 6.0
var boss_barrier_damage := 4
## バリアの持続時間(秒)
var boss_barrier_duration := 2.5
## 自発バリアの間隔(秒)。0以下で無効
var boss_barrier_auto_min := 10.0
var boss_barrier_auto_max := 16.0
## 自発バリアの持続(秒)
var boss_barrier_auto_duration := 1.5
## でかボールでボスを殴ったときのダメージ(通常のボールは1)
var boss_big_damage := 3
## 1UP(U)の出現率。通常ステージのドロップのうちこの割合がUになる。
## こどもモードは1プレイが伸びるので0(出さない)。おとなは1プレイに1〜2個出る値。
const ADULT_ONE_UP_CHANCE := 0.075
var one_up_chance := 0.0
## 同じボールがボスに連続でダメージを入れられる最短間隔(秒)。
## 狙いは「接触が数フレーム続いたときの多重ヒットを潰す」ことだけ。0.25秒にすると
## マルチボール中の正常なヒットまで弾いてボス戦が69→83秒に伸びたため0.1秒にした。
const BALL_BOSS_HIT_INTERVAL := 0.1
## でかボール(B)の持続時間(秒)
var big_duration := 8.0

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
	var kids := GameState.difficulty == GameState.Diff.KIDS
	_ball_speed = 116.0 * 1.2 * (KIDS_BALL_SPEED_MUL if kids else 1.0) # ゲームスピード1.2倍
	lives = START_LIVES
	auto_clear_remain = KIDS_AUTO_CLEAR_REMAIN if kids else 0
	one_up_chance = 0.0 if kids else ADULT_ONE_UP_CHANCE
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
	# 松葉ガニは硬いブロックが多く(必要ヒット数76回)、横縞(61回)より難しいため、
	# やさしい横縞を1面、松葉ガニを2面にしている。
	return [STAGE_STRIPE, STAGE_CRAB, STAGE_BOSS]

func _run_demo() -> void:
	await get_tree().create_timer(22.0).timeout
	if GameState.is_demo:
		GameState.is_demo = false
		get_tree().change_scene_to_file("res://scenes/breakout/BreakoutTitle.tscn")

# --- ステージ進行 ---

func _start_stage(n: int) -> void:
	stage = n
	_trans = false
	_clearing = false
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
	_spawn_blocks(data["layout"], data.get("block_hp", {}))
	_ensure_paddle()
	if data.get("boss", false):
		_spawn_boss()
		AudioManager.play_bgm("boss")
	else:
		AudioManager.play_bgm("stage")
	_spawn_ball()
	_update_stage()
	_flash("ステージ %d" % n)

## hp_map: 記号ごとのHP(例 {"R": 2})。指定がない記号は1HP。
func _spawn_blocks(layout: Array, hp_map: Dictionary = {}) -> void:
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
			b.dest = b.position
			var seg := rows - 1 - row
			if ch == "K":
				b.setup(Color(0.62, 0.62, 0.68), 0, 1, false)
			elif ch == "H":
				b.setup(Color(0.82, 0.82, 0.88), 30 + seg * 10, 2, true)
				_remaining += 1
			else:
				var hp_ := int(hp_map.get(ch, 1))
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
	var hp := adult_boss_hp if GameState.difficulty == GameState.Diff.ADULT else kids_boss_hp
	boss.setup(self, hp)
	boss.spawn_min = boss_spawn_min
	boss.spawn_max = boss_spawn_max
	boss.spawn_count = boss_spawn_count
	boss.burst_half = boss_burst_half
	boss.burst_quarter = boss_burst_quarter
	boss_barrier_damage = maxi(3, int(round(float(hp) / BARRIER_DAMAGE_RATIO)))
	boss.barrier_damage = boss_barrier_damage
	boss.barrier_duration = boss_barrier_duration
	boss.barrier_auto_min = boss_barrier_auto_min
	boss.barrier_auto_max = boss_barrier_auto_max
	boss.barrier_auto_duration = boss_barrier_auto_duration
	$World.add_child(boss)
	boss.position = Vector2(128, 50)
	_show_boss_bar(hp)
	if boss_spawn_burst > 0:
		boss_spawn_block_burst(boss_spawn_burst) # ボス出現時にもまとめて射出

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
		# ボスは横に動くので、ほぼ真上に飛ぶボールの側面にボスが寄っていくと、
		# 跳ね返してもすぐまた接触して毎フレームダメージが入りうる。同じボールからの
		# 連続ヒットには短い間隔を設ける(通常は1秒以上空くので普通のプレイには影響しない)。
		if ball.boss_hit_cd <= 0.0:
			ball.boss_hit_cd = BALL_BOSS_HIT_INTERVAL
			best.take_hit(boss_big_damage if ball.is_big() else 1) # でかボールはダメージ増
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
	_maybe_drop(b.position, b.from_boss)
	blocks.erase(b)
	b.queue_free()
	_check_clear()

func _maybe_drop(at: Vector2, from_boss: bool = false) -> void:
	if get_tree().get_nodes_in_group(Const.G_ITEMS).size() >= item_limit:
		return
	var is_boss_stage := boss != null and is_instance_valid(boss)
	var chance := drop_chance * boss_drop_mul if is_boss_stage else drop_chance
	if is_boss_stage and from_boss and boss_block_drop_chance >= 0.0:
		chance = boss_block_drop_chance
	if randf() < chance:
		var kind: String
		if is_boss_stage:
			# 最終ステージ(ボス戦)はマルチボール/でかボール/ワイドパドルのみ出す
			kind = boss_item_pool.pick_random()
		else:
			# 1UP(U)は1プレイの所要時間を伸ばすため、こどもモードでは出さない(issue #1)。
			# おとなモードのみ、1プレイに1〜2個出る程度の確率で復活させている。
			kind = "U" if randf() < one_up_chance else ["E", "M", "T", "B"].pick_random()
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
				b.set_big(big_duration)
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
			if balls.size() >= max_balls:
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
	if _remaining > auto_clear_remain:
		return
	_stage_clear()

func _stage_clear() -> void:
	if _clearing:
		return
	_clearing = true
	_trans = true
	# 掃除演出の途中でボールが残ブロックに当たると _check_clear が再入するため、先に片付ける。
	for b in balls:
		if is_instance_valid(b):
			b.queue_free()
	balls.clear()
	await _sweep_remaining_blocks()
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

## auto_clear_remain で残ったブロックを、左から順に連鎖爆発させて一気に片付ける。
## 「まだ残ってるのに終わった」ではなく「ぜんぶ吹き飛ばした」に見せるための演出。
func _sweep_remaining_blocks() -> void:
	var left: Array = []
	for b in blocks:
		if is_instance_valid(b) and b.alive:
			left.append(b)
	if left.is_empty():
		return
	left.sort_custom(func(a, b): return a.position.x < b.position.x)
	add_shake(0.8)
	_flash("ぜんぶ こわした！")
	var bonus := 0
	for i in left.size():
		var b = left[i]
		if not is_instance_valid(b):
			continue
		b.alive = false
		if b.breakable:
			_remaining -= 1
		bonus += b.score
		_explode(b.position, i % 3)
		_burst(b.position, b.color)
		_debris(b.position, b.color)
		AudioManager.play_se("explosion")
		add_shake(0.3)
		blocks.erase(b)
		b.queue_free()
		await get_tree().create_timer(0.12).timeout
	_remaining = maxi(_remaining, 0)
	if bonus > 0:
		add_score(bonus)
		# 中央メッセージ(CenterMsg: y=104〜126)と重なって両方読めなくなるため、
		# 既存の残機ボーナスと同じ y=150 に出す。
		_popup("ボーナス +%d" % bonus, Vector2(128.0, 150.0), Color(1.0, 0.9, 0.3))
	await get_tree().create_timer(0.7).timeout

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

func boss_spawn_block(count: int = 1) -> void:
	if not (boss and is_instance_valid(boss)):
		return
	for i in count:
		if not _launch_boss_block():
			break

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
	# 飛行中のブロックは position がボスの位置なので、着地予定(dest)で埋まり判定をする。
	# position で見ると同じフレームにまとめて撃ったとき同じ枠を重複して選んでしまう。
	var occupied := {}
	for b in blocks:
		if is_instance_valid(b):
			occupied[b.dest] = true
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
	b.from_boss = true
	b.dest = pos
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

## ボスがバリアを張った瞬間の処理。
## ボスの上の通路(上壁 y=8 〜 増援ブロックの上端 y=76)にボールが入ると往復し続けて
## パドルが関与しない時間になるため、ここで全ボールを下向きに弾き出して拾い直させる。
func boss_barrier_started() -> void:
	AudioManager.play_se("powerup")
	add_shake(0.2)
	# 全ボールを下向きに叩き落とすと「急に全部持っていかれた」感が強すぎたので、
	# ボスと同じ高さ以上にいるボール(=通路に閉じ込められている側)だけを対象にし、
	# 下に叩きつけるのではなくボスの左右へ払いのける。速さは変えない。
	if not (boss and is_instance_valid(boss)):
		return
	var by: float = boss.position.y + 18.0     # ボスの下端
	for b in balls:
		if not is_instance_valid(b) or b.stuck:
			continue
		if b.position.y > by:
			continue                            # すでに下にいるボールは触らない
		var away := signf(b.position.x - boss.position.x)
		if is_zero_approx(away):
			away = 1.0 if randf() < 0.5 else -1.0
		b.velocity = Vector2(away * 0.92, 0.39).normalized() * b.speed
	if boss and is_instance_valid(boss):
		# ボスの上(y=24付近)はスコア/ハイスコアのHUDと重なって読めなくなるため下に出す。
		_popup("バリア！", boss.position + Vector2(0.0, 40.0), Color(0.6, 0.85, 1.0))

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
	"U": "残機１ＵＰ！",
	"E": "ワイド！",
	"M": "ボール＋２！",
	"T": "つらぬき！",
	"B": "でかボール！",
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
	# ここでSTAGE1を直接指すと、面の順番を変えたときにチュートリアル明けだけ
	# 別の面が出てしまう。必ず1面目(_stage_list()[0])を使う。
	var data: Dictionary = _stage_list()[0]
	$BG.color = data["bg"]
	_spawn_blocks(data["layout"], data.get("block_hp", {}))
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
