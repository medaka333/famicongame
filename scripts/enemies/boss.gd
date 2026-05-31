extends Area2D
class_name Boss
## ボス（M10）。HP はステージ毎に可変（setup_hp）。3 種攻撃が HP でフェーズ遷移。

const BULLET_SCENE := preload("res://scenes/bullets/EnemyBullet.tscn")
const EXPLOSION_SCENE := preload("res://scenes/fx/Explosion.tscn")

var _max_hp: int = 40
var _hp: int = 40
var _phase: int = 1
var _dir: float = 1.0
var _move_speed: float = 45.0
var _fire_t: float = 1.0
var _alive: bool = true

func setup_hp(hp: int) -> void:
	_max_hp = hp
	_hp = hp

func _ready() -> void:
	collision_layer = Const.bit(Const.L_ENEMY)
	collision_mask = 0
	$Visual.texture = PixelArt.get_tex("boss")
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
	match _phase:
		1:
			var p := get_tree().get_first_node_in_group(Const.G_PLAYER) as Node2D
			var dir := (p.global_position - global_position).normalized() if p else Vector2.DOWN
			_shoot(bullets, dir * 150.0)
		2:
			for a in [-0.35, 0.0, 0.35]:
				_shoot(bullets, Vector2(sin(a), cos(a)) * 150.0)
		_:
			for i in 8:
				var ang := TAU * i / 8.0
				_shoot(bullets, Vector2(cos(ang), sin(ang)) * 130.0)

func _shoot(container: Node2D, vel: Vector2) -> void:
	var b := BULLET_SCENE.instantiate()
	container.add_child(b)
	b.global_position = global_position
	b.setup(vel)

func take_damage(amount: int) -> void:
	if not _alive:
		return
	_hp -= amount
	GameState.boss_hp_changed.emit(maxi(_hp, 0), _max_hp)
	get_tree().call_group("game", "add_shake", 0.05)
	if _hp <= _max_hp * 2 / 3 and _phase < 2:
		_phase = 2
		_move_speed = 65.0
	if _hp <= _max_hp / 3 and _phase < 3:
		_phase = 3
		_move_speed = 90.0
	if _hp <= 0:
		_die()

func _die() -> void:
	_alive = false
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
