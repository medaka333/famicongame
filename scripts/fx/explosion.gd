extends Node2D
class_name Explosion
## 爆発エフェクト（M2）。Tween でフラッシュ→縮小→消滅。

func _ready() -> void:
	var poly := $Visual as Polygon2D
	var tw := create_tween()
	tw.tween_property(poly, "scale", Vector2(2.0, 2.0), 0.05)
	tw.tween_property(poly, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)
