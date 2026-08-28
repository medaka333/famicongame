extends Node2D
## ブロック崩し: ボス(最終面)。上部で左右往復・増援ブロック召喚・HP制。
## 攻撃(弾)は持たない: プレイヤーに直接危険が及ばないよう、代わりに定期的にブロックを増援召喚する。
## ボール命中判定は breakout.gd 側（rect() を使用）。撃破/HP変化は _root へ通知。

const SPEED := 45.0
var hp := 40
var max_hp := 40
var _dir := 1.0
var _root: Node
var _spawn_t := 2.2
var _spr: Sprite2D
var _flash_t := 0.0
var _burst_half_done := false
var _burst_quarter_done := false

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
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = randf_range(2.0, 3.0)
		if _root and is_instance_valid(_root):
			_root.boss_spawn_block()
	if _flash_t > 0.0:
		_flash_t -= delta
		_spr.modulate = Color(1, 0.5, 0.5) if int(_flash_t * 30.0) % 2 == 0 else Color.WHITE
		if _flash_t <= 0.0:
			_spr.modulate = Color.WHITE

func take_hit(damage: int = 1) -> void:
	hp -= damage
	_flash_t = 0.15
	if _root and is_instance_valid(_root):
		_root.boss_hp_changed(hp, max_hp)
		if not _burst_half_done and hp <= max_hp / 2:
			_burst_half_done = true
			_root.boss_spawn_block_burst(10)
		if not _burst_quarter_done and hp <= max_hp / 4:
			_burst_quarter_done = true
			_root.boss_spawn_block_burst(10)
		if hp <= 0:
			_root.boss_defeated()
