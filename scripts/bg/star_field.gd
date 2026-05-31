extends Node2D
## 背景の星スクロール（M12 強化）。3 層を 速度・色・サイズで奥行き表現。

const COUNT := 64
const SPEEDS := [16.0, 30.0, 52.0]
const COLORS := [Color(0.35, 0.35, 0.5), Color(0.6, 0.6, 0.85), Color(0.95, 0.95, 1.0)]

var _pos: Array[Vector2] = []
var _layer: Array[int] = []

func _ready() -> void:
	for i in COUNT:
		_pos.append(Vector2(randi() % 256, randi() % 240))
		_layer.append(i % 3)

func _process(delta: float) -> void:
	for i in COUNT:
		_pos[i].y += SPEEDS[_layer[i]] * delta
		if _pos[i].y >= 240.0:
			_pos[i].y -= 240.0
			_pos[i].x = randi() % 256
	queue_redraw()

func _draw() -> void:
	for i in COUNT:
		var l := _layer[i]
		var sz := 2.0 if l == 2 else 1.0
		draw_rect(Rect2(_pos[i].floor(), Vector2(sz, sz)), COLORS[l])
