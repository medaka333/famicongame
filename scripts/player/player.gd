extends Area2D
class_name Player
## 自機（M16）。通常操作 / デモ時は AI（敵を狙い、敵弾を避ける）。デモ中も被弾する。

@export var speed: float = 140.0
const FIRE_COOLDOWN := [0.18, 0.12, 0.10]
const BULLET_SCENE := preload("res://scenes/bullets/Bullet.tscn")

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

func _ready() -> void:
	add_to_group(Const.G_PLAYER)
	collision_layer = Const.bit(Const.L_PLAYER)
	collision_mask = Const.bit(Const.L_ENEMY) \
		| Const.bit(Const.L_ENEMY_BULLET) \
		| Const.bit(Const.L_ITEM)
	area_entered.connect(_on_area_entered)
	_visual.texture = PixelArt.get_tex("player0")
	var sh := $CollisionShape2D.shape as RectangleShape2D
	if sh:
		var hb := GameState.player_hitbox()
		sh.size = Vector2(hb, hb)
	GameState.power_changed.connect(_on_power)
	_on_power(GameState.power_level)

func _physics_process(delta: float) -> void:
	if GameState.is_demo:
		_demo_move(delta)
	else:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		position += dir * speed * delta
	position = position.clamp(Const.FIELD_MIN, Const.FIELD_MAX)

	_fire_timer -= delta
	if (GameState.is_demo or Input.is_action_pressed("shoot")) and _fire_timer <= 0.0:
		_fire_timer = FIRE_COOLDOWN[clampi(GameState.power_level, 0, 2)]
		_shoot()

	_anim_t += delta
	if _anim_t >= 0.08:
		_anim_t = 0.0
		_anim_f = 1 - _anim_f
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
	position.x = move_toward(position.x, tx, speed * delta)
	position.y = move_toward(position.y, ty, speed * delta)

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
	match GameState.power_level:
		0:
			_spawn(bullets, _muzzle.global_position, Vector2(0, -300))
		1:
			_spawn(bullets, _muzzle.global_position + Vector2(-4, 0), Vector2(0, -300))
			_spawn(bullets, _muzzle.global_position + Vector2(4, 0), Vector2(0, -300))
		_:
			_spawn(bullets, _muzzle.global_position, Vector2(0, -300))
			_spawn(bullets, _muzzle.global_position + Vector2(-4, 0), Vector2(-90, -290))
			_spawn(bullets, _muzzle.global_position + Vector2(4, 0), Vector2(90, -290))
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
	AudioManager.play_se("miss")
	get_tree().call_group("game", "add_shake", 0.5)
	GameState.lose_life()
	if GameState.lives > 0:
		GameState.damage_power()
		_start_invincible()
	else:
		hide()
		set_physics_process(false)
		set_deferred("monitoring", false)

func _start_invincible() -> void:
	_invincible = true
	var tw := create_tween().set_loops(15)
	tw.tween_property(_visual, "modulate:a", 0.1, 0.05)
	tw.tween_property(_visual, "modulate:a", 1.0, 0.05)
	await get_tree().create_timer(1.5).timeout
	_invincible = false
	_visual.modulate.a = 1.0

func _on_power(lv: int) -> void:
	match lv:
		0:
			_visual.self_modulate = Color(1, 1, 1)
		1:
			_visual.self_modulate = Color(1, 1, 0.6)
		_:
			_visual.self_modulate = Color(1, 0.7, 0.7)
