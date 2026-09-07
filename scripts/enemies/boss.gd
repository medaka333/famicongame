extends Area2D
class_name Boss
## ボス（M15）。ステージ毎にスプライト＆攻撃パターンが変わる。撃破時に敵弾全消し。

const BULLET_SCENE := preload("res://scenes/bullets/EnemyBullet.tscn")
const EXPLOSION_SCENE := preload("res://scenes/fx/Explosion.tscn")

var _max_hp: int = 40
var _hp: int = 40
var _sprite: String = "boss1"
var _phase: int = 1
var _dir: float = 1.0
var _move_speed: float = 45.0
var _fire_t: float = 1.0
var _alive: bool = true
## boss2 フェーズ3の薙ぎ払い用。撃つたびに扇の向きをずらす
var _sweep: int = 0
## 出現からの経過時間。HPだけでなく時間でもフェーズを上げる(#11)
var _age: float = 0.0
## フェーズ2 / 3 に上がる経過時間(秒)
const PHASE_TIME := [16.0, 32.0]

func setup(hp: int, sprite: String) -> void:
	_max_hp = hp
	_hp = hp
	_sprite = sprite

func _ready() -> void:
	add_to_group(Const.G_ENEMIES)
	collision_layer = Const.bit(Const.L_ENEMY)
	collision_mask = 0
	if _sprite == "boss1":
		var tex := load("res://assets/sprites/boss1_crab.png") as Texture2D
		$Visual.texture = tex
		if tex != null and tex.get_width() > 56:
			var s := 56.0 / float(tex.get_width())
			$Visual.scale = Vector2(s, s)
	else:
		$Visual.texture = PixelArt.get_tex(_sprite)
	GameState.boss_appeared.emit()
	GameState.boss_hp_changed.emit(_hp, _max_hp)

func _physics_process(delta: float) -> void:
	if not _alive:
		return
	position.x += _dir * _move_speed * delta
	if position.x < 30.0:
		position.x = 30.0
		_dir = 1.0
	elif position.x > 226.0:
		position.x = 226.0
		_dir = -1.0
	# 時間経過でもフェーズを上げる。低火力で長引くほど厳しくなり、
	# 「時間をかけるほど難しくなる」時間ペナルティになる(HPによる移行は据え置き)。
	_age += delta
	if _phase < 2 and _age >= PHASE_TIME[0]:
		_advance_phase(2)
	elif _phase < 3 and _age >= PHASE_TIME[1]:
		_advance_phase(3)
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = _fire_interval()
		_attack()

func _fire_interval() -> float:
	if _sprite == "boss2":
		# 2面ボスはフェーズ3が急に強くなりすぎていた(回避AIへの被弾が3面ボスの
		# 最終形態より多い8発 vs 7発)ため、間隔を詰めない。フェーズ3は薙ぎ払いで
		# 画面を広く覆うので、発射間隔はフェーズ2と同じで十分きつい。
		return [1.2, 0.9, 0.9][_phase - 1]
	return [1.2, 0.9, 0.6][_phase - 1]

func _attack() -> void:
	var bullets := get_tree().get_first_node_in_group("bullet_container") as Node2D
	if bullets == null:
		return
	match _sprite:
		"boss2":
			_attack_crab(bullets)
		"boss3":
			_attack_final(bullets)
		_:
			_attack_fortress(bullets)

# boss1: 自機狙い → 3way → 全方位8
func _attack_fortress(bullets: Node2D) -> void:
	match _phase:
		1:
			_shoot(bullets, _aim() * 150.0)
		2:
			for a in [-0.35, 0.0, 0.35]:
				_shoot(bullets, Vector2(sin(a), cos(a)) * 150.0)
		_:
			for i in 8:
				var ang := TAU * i / 8.0
				_shoot(bullets, Vector2(cos(ang), sin(ang)) * 130.0)

# boss2: 斜め2way+自機狙い → 扇5way+自機狙い → 扇5way+自機狙い2(広め)
# 以前は フェーズ1「斜め2発だけ」/ フェーズ3「自機狙い拡散3を0.6秒間隔」で落差が極端だった。
# フェーズ1は自機の正面に一切飛んでこず被弾率0%、フェーズ3は3面ボスより当たっていた。
# 「最初から狙ってくる蟹」として、フェーズが上がるほど弾が増える形に均した。
func _attack_crab(bullets: Node2D) -> void:
	match _phase:
		1:
			# 斜め弾は蟹らしさとして残しつつ、自機狙いを1発混ぜて「狙ってくる」と分からせる
			_shoot(bullets, Vector2(-120, 90))
			_shoot(bullets, Vector2(120, 90))
			_shoot(bullets, _aim() * 140.0)
		2:
			# 元のまま(扇5way)。ここは「順当」との評価だったので触らない
			for a in [-0.6, -0.3, 0.0, 0.3, 0.6]:
				_shoot(bullets, Vector2(sin(a), cos(a)) * 140.0)
		_:
			# 元は「自機狙いを±0.2で3発 × 0.6秒間隔」で、3面ボスの最終形態より当たっていた。
			# 3面ボスが「パターンが一定で読めばかわせる」良い調整なので、こちらもその方向に
			# 変更し、扇5wayを左右に振る薙ぎ払いにした。狙い撃ちではないので理不尽にならない。
			const SWEEP := [-0.5, -0.25, 0.0, 0.25, 0.5, 0.25, 0.0, -0.25]
			var base: float = SWEEP[_sweep % SWEEP.size()]
			_sweep += 1
			for a in [-0.5, -0.25, 0.0, 0.25, 0.5]:
				_shoot(bullets, Vector2(sin(base + a), cos(base + a)) * 140.0)

# boss3: 3way → 全方位8 → 全方位12 + 自機狙い（激しい・ADULT専用）
func _attack_final(bullets: Node2D) -> void:
	match _phase:
		1:
			for a in [-0.35, 0.0, 0.35]:
				_shoot(bullets, Vector2(sin(a), cos(a)) * 150.0)
		2:
			for i in 8:
				var ang := TAU * i / 8.0
				_shoot(bullets, Vector2(cos(ang), sin(ang)) * 130.0)
		_:
			for i in 12:
				var ang := TAU * i / 12.0
				_shoot(bullets, Vector2(cos(ang), sin(ang)) * 120.0)
			_shoot(bullets, _aim() * 180.0)

func _aim() -> Vector2:
	var p := get_tree().get_first_node_in_group(Const.G_PLAYER) as Node2D
	return (p.global_position - global_position).normalized() if p else Vector2.DOWN

func _shoot(container: Node2D, vel: Vector2) -> void:
	var b := BULLET_SCENE.instantiate()
	container.add_child(b)
	b.global_position = global_position
	b.setup(vel * GameState.bullet_speed_mul())

func take_damage(amount: int) -> void:
	if not _alive:
		return
	_hp -= amount
	GameState.boss_hp_changed.emit(maxi(_hp, 0), _max_hp)
	get_tree().call_group("game", "add_shake", 0.05)
	_flash()
	if _hp <= _max_hp * 2 / 3 and _phase < 2:
		_advance_phase(2)
	if _hp <= _max_hp / 3 and _phase < 3:
		_advance_phase(3)
	if _hp <= 0:
		_die()

func _advance_phase(n: int) -> void:
	_phase = n
	_move_speed = 65.0 if n == 2 else 90.0

func _flash() -> void:
	$Visual.modulate = Color(1.6, 1.6, 1.6)
	await get_tree().create_timer(0.04).timeout
	if is_instance_valid(self):
		$Visual.modulate = Color(1.0, 1.0, 1.0)

func _die() -> void:
	_alive = false
	# 撃破時に敵弾を全消し（理不尽死防止）
	for b in get_tree().get_nodes_in_group("enemy_bullet"):
		b.queue_free()
	GameState.add_score(5000)
	GameState.boss_defeated.emit()
	var fx_c := get_tree().get_first_node_in_group("fx_container") as Node2D
	for i in 8:
		if fx_c:
			var fx := EXPLOSION_SCENE.instantiate()
			fx_c.add_child(fx)
			fx.global_position = global_position + Vector2(randf_range(-18, 18), randf_range(-12, 12))
		AudioManager.play_se("explosion")
		get_tree().call_group("game", "add_shake", 0.2)
		await get_tree().create_timer(0.12).timeout
	queue_free()
