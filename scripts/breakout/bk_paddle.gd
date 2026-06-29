extends Area2D
## ブロック崩し: パドル。横移動 + 落下アイテム取得(Area2D)。
## EXPAND=拡張(残ライフ間) / shrink=ボス弾被弾で一時縮小。

const SPEED := 175.0
var base_half := 16.0
var half_w := 16.0
var _expanded := false
var _shrink_t := 0.0
var _cs: CollisionShape2D
var _color := Color(0.36, 0.66, 1.0)

func setup(bh: float) -> void:
	base_half = bh
	half_w = bh

func _ready() -> void:
	collision_layer = Const.bit(Const.L_PLAYER)
	collision_mask = Const.bit(Const.L_ITEM)
	_cs = CollisionShape2D.new()
	_cs.shape = RectangleShape2D.new()
	add_child(_cs)
	_apply()
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if _shrink_t > 0.0:
		_shrink_t -= delta
	var target := base_half
	if _expanded:
		target = minf(base_half + 8.0, 32.0)
	if _shrink_t > 0.0:
		target = maxf(base_half * 0.6, 10.0)
	if not is_equal_approx(target, half_w):
		half_w = target
		_apply()
	var dir := 0.0
	if not GameState.is_demo:
		dir = Input.get_axis("move_left", "move_right")
	position.x = clampf(position.x + dir * SPEED * delta, 8.0 + half_w, 248.0 - half_w)

func _apply() -> void:
	(_cs.shape as RectangleShape2D).size = Vector2(half_w * 2.0, 8.0)
	queue_redraw()

func hit_offset(bx: float) -> float:
	return clampf((bx - position.x) / half_w, -1.0, 1.0)

func expand() -> void:
	_expanded = true

func reset_size() -> void:
	_expanded = false
	_shrink_t = 0.0

func shrink(dur: float) -> void:
	_shrink_t = maxf(_shrink_t, dur)

func _on_area_entered(a: Area2D) -> void:
	if a.has_method("pickup"):
		a.pickup()

func _draw() -> void:
	draw_rect(Rect2(-half_w, -4, half_w * 2.0, 8.0), _color)
	draw_rect(Rect2(-half_w, -4, half_w * 2.0, 2.0), Color(0.8, 0.95, 1.0))
	draw_rect(Rect2(-half_w, 2, half_w * 2.0, 2.0), Color(0.1, 0.3, 0.6))
