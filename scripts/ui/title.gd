extends Node2D
## タイトル（M14）。KIDS/ADULT 選択 + 操作説明 + 放置デモ。

var _sel: int = 0
var _idle: float = 0.0

func _ready() -> void:
	GameState.is_demo = false
	AudioManager.stop_bgm()
	GameState.difficulty = GameState.Diff.KIDS
	$HiScoreLabel.text = "HI-SCORE  %06d" % GameState.hi_score
	_refresh()
	_blink()

func _refresh() -> void:
	$KidsLabel.text = ("> " if _sel == 0 else "  ") + "KIDS  - EASY -"
	$AdultLabel.text = ("> " if _sel == 1 else "  ") + "ADULT - HARD -"

func _process(delta: float) -> void:
	_idle += delta
	if _idle >= 12.0:
		GameState.is_demo = true
		get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _blink() -> void:
	while is_inside_tree():
		$PressStart.modulate.a = 1.0
		await get_tree().create_timer(0.6).timeout
		if not is_inside_tree():
			return
		$PressStart.modulate.a = 0.0
		await get_tree().create_timer(0.4).timeout

func _unhandled_input(event: InputEvent) -> void:
	_idle = 0.0
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_C:
		get_tree().change_scene_to_file("res://scenes/ui/KeyConfig.tscn")
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		_sel = 1 - _sel
		_refresh()
	elif event.is_action_pressed("shoot") or event.is_action_pressed("ui_select_start"):
		GameState.difficulty = _sel
		get_tree().change_scene_to_file("res://scenes/game/Game.tscn")
