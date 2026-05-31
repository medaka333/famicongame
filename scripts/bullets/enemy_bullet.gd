extends Area2D
class_name EnemyBullet
## 敵弾（M2）。§5.4

var velocity: Vector2 = Vector2.ZERO

func setup(vel: Vector2) -> void:
	velocity = vel

func _ready() -> void:
	collision_layer = Const.bit(Const.L_ENEMY_BULLET)
	collision_mask = Const.bit(Const.L_PLAYER)
	add_to_group("enemy_bullet")
	$Visual.texture = PixelArt.get_tex("ebullet")

func _physics_process(delta: float) -> void:
	position += velocity * delta
	if position.y > 256.0 or position.y < -16.0 \
		or position.x < -16.0 or position.x > 272.0:
		queue_free()
