extends Control

const GAME_SCENE: String = "res://scenes/main.tscn"

var continue_button: Button

func _ready() -> void:
	get_tree().paused = false
	_set_menu_background()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(300, 260)
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	var heading := Label.new()
	heading.text = "SKYWARD TALES"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	column.add_child(heading)
	var caption := Label.new()
	caption.text = "Фэнтезийное приключение"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	_add_button(column, "Новая игра", _start_new)
	continue_button = _add_button(column, "Продолжить", _continue_game)
	continue_button.disabled = SaveSystem.load_snapshot().is_empty()
	_add_button(column, "Выход", _exit_game)

func _set_menu_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.045, 0.09, 0.105)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

func _add_button(parent: VBoxContainer, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(260, 38)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _start_new() -> void:
	get_tree().set_meta("skyward_continue", false)
	get_tree().change_scene_to_file(GAME_SCENE)

func _continue_game() -> void:
	if SaveSystem.load_snapshot().is_empty():
		return
	get_tree().set_meta("skyward_continue", true)
	get_tree().change_scene_to_file(GAME_SCENE)

func _exit_game() -> void:
	get_tree().quit()
