extends Node2D
## ブロック崩し: ブロック1個。通常 / 硬い(複数HP) / 鋼鉄(K,不壊)。
## 複数HPブロックは残HP(=あと何回)を入れ子の層で表示。二重=あと2、三重=あと3。
## 当たり判定は breakout.gd が rect() を走査して行う（§6）。

var hp := 1
var max_hp := 1
var breakable := true
var score := 50
var color := Color.WHITE
var alive := true
## ボスが増援として召喚したブロックか(アイテムドロップ率を変えるため)
var from_boss := false
## 最終的に置かれる位置。増援ブロックは飛行中 position がボスの位置になるため、
## 「どの枠を使う予定か」はこちらで持つ(重複配置の判定に使う)。
var dest := Vector2.ZERO

func setup(col: Color, sc: int, hp_: int, breakable_: bool) -> void:
	color = col
	score = sc
	hp = hp_
	max_hp = hp_
	breakable = breakable_

func rect() -> Rect2:
	return Rect2(position.x - 8.0, position.y - 4.0, 16.0, 8.0)

func hit() -> bool:
	# true = 破壊された
	if not breakable:
		return false
	hp -= 1
	if hp <= 0:
		return true
	queue_redraw()
	return false

func _draw() -> void:
	draw_rect(Rect2(-8, -4, 16, 8), color)
	draw_rect(Rect2(-8, -4, 16, 1), Color(1, 1, 1, 0.55))
	draw_rect(Rect2(-8, 3, 16, 1), Color(0, 0, 0, 0.4))
	if not breakable:
		draw_rect(Rect2(-7, -3, 2, 2), Color(1, 1, 1, 0.5))
		draw_rect(Rect2(5, -3, 2, 2), Color(1, 1, 1, 0.5))
		return
	if max_hp <= 1:
		return
	# 残HP = 入れ子の層数。二重=あと2、三重=あと3。当たるたび外側の層が1枚剥がれる。
	# 内側ほど明るく塗って層の重なりを立体的に見せる。
	for i in hp:
		var ins := float(i)
		var r := Rect2(-8.0 + ins * 2.0, -4.0 + ins, 16.0 - ins * 4.0, 8.0 - ins * 2.0)
		if i > 0:
			draw_rect(r, color.lightened(0.14 * ins))
		draw_rect(r, Color(0, 0, 0, 0.5), false, 1.0)
