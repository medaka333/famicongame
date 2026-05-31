extends Area2D
class_name Enemy
## 敵本体（M2）。§5.6

@export var def: EnemyDef

var _hp: int = 1
var _t: float = 0.0
var _base_x: float = 0.0
var _fire_t: float = 0.0

const BULLET_SCENE := preload("res://scenes/bullets/EnemyBullet.tscn")
const EXPLOSION_SCENE := preload("res://scenes/fx/Explosion.tscn")
const POWERUP_SCENE := preload("res://scenes/items/PowerUp.tscn")

func setup(d: EnemyDef, pos: Vector2) -> void:
	def = d
	position = pos

func _ready() -> void:
	add_to_group(Const.G_ENEMIES)
	collision_layer = Const.bit(Const.L_ENEMY)
	collision_mask = 0
	_hp = def.max_hp
	_base_x = position.x
	_fire_t = def.fire_interval if def.fire_interval > 0.0 else INF

func _physics_process(delta: float) -> void:
	_t += delta
	match def.move_pattern:
		"straight":
			position.y += def.speed * delta
		"sine":
			position.y += def.speed * delta
			position.x = _base_x + sin(_t * 3.0) * 24.0
		"homing":
			var p := get_tree().get_first_node_in_group(Const.G_PLAYER) as Node2D
			if p:
				var dir := (p.global_position - global_position).normalized()
				position += dir * def.speed * delta
			else:
				position.y += def.speed * delta

	if def.fire_interval > 0.0:
		_fire_t -= delta
		if _fire_t <= 0.0:
			_fire_t = def.fire_interval
			_fire()

	if position.y > 260.0:
		queue_free()

func take_damage(amount: int) -> void:
	_hp -= amount
	if _hp <= 0:
		_die()

func _fire() -> void:
	var bullets := get_tree().get_first_node_in_group("bullet_container") as Node2D
	if bullets == null:
		return
	var b := BULLET_SCENE.instantiate()
	bullets.add_child(b)
	b.global_position = global_position
	b.setup(Vector2(0, 140))

func _die() -> void:
	GameState.add_score(def.score)
	get_tree().call_group("game", "add_shake", 0.15)
	var fx_container := get_tree().get_first_node_in_group("fx_container")
	if fx_container:
		var fx := EXPLOSION_SCENE.instantiate()
		fx_container.add_child(fx)
		fx.global_position = global_position
	if randf() < def.item_drop_chance:
		var item_container := get_tree().get_first_node_in_group("item_container") as Node2D
		if item_container:
			var item := POWERUP_SCENE.instantiate()
			item_container.add_child(item)
			item.global_position = global_position
	AudioManager.play_se("explosion")
	queue_free()
