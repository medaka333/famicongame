extends Node2D
class_name Explosion
## 爆発エフェクト（M14）。3 フレームのドットアニメ → 消滅。

const FRAMES := ["exp0", "exp1", "exp2"]
const FRAME_TIME := 0.06

var _i: int = 0
var _t: float = 0.0
@onready var _spr: Sprite2D = $Visual

func _ready() -> void:
	_spr.texture = PixelArt.get_tex(FRAMES[0])

func _process(delta: float) -> void:
	_t += delta
	if _t >= FRAME_TIME:
		_t = 0.0
		_i += 1
		if _i >= FRAMES.size():
			queue_free()
		else:
			_spr.texture = PixelArt.get_tex(FRAMES[_i])
