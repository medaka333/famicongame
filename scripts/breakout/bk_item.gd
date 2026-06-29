extends Area2D
## ブロック崩し: 落下アイテム。E=拡張 / M=マルチ / S=減速 / T=貫通 / U=1UP。
## パドルが area_entered で pickup() を呼ぶ。

const FALL := 70.0
var kind := "E"
var _root: Node

const TINT := {
	"E": Color(0.4, 1.0, 0.4),
	"M": Color(0.4, 0.8, 1.0),
	"S": Color(1.0, 0.9, 0.3),
	"T": Color(1.0, 0.5, 1.0),
	"U": Color(1.0, 0.4, 0.4),
}
const LETTER := {"E": "E", "M": "M", "S": "S", "T": "T", "U": "1"}

func setup(root: Node, k: String) -> void:
	_root = root
	kind = k

func _ready() -> void:
	collision_layer = Const.bit(Const.L_ITEM)
	collision_mask = 0
	add_to_group(Const.G_ITEMS)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	cs.shape = rect
	add_child(cs)
	var spr := Sprite2D.new()
	spr.texture = PixelArt.get_tex("item")
	spr.modulate = TINT.get(kind, Color.WHITE)
	add_child(spr)
	var lbl := Label.new()
	lbl.text = LETTER.get(kind, "?")
	lbl.position = Vector2(-4, -11)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color.BLACK)
	add_child(lbl)

func _physics_process(delta: float) -> void:
	position.y += FALL * delta
	if position.y > 248.0:
		queue_free()

func pickup() -> void:
	if _root and is_instance_valid(_root):
		_root.apply_item(kind)
	queue_free()
