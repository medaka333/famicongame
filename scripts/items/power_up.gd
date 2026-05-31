extends Area2D
class_name PowerUp
## パワーアップアイテム（M4）。落下して自機に触れると取得。

const SPEED := 60.0

func _ready() -> void:
	add_to_group(Const.G_ITEMS)
	collision_layer = Const.bit(Const.L_ITEM)
	collision_mask = Const.bit(Const.L_PLAYER)
	area_entered.connect(_on_area_entered)
	$Visual.texture = PixelArt.get_tex("item")

func _physics_process(delta: float) -> void:
	position.y += SPEED * delta
	if position.y > 260.0:
		queue_free()

func _on_area_entered(_area: Area2D) -> void:
	GameState.add_power()
	AudioManager.play_se("powerup")
	queue_free()
