extends Area2D
class_name Boss
## ボス（M15）。ステージ毎にスプライト＆攻撃パターンが変わる。撃破時に敵弾全消し。

const BULLET_SCENE := preload("res://scenes/bullets/EnemyBullet.tscn")
const EXPLOSION_SCENE := preload("res://scenes/fx/Explosion.tscn")

var _max_hp: int = 40
var _hp: int = 40
var _sprite: String = "boss1"
var _phase: int = 1
var _dir: float = 1.0
var _move_speed: float = 45.0
var _fire_t: float = 1.0
var _alive: bool = true

func setup(hp: int, sprite: String) -> void:
	_max_hp = hp
	_hp = hp
	_sprite = sprite

func _ready() -> void:
	add_to_group(Const.G_ENEMIES)
	collision_layer = Const.bit(Const.L_ENEMY)
	collision_mask = 0
	if _sprite == "boss1":
		var tex := load("res://assets/sprites/boss1_crab.png") as Texture2D
		$Visual.texture = tex
		if tex != null and tex.get_width() > 56:
			var s := 56.0 / float(tex.get_width())
			$Visual.scale = Vector2(s, s)
	else:
		$Visual.texture = PixelArt.get_tex(_sprite)
	GameState.boss_appeared.emit()
	GameState.boss_hp_changed.emit(_hp, _max_hp)

func _physics_process(delta: float) -> void:
	if not _alive:
		return
	position.x += _dir * _move_speed * delta
	if position.x < 30.0:
		position.x = 30.0
		_dir = 1.0
	elif position.x > 226.0:
		position.x = 226.0
		_dir = -1.0
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = [1.2, 0.9, 0.6][_phase - 1]
		_attack()

func _attack() -> void:
	var bullets := get_tree().get_first_node_in_group("bullet_container") as Node2D
	if bullets == null:
		return
	match _sprite:
		"boss2":
			_attack_crab(bullets)
		"boss3":
			_attack_final(bullets)
		_:
			_attack_fortress(bullets)

# boss1: 自機狙い → 3way → 全方位8
func _attack_fortress(bullets: Node2D) -> void:
	match _phase:
		1:
			_shoot(bullets, _aim() * 150.0)
		2:
			for a in [-0.35, 0.0, 0.35]:
				_shoot(bullets, Vector2(sin(a), cos(a)) * 150.0)
		_:
			for i in 8:
				var ang := TAU * i / 8.0
				_shoot(bullets, Vector2(cos(ang), sin(ang)) * 130.0)

# boss2: 左右ばらまき → 下方向扇5way → 自機狙い拡散3
func _attack_crab(bullets: Node2D) -> void:
	match _phase:
		1:
			_shoot(bullets, Vector2(-120, 90))
			_shoot(bullets, Vector2(120, 90))
		2:
			for a in [-0.6, -0.3, 0.0, 0.3, 0.6]:
				_shoot(bullets, Vector2(sin(a), cos(a)) * 140.0)
		_:
			for s in [-0.2, 0.0, 0.2]:
				_shoot(bullets, _aim().rotated(s) * 150.0)

# boss3: 3way → 全方位8 → 全方位12 + 自機狙い（激しい・ADULT専用）
func _attack_final(bullets: Node2D) -> void:
	match _phase:
		1:
			for a in [-0.35, 0.0, 0.35]:
				_shoot(bullets, Vector2(sin(a), cos(a)) * 150.0)
		2:
			for i in 8:
				var ang := TAU * i / 8.0
				_shoot(bullets, Vector2(cos(ang), sin(ang)) * 130.0)
		_:
			for i in 12:
				var ang := TAU * i / 12.0
				_shoot(bullets, Vector2(cos(ang), sin(ang)) * 120.0)
			_shoot(bullets, _aim() * 180.0)

func _aim() -> Vector2:
	var p := get_tree().get_first_node_in_group(Const.G_PLAYER) as Node2D
	return (p.global_position - global_position).normalized() if p else Vector2.DOWN

func _shoot(container: Node2D, vel: Vector2) -> void:
	var b := BULLET_SCENE.instantiate()
	container.add_child(b)
	b.global_position = global_position
	b.setup(vel * GameState.bullet_speed_mul())

func take_damage(amount: int) -> void:
	if not _alive:
		return
	_hp -= amount
	GameState.boss_hp_changed.emit(maxi(_hp, 0), _max_hp)
	get_tree().call_group("game", "add_shake", 0.05)
	_flash()
	if _hp <= _max_hp * 2 / 3 and _phase < 2:
		_phase = 2
		_move_speed = 65.0
	if _hp <= _max_hp / 3 and _phase < 3:
		_phase = 3
		_move_speed = 90.0
	if _hp <= 0:
		_die()

func _flash() -> void:
	$Visual.modulate = Color(1.6, 1.6, 1.6)
	await get_tree().create_timer(0.04).timeout
	if is_instance_valid(self):
		$Visual.modulate = Color(1.0, 1.0, 1.0)

func _die() -> void:
	_alive = false
	# 撃破時に敵弾を全消し（理不尽死防止）
	for b in get_tree().get_nodes_in_group("enemy_bullet"):
		b.queue_free()
	GameState.add_score(5000)
	GameState.boss_defeated.emit()
	var fx_c := get_tree().get_first_node_in_group("fx_container") as Node2D
	for i in 8:
		if fx_c:
			var fx := EXPLOSION_SCENE.instantiate()
			fx_c.add_child(fx)
			fx.global_position = global_position + Vector2(randf_range(-18, 18), randf_range(-12, 12))
		AudioManager.play_se("explosion")
		get_tree().call_group("game", "add_shake", 0.2)
		await get_tree().create_timer(0.12).timeout
	queue_free()
