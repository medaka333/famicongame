extends Node2D
class_name Explosion
## 爆発エフェクト（M8）。ドット絵を拡大→フェードで消す。

func _ready() -> void:
	var spr := $Visual as Sprite2D
	spr.texture = PixelArt.get_tex("explosion")
	spr.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(spr, "scale", Vector2(1.4, 1.4), 0.06)
	tw.tween_property(spr, "modulate:a", 0.0, 0.14)
	tw.tween_callback(queue_free)
