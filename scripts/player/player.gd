extends Area2D
class_name Player
## 自機（M1）。8 方向移動 + オート連射ショット。§5.3 / §0.5

@export var speed: float = 140.0          # px/sec（スターソルジャー基準: §0.5）
const FIRE_COOLDOWN := [0.18, 0.12, 0.10] # 連射間隔 Lv0/Lv1/Lv2（取得で高速化）
const BULLET_SCENE := preload("res://scenes/bullets/Bullet.tscn")

@onready var _muzzle: Marker2D = $Muzzle
@onready var _bullets: Node2D = get_node("../BulletContainer")

var _fire_timer: float = 0.0

func _ready() -> void:
	add_to_group(Const.G_PLAYER)
	collision_layer = Const.bit(Const.L_PLAYER)
	collision_mask = Const.bit(Const.L_ENEMY) \
		| Const.bit(Const.L_ENEMY_BULLET) \
		| Const.bit(Const.L_ITEM)

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += dir * speed * delta
	position = position.clamp(Const.FIELD_MIN, Const.FIELD_MAX)

	_fire_timer -= delta
	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0:
		_fire_timer = FIRE_COOLDOWN[clampi(GameState.power_level, 0, 2)]
		_shoot()

func _shoot() -> void:
	match GameState.power_level:
		0:
			_spawn(_muzzle.global_position, Vector2(0, -300))
		1:
			_spawn(_muzzle.global_position + Vector2(-4, 0), Vector2(0, -300))
			_spawn(_muzzle.global_position + Vector2(4, 0), Vector2(0, -300))
		_:
			_spawn(_muzzle.global_position, Vector2(0, -300))
			_spawn(_muzzle.global_position + Vector2(-4, 0), Vector2(-90, -290))
			_spawn(_muzzle.global_position + Vector2(4, 0), Vector2(90, -290))
	AudioManager.play_se("shot")

func _spawn(pos: Vector2, vel: Vector2) -> void:
	var b := BULLET_SCENE.instantiate()
	_bullets.add_child(b)
	b.global_position = pos
	b.setup(vel)
