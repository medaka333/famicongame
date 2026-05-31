extends Resource
class_name EnemyDef
## 敵の定義リソース（.tres で差し替え可能）。§5.5

@export var id: String = "grunt"
@export var max_hp: int = 1
@export var speed: float = 50.0
@export var score: int = 100
@export_enum("straight", "sine", "homing") var move_pattern: String = "straight"
@export var fire_interval: float = 0.0   # 0 = 撃たない
@export var item_drop_chance: float = 0.0
@export var sprite_name: String = "zako_red"
