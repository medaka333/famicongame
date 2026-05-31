extends Area2D
class_name Player
## 自機。8方向移動 + オート連射 + 被弾無敵 + 噴射 2 フレームアニメ。

@export var speed: float = 140.0
const FIRE_COOLDOWN := [0.18, 0.12, 0.10]
const BULLET_SCENE := preload("res://scenes/bullets/Bullet.tscn")

@onready var _visual: Sprite2D = $Visual
@onready var _muzzle: Marker2D = $Muzzle

var _fire_timer: float = 0.0
var _invincible: bool = false
var _anim_t: float = 0.0
var _anim_f: int = 0

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

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += dir * speed * delta
	position = position.clamp(Const.FIELD_MIN, Const.FIELD_MAX)

	_fire_timer -= delta
	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0:
		_fire_timer = FIRE_COOLDOWN[clampi(GameState.power_level, 0, 2)]
		_shoot()

	_anim_t += delta
	if _anim_t >= 0.08:
		_anim_t = 0.0
		_anim_f = 1 - _anim_f
		_visual.texture = PixelArt.get_tex("player" + str(_anim_f))

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
