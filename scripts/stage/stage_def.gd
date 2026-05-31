extends Resource
class_name StageDef
## ステージ定義（M10）。1 ステージ分のザコ構成・難度・ボス HP・背景色。

@export var enemy_defs: Array[EnemyDef] = []
@export var spawn_interval: float = 1.2
@export var zako_duration: float = 14.0
@export var boss_hp: int = 40
@export var boss_sprite: String = "boss1"
@export var bg_color: Color = Color(0.04, 0.05, 0.16)
