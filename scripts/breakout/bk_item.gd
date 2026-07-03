extends Area2D
## ブロック崩し: 落下アイテム。E=拡張 / M=マルチ / T=貫通 / B=でかボール / U=1UP。
## パドルが area_entered で pickup() を呼ぶ。
## 視認性: 色付き宝石 + 大きい文字(黒フチ) + 点滅わく + 脈動。当たりは広め。

const FALL := 64.0
var kind := "E"
var _root: Node
var _t := 0.0
var _lbl: Label

# 種別カラー（breakout.gd の取得演出からも参照する）
const COL := {
	"E": Color8(64, 220, 96),    # みどり = ワイド
	"M": Color8(72, 160, 252),   # あお   = マルチ
	"T": Color8(220, 96, 252),   # むらさき= つらぬき
	"B": Color8(255, 160, 40),   # オレンジ= でかボール
	"U": Color8(255, 210, 50),   # きん   = 1UP（超レア）
}
const LETTER := {"E": "E", "M": "M", "T": "T", "B": "B", "U": "1"}

func setup(root: Node, k: String) -> void:
	_root = root
	kind = k

func _ready() -> void:
	collision_layer = Const.bit(Const.L_ITEM)
	collision_mask = 0
	add_to_group(Const.G_ITEMS)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 18)   # 取りやすく広め
	cs.shape = rect
	add_child(cs)
	_lbl = Label.new()
	_lbl.text = LETTER.get(kind, "?")
	_lbl.size = Vector2(16, 16)
	_lbl.position = Vector2(-8, -9)
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl.add_theme_font_size_override("font_size", 12)
	_lbl.add_theme_color_override("font_color", Color.WHITE)
	_lbl.add_theme_constant_override("outline_size", 4)
	_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_lbl)

func _process(delta: float) -> void:
	_t += delta
	var amp := 0.18 if kind == "U" else 0.10   # レアは強く脈動
	var freq := 10.0 if kind == "U" else 8.0
	var s := 1.0 + sin(_t * freq) * amp
	scale = Vector2(s, s)
	queue_redraw()

func _physics_process(delta: float) -> void:
	var fall := 52.0 if kind == "U" else FALL   # レアは取りやすく ゆっくり
	position.y += fall * delta
	if position.y > 248.0:
		queue_free()

func pickup() -> void:
	if _root and is_instance_valid(_root):
		_root.apply_item(kind)
	queue_free()

func _draw() -> void:
	var c: Color = COL.get(kind, Color.WHITE)
	if kind == "U":
		_draw_rare(c)
		return
	# 点滅する外わく（落下中から気づけるように）
	var blink := 0.5 + 0.5 * sin(_t * 12.0)
	draw_rect(Rect2(-10, -10, 20, 20), Color(1, 1, 1, 0.18 + 0.5 * blink), false, 1.0)
	# 本体（ふち→中身→上ハイライト→下かげ）
	draw_rect(Rect2(-8, -8, 16, 16), Color.BLACK)
	draw_rect(Rect2(-7, -7, 14, 14), c)
	draw_rect(Rect2(-7, -7, 14, 4), c.lightened(0.45))
	draw_rect(Rect2(-7, 5, 14, 2), c.darkened(0.4))

# 1UP=超レア: 虹色わく + 金の宝石 + きらめき
func _draw_rare(c: Color) -> void:
	var hue := fmod(_t * 0.6, 1.0)
	var rainbow := Color.from_hsv(hue, 0.85, 1.0)
	draw_rect(Rect2(-11, -11, 22, 22), Color(rainbow.r, rainbow.g, rainbow.b, 0.75), false, 2.0)
	draw_rect(Rect2(-8, -8, 16, 16), Color.BLACK)
	draw_rect(Rect2(-7, -7, 14, 14), c)
	draw_rect(Rect2(-7, -7, 14, 5), c.lightened(0.55))
	draw_rect(Rect2(-7, 5, 14, 2), c.darkened(0.45))
	var sp := 0.5 + 0.5 * sin(_t * 16.0)
	draw_rect(Rect2(-6, -6, 2, 2), Color(1, 1, 1, sp))
	draw_rect(Rect2(4, 4, 2, 2), Color(1, 1, 1, sp))
	draw_rect(Rect2(4, -6, 2, 2), Color(1, 1, 1, 1.0 - sp))
	draw_rect(Rect2(-6, 4, 2, 2), Color(1, 1, 1, 1.0 - sp))
