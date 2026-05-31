extends Area2D
class_name Bullet
## プレイヤー弾（M1）。直進し、画面外で消滅。§5.4

var velocity: Vector2 = Vector2.ZERO

func setup(vel: Vector2) -> void:
	velocity = vel

func _ready() -> void:
	collision_layer = Const.bit(Const.L_PLAYER_BULLET)
	collision_mask = Const.bit(Const.L_ENEMY)
	area_entered.connect(_on_area_entered)
	var tex := "pbullet2" if GameState.power_level >= 2 else "pbullet"
	$Visual.texture = PixelArt.get_tex(tex)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	if position.y < -16.0 or position.y > 256.0 \
		or position.x < -16.0 or position.x > 272.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(1)
	queue_free()
