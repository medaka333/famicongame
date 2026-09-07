extends Area2D
class_name PowerUp
## パワーアップアイテム（M4）。落下して自機に触れると取得。
## 2種類あり、取ると船のモードが切り替わる(#10):
##   フォーカス(青) = 正面集中。ボスに強いが移動が鈍る
##   ワイド(橙)     = 広角(北前船)。ザコ掃討が速いが当たり判定が大きい

const SPEED := 60.0
const COL_FOCUS := Color(0.55, 0.8, 1.0)
const COL_WIDE := Color(1.0, 0.7, 0.35)

## GameState.ShipMode.FOCUS か WIDE。生成側が setup() で決める
var mode: int = 1

func setup(m: int) -> void:
	mode = m

func _ready() -> void:
	add_to_group(Const.G_ITEMS)
	collision_layer = Const.bit(Const.L_ITEM)
	collision_mask = Const.bit(Const.L_PLAYER)
	area_entered.connect(_on_area_entered)
	# 種類ごとに専用の絵(F / W の文字入り)を使う。
	# 共通の絵を self_modulate で色分けする案は、元の絵が緑のため機能しなかった。
	$Visual.texture = PixelArt.get_tex(
		"item_wide" if mode == GameState.ShipMode.WIDE else "item_focus")
	queue_redraw()

var _t := 0.0

func _color() -> Color:
	return COL_WIDE if mode == GameState.ShipMode.WIDE else COL_FOCUS

## 落下中に目立つよう、絵の後ろで色付きのわくを点滅させる
func _draw() -> void:
	var c := _color()
	var blink := 0.5 + 0.5 * sin(_t * 10.0)
	draw_rect(Rect2(-9, -9, 18, 18), Color(c.r, c.g, c.b, 0.25 + 0.55 * blink), false, 1.0)
	draw_rect(Rect2(-11, -11, 22, 22), Color(c.r, c.g, c.b, 0.12 + 0.25 * blink), false, 1.0)

func _physics_process(delta: float) -> void:
	_t += delta
	$Visual.scale = Vector2.ONE * (1.0 + 0.12 * sin(_t * 9.0))
	queue_redraw()
	position.y += SPEED * delta
	if position.y > 260.0:
		queue_free()

func _on_area_entered(_area: Area2D) -> void:
	GameState.set_ship_mode(mode)
	AudioManager.play_se("powerup")
	queue_free()
