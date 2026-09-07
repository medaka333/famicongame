extends Area2D
class_name Player
## 自機（M16）。通常操作 / デモ時は AI（敵を狙い、敵弾を避ける）。デモ中も被弾する。

@export var speed: float = 140.0
## モード別の連射間隔(NORMAL / FOCUS / WIDE の順)。
## 以前は [0.18, 0.12, 0.10] の直線的な強化で、ボスの真下に張り付いて撃つと
## 最終形態が Lv0比 4.7〜6.8倍の速さでボスを溶かしていた(実測)。
const FIRE_COOLDOWN := [0.18, 0.18, 0.15]
## フォーカス時の移動速度倍率。ボスに強いかわりに動きが鈍い、という枷。
## 0.75では重すぎたので0.85に。連射を0.18に落とすとワイドとボス撃破時間が並んで
## ワイドの上位互換になってしまうため、火力ではなく移動で差をつけている。
const FOCUS_SPEED_MUL := 0.85
const BULLET_SCENE := preload("res://scenes/bullets/Bullet.tscn")
const EXPLOSION_SCENE := preload("res://scenes/fx/Explosion.tscn")
const KITAMAEBUNE_TEX := preload("res://assets/sprites/player_kitamaebune.png")
const KITAMAEBUNE_WIDTH := 56.0
## フォーカス機の大きさ。通常機より少し大きく、当たり判定も同じ倍率で大きくなる。
## 移動速度低下と合わせた枷(ワイドの3.5倍ほどではない)。
const FOCUS_SCALE := 1.25

@onready var _visual: Sprite2D = $Visual
@onready var _muzzle: Marker2D = $Muzzle

var _fire_timer: float = 0.0
var _invincible: bool = false
var _anim_t: float = 0.0
var _anim_f: int = 0
var _demo_t: float = 0.0
var _demo_decide_t: float = 0.0
var _demo_tx: float = 128.0
var _demo_ty: float = 160.0
var _demo_avoiding: bool = false
var _col_shape: RectangleShape2D
var _base_hitbox: float = 4.0

func _ready() -> void:
	add_to_group(Const.G_PLAYER)
	collision_layer = Const.bit(Const.L_PLAYER)
	collision_mask = Const.bit(Const.L_ENEMY) \
		| Const.bit(Const.L_ENEMY_BULLET) \
		| Const.bit(Const.L_ITEM)
	area_entered.connect(_on_area_entered)
	_visual.texture = PixelArt.get_tex("player0")
	_col_shape = $CollisionShape2D.shape as RectangleShape2D
	_base_hitbox = GameState.player_hitbox()
	if _col_shape:
		_col_shape.size = Vector2(_base_hitbox, _base_hitbox)
	GameState.ship_mode_changed.connect(_on_ship_mode)
	_on_ship_mode(GameState.ship_mode)

func _physics_process(delta: float) -> void:
	if GameState.is_demo:
		_demo_move(delta)
	else:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		position += dir * _current_speed() * delta
	position = position.clamp(Const.FIELD_MIN, Const.FIELD_MAX)

	_fire_timer -= delta
	if (GameState.is_demo or Input.is_action_pressed("shoot")) and _fire_timer <= 0.0:
		_fire_timer = FIRE_COOLDOWN[clampi(GameState.ship_mode, 0, 2)]
		_shoot()

	_anim_t += delta
	if _anim_t >= 0.08:
		_anim_t = 0.0
		_anim_f = 1 - _anim_f
		if GameState.ship_mode == GameState.ShipMode.NORMAL:
			_visual.texture = PixelArt.get_tex("player" + str(_anim_f))

# --- デモ AI ---

func _demo_move(delta: float) -> void:
	_demo_t += delta
	# 回避方向だけ 0.15 秒ごとに決める（毎フレーム判断だと震える）
	_demo_decide_t -= delta
	if _demo_decide_t <= 0.0:
		_demo_decide_t = 0.15
		_demo_decide()
	var tx := position.x
	var ty := 160.0 + sin(_demo_t * 1.4) * 32.0   # 上下にゆらぐ
	if _demo_avoiding:
		# 回避中は決めた逃げ先へ（固定なので震えない）
		tx = _demo_tx
		ty = _demo_ty
	else:
		# アイテムがあれば取りに行く、なければ最寄り敵を狙う（毎フレーム滑らか追従）
		var item := _demo_item()
		if item != null:
			tx = item.global_position.x
		else:
			var e := _demo_enemy()
			if e != null:
				tx = e.global_position.x
	tx = clampf(tx, Const.FIELD_MIN.x, Const.FIELD_MAX.x)
	ty = clampf(ty, Const.FIELD_MIN.y, Const.FIELD_MAX.y)
	var sp := _current_speed()
	position.x = move_toward(position.x, tx, sp * delta)
	position.y = move_toward(position.y, ty, sp * delta)

func _demo_decide() -> void:
	var threat := _demo_threat()
	if threat != null:
		_demo_avoiding = true
		_demo_tx = position.x + (70.0 if threat.global_position.x < position.x else -70.0)
		_demo_ty = position.y + 24.0
	else:
		_demo_avoiding = false

func _demo_threat() -> Node2D:
	var best: Node2D = null
	var bd := 64.0
	for b in get_tree().get_nodes_in_group("enemy_bullet"):
		var bb := b as Node2D
		if bb.global_position.y < position.y + 8.0:
			var d := bb.global_position.distance_to(position)
			if d < bd:
				bd = d
				best = bb
	return best

func _demo_enemy() -> Node2D:
	var best: Node2D = null
	var bd := 9999.0
	for e in get_tree().get_nodes_in_group(Const.G_ENEMIES):
		var ee := e as Node2D
		var d := absf(ee.global_position.x - position.x)
		if d < bd:
			bd = d
			best = ee
	return best

func _demo_item() -> Node2D:
	var best: Node2D = null
	var bd := 9999.0
	for it in get_tree().get_nodes_in_group(Const.G_ITEMS):
		var ii := it as Node2D
		if ii.global_position.y < 230.0:
			var d := absf(ii.global_position.x - position.x)
			if d < bd:
				bd = d
				best = ii
	return best

func _shoot() -> void:
	var bullets := get_tree().get_first_node_in_group("bullet_container") as Node2D
	if bullets == null:
		return
	match GameState.ship_mode:
		GameState.ShipMode.FOCUS:
			# 正面集中。全弾がボスに当たるのでボス戦に強い(実測で2面ボス12.8秒)
			_spawn(bullets, _muzzle.global_position + Vector2(-4, 0), Vector2(0, -300))
			_spawn(bullets, _muzzle.global_position + Vector2(4, 0), Vector2(0, -300))
		GameState.ShipMode.WIDE:
			# 広角。通常の距離(y=180前後)では斜め弾がボスに当たらないので、
			# ボス戦はフォーカスに劣る(実測で2面ボス15.9秒)。かわりにザコ掃討が速い。
			_spawn(bullets, _muzzle.global_position, Vector2(0, -300))
			_spawn(bullets, _muzzle.global_position + Vector2(-4, 0), Vector2(-120, -290))
			_spawn(bullets, _muzzle.global_position + Vector2(4, 0), Vector2(120, -290))
		_:
			_spawn(bullets, _muzzle.global_position, Vector2(0, -300))
	AudioManager.play_se("shot")

func _spawn(container: Node2D, pos: Vector2, vel: Vector2) -> void:
	var b := BULLET_SCENE.instantiate()
	container.add_child(b)
	b.global_position = pos
	b.setup(vel)

func _on_area_entered(area: Area2D) -> void:
	if _invincible:
		return
	if area is EnemyBullet or area is Enemy or area is Boss:
		_hit()

func _hit() -> void:
	GameState.lose_life()
	if GameState.lives > 0:
		_hit_survive()
	else:
		_hit_death()

# 被弾（残機あり）: 白フラッシュ + 破片 + 一瞬スロー → 無敵点滅
func _hit_survive() -> void:
	AudioManager.play_se("miss")
	_visual.modulate = Color(4, 4, 4)   # 一瞬の白フラッシュ
	get_tree().call_group("game", "add_shake", 0.6)
	_spawn_debris(global_position, 5, 26.0)
	get_tree().call_group("game", "hit_stop", 0.05, 0.15)
	await get_tree().create_timer(0.05, true, false, true).timeout   # 白フラッシュを見せる
	GameState.lose_ship_mode()
	_start_invincible()

# 破壊（残機0）: 爆散。強スロー → 爆発連鎖 + 破片放射
func _hit_death() -> void:
	set_physics_process(false)
	set_deferred("monitoring", false)
	_invincible = true
	_visual.modulate = Color(5, 5, 5)
	AudioManager.play_se("explosion")
	get_tree().call_group("game", "add_shake", 1.0)
	get_tree().call_group("game", "hit_stop", 0.15, 0.05)
	await _death_burst()

func _death_burst() -> void:
	# 強スロー明けまで実時間で待ってから機体を消す
	await get_tree().create_timer(0.15, true, false, true).timeout
	hide()
	# 爆発を機体周囲に時間差で連鎖
	for i in 6:
		var off := Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		_spawn_explosion(global_position + off)
		if i % 2 == 0:
			AudioManager.play_se("explosion")
		_spawn_debris(global_position + off, 3, 40.0)
		await get_tree().create_timer(0.09, true, false, true).timeout

func _fx() -> Node2D:
	return get_tree().get_first_node_in_group("fx_container") as Node2D

func _spawn_explosion(at: Vector2) -> void:
	var fx := _fx()
	if fx == null:
		return
	var e := EXPLOSION_SCENE.instantiate()
	fx.add_child(e)
	e.global_position = at

# 破片スパークを放射状に飛ばす（breakout の _burst と同型）
func _spawn_debris(at: Vector2, count: int, dist: float) -> void:
	var fx := _fx()
	if fx == null:
		return
	var base := randf() * TAU
	for i in count:
		var ang := base + TAU * float(i) / float(count)
		var s := Sprite2D.new()
		s.texture = PixelArt.get_tex("spark_blue")
		s.global_position = at
		fx.add_child(s)
		var dst := at + Vector2(cos(ang), sin(ang)) * dist
		var tw := s.create_tween()
		tw.tween_property(s, "global_position", dst, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "scale", Vector2(0.2, 0.2), 0.32)
		tw.parallel().tween_property(s, "modulate:a", 0.0, 0.36)
		tw.tween_callback(s.queue_free)

func _start_invincible() -> void:
	_invincible = true
	_visual.modulate = Color(1, 1, 1, 1)   # フラッシュ解除
	var tw := create_tween().set_loops(15)
	tw.tween_property(_visual, "modulate:a", 0.1, 0.05)
	tw.tween_property(_visual, "modulate:a", 1.0, 0.05)
	await get_tree().create_timer(1.5).timeout
	_invincible = false
	_visual.modulate.a = 1.0

## フォーカス中は移動が鈍る。デモAIの移動もここを通す。
func _current_speed() -> float:
	return speed * FOCUS_SPEED_MUL if GameState.ship_mode == GameState.ShipMode.FOCUS else speed

func _on_ship_mode(mode: int) -> void:
	if mode == GameState.ShipMode.WIDE:
		# 北前船。見た目が大きくなり、当たり判定も3.5倍になる(広角の代償)
		_visual.texture = KITAMAEBUNE_TEX
		_visual.self_modulate = Color(1, 1, 1)
		var s := KITAMAEBUNE_WIDTH / KITAMAEBUNE_TEX.get_width()
		_visual.scale = Vector2(s, s)
		if _col_shape:
			var hb := _base_hitbox * (KITAMAEBUNE_WIDTH / 16.0)
			_col_shape.size = Vector2(hb, hb)
		return
	_visual.self_modulate = Color(1, 1, 1)
	if mode == GameState.ShipMode.FOCUS:
		# 専用の細身の機体。通常機より一回り大きく、当たり判定も同じだけ大きい
		_visual.texture = PixelArt.get_tex("player_focus")
		_visual.scale = Vector2(FOCUS_SCALE, FOCUS_SCALE)
		if _col_shape:
			_col_shape.size = Vector2(_base_hitbox, _base_hitbox) * FOCUS_SCALE
		return
	_visual.scale = Vector2(1, 1)
	_visual.texture = PixelArt.get_tex("player" + str(_anim_f))
	if _col_shape:
		_col_shape.size = Vector2(_base_hitbox, _base_hitbox)
