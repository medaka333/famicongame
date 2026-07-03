extends Node2D
## ブロック崩し: プレイ枠の壁を見やすく描く固定フレーム。
## 反射: 左(x=8) / 右(x=248) / 上(y=8)。底は壁なし＝落下(ミス)。
## World とは別ノード（shake しない）。反射面を明るくして「どこで跳ね返るか」を明示。

const T := 8.0        # 壁の厚み（内側の面＝反射位置）
const W := 256.0
const H := 240.0

var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var wall := Color8(96, 100, 124)
	var hi := Color8(184, 200, 244)    # 反射面（明るい）= ここで跳ね返る
	var rivet := Color8(150, 158, 196)
	# 壁本体
	draw_rect(Rect2(0, 0, T, H), wall)                  # 左
	draw_rect(Rect2(W - T, 0, T, H), wall)              # 右
	draw_rect(Rect2(0, 0, W, T), wall)                  # 上
	# 反射面の明るいフチ
	draw_rect(Rect2(T - 2.0, T, 2.0, H - T), hi)        # 左の面
	draw_rect(Rect2(W - T, T, 2.0, H - T), hi)          # 右の面
	draw_rect(Rect2(T, T - 2.0, W - T * 2.0, 2.0), hi)  # 上の面
	# リベット（NESらしさ）
	var yy := T + 8.0
	while yy < H - 6.0:
		draw_rect(Rect2(2.0, yy, 3.0, 3.0), rivet)
		draw_rect(Rect2(W - 5.0, yy, 3.0, 3.0), rivet)
		yy += 20.0
	# 底＝壁なし(落ちる)。危険ストライプ点滅で注意喚起
	var blink := 0.5 + 0.5 * sin(_t * 6.0)
	var dng := Color(0.95, 0.25, 0.25, 0.3 + 0.45 * blink)
	var x := T
	while x < W - T:
		draw_rect(Rect2(x, H - 3.0, 6.0, 3.0), dng)
		x += 12.0
