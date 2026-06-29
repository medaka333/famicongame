extends Node2D
## ブロック崩し: ブロック1個。通常 / 硬い(H,2HP) / 鋼鉄(K,不壊)。
## 当たり判定は breakout.gd が rect() を走査して行う（§6）。

var hp := 1
var breakable := true
var score := 50
var color := Color.WHITE
var alive := true

func setup(col: Color, sc: int, hp_: int, breakable_: bool) -> void:
	color = col
	score = sc
	hp = hp_
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
	color = color.lightened(0.3)
	queue_redraw()
	return false

func _draw() -> void:
	draw_rect(Rect2(-8, -4, 16, 8), color)
	draw_rect(Rect2(-8, -4, 16, 1), Color(1, 1, 1, 0.55))
	draw_rect(Rect2(-8, 3, 16, 1), Color(0, 0, 0, 0.4))
	if not breakable:
		draw_rect(Rect2(-7, -3, 2, 2), Color(1, 1, 1, 0.5))
		draw_rect(Rect2(5, -3, 2, 2), Color(1, 1, 1, 0.5))
