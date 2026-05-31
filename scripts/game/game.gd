extends Node2D
## プレイ画面ルート（M14）。背景・シェイク・ポーズ・BGM・デモ制御。

@onready var _world: Node2D = $World

var _trauma: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game")
	$World/EnemyContainer.add_to_group("enemy_container")
	$World/BulletContainer.add_to_group("bullet_container")
	$World/ItemContainer.add_to_group("item_container")
	$World/FXContainer.add_to_group("fx_container")
	GameState.reset_run()
	GameState.game_over.connect(_on_game_over)
	GameState.all_clear.connect(_on_all_clear)
	if GameState.is_demo:
		_run_demo()

func _run_demo() -> void:
	await get_tree().create_timer(22.0).timeout
	if GameState.is_demo:
		GameState.is_demo = false
		get_tree().change_scene_to_file("res://scenes/ui/Title.tscn")

func add_shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)

func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(_trauma - delta * 1.5, 0.0)
		var amt := _trauma * _trauma * 4.0
		_world.position = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
	elif _world.position != Vector2.ZERO:
		_world.position = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_demo:
		if event.is_pressed():
			GameState.is_demo = false
			get_tree().change_scene_to_file("res://scenes/ui/Title.tscn")
		return
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused

func _on_game_over() -> void:
	AudioManager.stop_bgm()
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")

func _on_all_clear() -> void:
	await get_tree().create_timer(5.0).timeout
	AudioManager.stop_bgm()
	get_tree().change_scene_to_file("res://scenes/ui/Title.tscn")
