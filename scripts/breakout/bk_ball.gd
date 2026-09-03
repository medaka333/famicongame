extends Node2D
## ブロック崩し: ボール。サブステップCCD + 円-AABB反射。
## ブロック/ボスとの判定は breakout.gd の ball_collide() に委譲（法線を bounce() で受ける）。

var R := 3.0
var velocity := Vector2.ZERO
var speed := 116.0
var base_speed := 116.0
var stuck := true
## ボスへ連続でダメージを入れないための間隔(breakout.gd が設定・ここで減らす)
var boss_hit_cd := 0.0
var _thru_t := 0.0
var _big_t := 0.0
var _trail_t := 0.0
var _root: Node
var _paddle: Node

signal lost(ball)

func setup(root: Node, paddle: Node, spd: float) -> void:
	_root = root
	_paddle = paddle
	speed = spd
	base_speed = spd

func is_thru() -> bool:
	return _thru_t > 0.0

func set_thru(dur: float) -> void:
	_thru_t = maxf(_thru_t, dur)

func set_big(dur: float) -> void:
	_big_t = maxf(_big_t, dur)

func is_big() -> bool:
	return _big_t > 0.0

func launch(dir_x := 0.0) -> void:
	if not stuck:
		return
	stuck = false
	var a := deg_to_rad(clampf(dir_x, -0.5, 0.5) * 60.0 + randf_range(-12.0, 12.0))
	velocity = Vector2(sin(a), -cos(a)) * speed
	AudioManager.play_se("shot")

func launch_dir(v: Vector2) -> void:
	stuck = false
	if v.length() > 0.01:
		velocity = v.normalized() * speed

func _physics_process(delta: float) -> void:
	if boss_hit_cd > 0.0:
		boss_hit_cd -= delta
	if _thru_t > 0.0:
		_thru_t -= delta
	if _big_t > 0.0:
		_big_t -= delta
	R = 5.0 if _big_t > 0.0 else 3.0
	if stuck:
		if _paddle and is_instance_valid(_paddle):
			position = Vector2(_paddle.position.x, _paddle.position.y - 8.0)
		queue_redraw()
		return
	if velocity.length() > 0.01:
		velocity = velocity.normalized() * speed
	if is_big() or is_thru():
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.025
			_spawn_trail()
	var steps := 1 + int(velocity.length() * delta / R)
	var sub := delta / float(steps)
	for _i in steps:
		position += velocity * sub
		_walls()
		_paddle_bounce()
		if _root and is_instance_valid(_root):
			_root.ball_collide(self)
		if position.y - R > 244.0:
			lost.emit(self)
			return
	queue_redraw()

func _spawn_trail() -> void:
	# でかボール/貫通ボール専用の残像(パワーアップ状態を画面全体で分かりやすくする)。
	var parent := get_parent()
	if not parent:
		return
	var s := Sprite2D.new()
	s.texture = PixelArt.get_tex("spark")
	s.position = position
	s.modulate = Color(1.0, 0.5, 1.0, 0.4) if _thru_t > 0.0 else Color(1.0, 0.7, 0.2, 0.4)
	s.scale = Vector2(R / 4.0, R / 4.0)
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.22)
	tw.tween_callback(s.queue_free)

func _walls() -> void:
	var hit := false
	if position.x < 8.0 + R and velocity.x < 0.0:
		position.x = 8.0 + R
		velocity.x = absf(velocity.x)
		hit = true
	elif position.x > 248.0 - R and velocity.x > 0.0:
		position.x = 248.0 - R
		velocity.x = -absf(velocity.x)
		hit = true
	if position.y < 8.0 + R and velocity.y < 0.0:
		position.y = 8.0 + R
		velocity.y = absf(velocity.y)
		hit = true
	if hit:
		AudioManager.play_se("cursor")

func _paddle_bounce() -> void:
	if not (_paddle and is_instance_valid(_paddle)):
		return
	var p = _paddle
	var pr := Rect2(p.position.x - p.half_w, p.position.y - 4.0, p.half_w * 2.0, 8.0)
	var closest := position.clamp(pr.position, pr.end)
	if position.distance_to(closest) < R and velocity.y > 0.0:
		var off: float = p.hit_offset(position.x)
		var a := deg_to_rad(off * 60.0)
		velocity = Vector2(sin(a), -cos(a)) * speed
		position.y = pr.position.y - R
		_accelerate()
		AudioManager.play_se("cursor")
		if _root and is_instance_valid(_root):
			_root.notify_paddle_touch()

func bounce(n: Vector2) -> void:
	if velocity.dot(n) < 0.0:
		velocity = velocity.bounce(n)
		_accelerate()
		_enforce_min_vy()

func _accelerate() -> void:
	speed = minf(speed + 2.5, base_speed * 1.8)
	if velocity.length() > 0.01:
		velocity = velocity.normalized() * speed

func _enforce_min_vy() -> void:
	var mv := speed * 0.28
	if absf(velocity.y) < mv:
		velocity.y = mv if velocity.y >= 0.0 else -mv
		if velocity.length() > 0.01:
			velocity = velocity.normalized() * speed

func _draw() -> void:
	draw_circle(Vector2.ZERO, R + 1.0, Color(1, 1, 1, 0.25))
	var col := Color(1, 1, 1)
	if _thru_t > 0.0:
		col = Color(1.0, 0.5, 1.0)
	if _big_t > 0.0:
		col = Color(1.0, 0.7, 0.2)   # でかボール=オレンジ
	draw_circle(Vector2.ZERO, R, col)
