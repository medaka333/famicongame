extends Node2D
## ブロック崩し: ボス(最終面)。上部で左右往復・落下弾・HP制。
## ボール命中判定は breakout.gd 側（rect() を使用）。撃破/HP変化は _root へ通知。

const SPEED := 45.0
var hp := 40
var max_hp := 40
var _dir := 1.0
var _root: Node
var _fire_t := 1.6
var _spr: Sprite2D
var _flash_t := 0.0

func setup(root: Node, hp_: int) -> void:
	_root = root
	hp = hp_
	max_hp = hp_

func _ready() -> void:
	_spr = Sprite2D.new()
	_spr.texture = PixelArt.get_tex("boss3")
	_spr.scale = Vector2(1.5, 1.5)
	add_child(_spr)

func rect() -> Rect2:
	return Rect2(position.x - 22.0, position.y - 18.0, 44.0, 36.0)

func _physics_process(delta: float) -> void:
	position.x += _dir * SPEED * delta
	if position.x < 48.0:
		position.x = 48.0
		_dir = 1.0
	elif position.x > 208.0:
		position.x = 208.0
		_dir = -1.0
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = 1.6
		if _root and is_instance_valid(_root):
			_root.boss_fire(position)
	if _flash_t > 0.0:
		_flash_t -= delta
		_spr.modulate = Color(1, 0.5, 0.5) if int(_flash_t * 30.0) % 2 == 0 else Color.WHITE
		if _flash_t <= 0.0:
			_spr.modulate = Color.WHITE

func take_hit() -> void:
	hp -= 1
	_flash_t = 0.15
	if _root and is_instance_valid(_root):
		_root.boss_hp_changed(hp, max_hp)
		if hp <= 0:
			_root.boss_defeated()
