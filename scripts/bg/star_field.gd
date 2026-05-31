extends Node2D
## 背景の星スクロール（M5）。3 層速度で奥行きを表現。

const COUNT := 56
const SPEEDS := [18.0, 32.0, 52.0]

var _pos: Array[Vector2] = []
var _spd: Array[float] = []

func _ready() -> void:
	for i in COUNT:
		_pos.append(Vector2(randi() % 256, randi() % 240))
		_spd.append(SPEEDS[i % SPEEDS.size()])

func _process(delta: float) -> void:
	for i in COUNT:
		_pos[i].y += _spd[i] * delta
		if _pos[i].y >= 240.0:
			_pos[i].y -= 240.0
			_pos[i].x = randi() % 256
	queue_redraw()

func _draw() -> void:
	for i in COUNT:
		var b := 0.35 + (_spd[i] / 52.0) * 0.5
		draw_rect(Rect2(_pos[i].floor(), Vector2.ONE), Color(b, b, b))
