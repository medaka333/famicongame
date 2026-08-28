extends Area2D
## ブロック崩し: パドル。横移動 + 落下アイテム取得(Area2D)。
## EXPAND=拡張(残ライフ間)。

const SPEED := 210.0 ## 175 * 1.2 (ゲームスピード1.2倍)
var base_half := 16.0
var half_w := 16.0
var _expanded := false
var _cs: CollisionShape2D
var _color := Color(0.36, 0.66, 1.0)
var _flash_t := 0.0
var _flash_col := Color.WHITE
var _root: Node

func setup(bh: float, root: Node = null) -> void:
	base_half = bh
	half_w = bh
	_root = root

func _ready() -> void:
	collision_layer = Const.bit(Const.L_PLAYER)
	collision_mask = Const.bit(Const.L_ITEM)
	_cs = CollisionShape2D.new()
	_cs.shape = RectangleShape2D.new()
	add_child(_cs)
	_apply()
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		queue_redraw()
	var target := base_half
	if _expanded:
		target = minf(base_half + 8.0, 32.0)
	if not is_equal_approx(target, half_w):
		half_w = target
		_apply()
	var dir := 0.0
	if GameState.is_demo:
		dir = _demo_dir()
	else:
		dir = Input.get_axis("move_left", "move_right")
	position.x = clampf(position.x + dir * SPEED * delta, 8.0 + half_w, 248.0 - half_w)

func _demo_dir() -> float:
	# デモ中は最もパドルに近い(y最大の)ボールを追いかける
	if not (_root and is_instance_valid(_root)):
		return 0.0
	var balls: Array = _root.balls
	var target = null
	var best_y := -INF
	for b in balls:
		if is_instance_valid(b) and b.position.y > best_y:
			best_y = b.position.y
			target = b
	if target == null:
		return 0.0
	var diff: float = target.position.x - position.x
	if absf(diff) < 4.0:
		return 0.0
	return signf(diff)

func _apply() -> void:
	(_cs.shape as RectangleShape2D).size = Vector2(half_w * 2.0, 8.0)
	queue_redraw()

func hit_offset(bx: float) -> float:
	return clampf((bx - position.x) / half_w, -1.0, 1.0)

func expand() -> void:
	_expanded = true

func reset_size() -> void:
	_expanded = false

func flash(c: Color) -> void:
	_flash_col = c
	_flash_t = 0.35

func _on_area_entered(a: Area2D) -> void:
	if a.has_method("pickup"):
		a.pickup()

func _draw() -> void:
	var body := _color
	if _flash_t > 0.0:
		body = _color.lerp(_flash_col, _flash_t / 0.35)
	draw_rect(Rect2(-half_w, -4, half_w * 2.0, 8.0), body)
	draw_rect(Rect2(-half_w, -4, half_w * 2.0, 2.0), Color(0.8, 0.95, 1.0))
	draw_rect(Rect2(-half_w, 2, half_w * 2.0, 2.0), Color(0.1, 0.3, 0.6))
	if _flash_t > 0.0:
		var a := 0.6 * _flash_t / 0.35
		draw_rect(Rect2(-half_w - 1.0, -5.0, half_w * 2.0 + 2.0, 10.0), Color(_flash_col.r, _flash_col.g, _flash_col.b, a), false, 2.0)
