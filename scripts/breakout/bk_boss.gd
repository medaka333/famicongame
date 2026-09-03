extends Node2D
## ブロック崩し: ボス(最終面)。上部で左右往復・増援ブロック召喚・HP制。
## 攻撃(弾)は持たない: プレイヤーに直接危険が及ばないよう、代わりに定期的にブロックを増援召喚する。
## ボール命中判定は breakout.gd 側（rect() を使用）。撃破/HP変化は _root へ通知。

const SPEED := 45.0
var hp := 40
var max_hp := 40
## 増援ブロックの召喚間隔(秒)。大きいほどゆるい。
var spawn_min := 2.0
var spawn_max := 3.0
## HPが半分 / 4分の1 に達したときにまとめて出す個数。0 = 出さない。
var burst_half := 10
var burst_quarter := 10
# --- バリア(issue #8) ---
# 上壁とボスの間にボールが入ると往復し続けて当たりっぱなしになり、プレイヤーが
# 操作せずに見ているだけの時間ができてしまう。そこで連続で一定ダメージを受けたら
# ボスがバリアを張り、その間は無敵になった上でボールを下(パドル側)へ弾き飛ばす。
# プレイヤーは拾い直して狙い直す必要があり、バリア中は耐える時間になる。
## 累積でこのダメージを受けるとバリアが発動する
var barrier_damage := 4
## バリアの持続時間(秒)
var barrier_duration := 2.5
# --- 自発バリア ---
# ボスは攻撃を一切持たない(ずっと殴られるだけ)ので、ダメージ由来のバリアとは別に
# 自分からもバリアを張る。予兆を出してから発動するので理不尽にはならない。
## 自発バリアの間隔(秒)。0以下で無効
var barrier_auto_min := 10.0
var barrier_auto_max := 16.0
## 自発バリアの持続(秒)。ダメージ由来より短くして待たされ感を抑える
var barrier_auto_duration := 1.5
## 予兆の長さ(秒)。この間リングが外から収縮してきて「来るぞ」を知らせる
var barrier_telegraph := 1.0
var _dmg_acc := 0
var _barrier_t := 0.0
var _auto_t := 0.0
var _tele_t := 0.0
var _dir := 1.0
var _root: Node
var _spawn_t := 2.2
var _spr: Sprite2D
var _flash_t := 0.0
## 点滅の色。被弾=赤 / クールダウン中に弾かれた=青(「効いていない」ではなく「ガードした」と読ませる)
var _flash_col := Color(1, 0.5, 0.5)
const FLASH_DAMAGE := Color(1, 0.5, 0.5)
const FLASH_GUARD := Color(0.55, 0.75, 1.0)
## 予兆の色。modulate は 1.0 を超えると明るくなるので、全チャンネルを大きく持ち上げて
## 白飛びさせる(1.0以下だと暗くなるだけ。青に寄せる案は見た目が微妙だったため不採用)。
const TELEGRAPH_TINT := Color(3.6, 3.6, 3.6)
var _burst_half_done := false
var _burst_quarter_done := false

func setup(root: Node, hp_: int) -> void:
	_root = root
	hp = hp_
	max_hp = hp_

func _ready() -> void:
	_auto_t = randf_range(barrier_auto_min, barrier_auto_max)
	_spr = Sprite2D.new()
	_spr.texture = PixelArt.get_tex("boss3")
	_spr.scale = Vector2(1.5, 1.5)
	add_child(_spr)

func _start_barrier(dur: float) -> void:
	_barrier_t = dur
	_tele_t = 0.0
	_dmg_acc = 0
	_auto_t = randf_range(barrier_auto_min, barrier_auto_max)  # 直後にまた自発しないように
	queue_redraw()
	if _root and is_instance_valid(_root):
		_root.boss_barrier_started()

func _draw() -> void:
	if _barrier_t <= 0.0:
		return
	# 残り時間で薄くなる脈動リング。「効いていない」ではなく「防がれている」と読ませる。
	var life := clampf(_barrier_t / maxf(barrier_duration, 0.01), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_barrier_t * 14.0)
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 20, Color(0.55, 0.8, 1.0, 0.35 + 0.45 * pulse * life), 2.0)
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 20, Color(1, 1, 1, 0.25 * life), 1.0)

func rect() -> Rect2:
	return Rect2(position.x - 22.0, position.y - 18.0, 44.0, 36.0)

func _physics_process(delta: float) -> void:
	position.x += _dir * SPEED * delta
	if position.x < 48.0:
		position.x = 48.0
		_dir = 1.0
	elif position.x > 208.0:
		position.x = 208.0
		_dir = -1.0
	if _barrier_t > 0.0:
		_barrier_t -= delta
		queue_redraw()
		if _barrier_t <= 0.0:
			_dmg_acc = 0
	elif _tele_t > 0.0:
		# 予兆中。終わったら自発バリアを張る
		_tele_t -= delta
		if _tele_t <= 0.0:
			_start_barrier(barrier_auto_duration)
	elif barrier_auto_min > 0.0:
		_auto_t -= delta
		if _auto_t <= 0.0:
			_auto_t = randf_range(barrier_auto_min, barrier_auto_max)
			_tele_t = barrier_telegraph
			AudioManager.play_se("cursor")
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = randf_range(spawn_min, spawn_max)
		if _root and is_instance_valid(_root):
			_root.boss_spawn_block()
	if _flash_t > 0.0:
		_flash_t -= delta
		_spr.modulate = _flash_col if int(_flash_t * 30.0) % 2 == 0 else Color.WHITE
		if _flash_t <= 0.0:
			_spr.modulate = Color.WHITE
	elif _tele_t > 0.0:
		# 予兆はボス本体が白く脈動することだけで表す(リングでの予告は分かりにくく不採用)
		var tp := 0.5 + 0.5 * sin(_tele_t * 14.0)
		_spr.modulate = Color.WHITE.lerp(TELEGRAPH_TINT, tp)
	elif _spr.modulate != Color.WHITE:
		_spr.modulate = Color.WHITE

func is_barrier() -> bool:
	return _barrier_t > 0.0

func take_hit(damage: int = 1) -> void:
	if _barrier_t > 0.0:
		# 跳ね返りは breakout.gd 側で起きる。ここではダメージだけ無効化し、
		# 「当たったのに減らない」がバグに見えないよう青く光らせる。
		_flash_col = FLASH_GUARD
		_flash_t = 0.12
		return
	hp -= damage
	_dmg_acc += damage
	_flash_col = FLASH_DAMAGE
	_flash_t = 0.15
	if _root and is_instance_valid(_root):
		_root.boss_hp_changed(hp, max_hp)
		if not _burst_half_done and hp <= max_hp / 2:
			_burst_half_done = true
			if burst_half > 0:
				_root.boss_spawn_block_burst(burst_half)
		if not _burst_quarter_done and hp <= max_hp / 4:
			_burst_quarter_done = true
			if burst_quarter > 0:
				_root.boss_spawn_block_burst(burst_quarter)
		if hp <= 0:
			_root.boss_defeated()
		elif _dmg_acc >= barrier_damage:
			_start_barrier(barrier_duration)
