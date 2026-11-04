extends Control

const GAME_SCENE: String = "res://scenes/main.tscn"

var continue_button: Button
var menu_column: VBoxContainer
var creation: HeroCreationPanel

func _ready() -> void:
	get_tree().paused = false
	GameAudio.music("sky")
	# CI smoke test of exported builds: `SkywardTales -- --smoke` opens the world.
	if "--smoke" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
	_set_menu_background()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var version := Label.new()
	version.text = "v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	version.add_theme_font_size_override("font_size", UiFont.px(8))
	version.modulate = Color(1, 1, 1, 0.55)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -60
	version.offset_top = -16
	version.offset_right = -6
	version.offset_bottom = -4
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version)
	menu_column = VBoxContainer.new()
	menu_column.custom_minimum_size = Vector2(300, 0)
	menu_column.add_theme_constant_override("separation", 8)
	center.add_child(menu_column)
	var heading := Label.new()
	heading.text = "SKYWARD TALES"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", UiFont.px(30))
	heading.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	heading.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.16))
	heading.add_theme_constant_override("outline_size", 8)
	menu_column.add_child(heading)
	var caption := Label.new()
	caption.text = "Угасающее небо"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	caption.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.16))
	caption.add_theme_constant_override("outline_size", 5)
	menu_column.add_child(caption)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	menu_column.add_child(spacer)
	_add_button(menu_column, "Новая игра", _start_new)
	continue_button = _add_button(menu_column, "Продолжить", _continue_game)
	continue_button.disabled = SaveSystem.load_latest().is_empty()
	_add_button(menu_column, "Выход", _exit_game)
	creation = HeroCreationPanel.new()
	creation.visible = false
	creation.confirmed.connect(_begin_adventure)
	creation.cancelled.connect(func() -> void:
		creation.visible = false
		menu_column.visible = true)
	center.add_child(creation)

func _set_menu_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.045, 0.09, 0.105)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# The generated meadow, slowly drifting, under a dusk tint.
	var ground := WorldArt.texture("world/greenreach_ground.png")
	if ground != null:
		var art := TextureRect.new()
		art.texture = ground
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.position = Vector2(-120, -160)
		art.size = ground.get_size()
		add_child(art)
		var tween := art.create_tween().set_loops()
		tween.tween_property(art, "position", Vector2(-420, -300), 40.0)
		tween.tween_property(art, "position", Vector2(-120, -160), 40.0)
	var tint := ColorRect.new()
	tint.color = Color(0.06, 0.04, 0.14, 0.55)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tint)

func _add_button(parent: VBoxContainer, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(260, 34)
	button.add_theme_font_size_override("font_size", UiFont.px(18))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _start_new() -> void:
	menu_column.visible = false
	creation.visible = true

func _begin_adventure(hero_name: String, gender: String) -> void:
	get_tree().set_meta("skyward_continue", false)
	get_tree().set_meta("skyward_new_hero", {"name": hero_name, "gender": gender})
	get_tree().change_scene_to_file(GAME_SCENE)

func _continue_game() -> void:
	if SaveSystem.load_latest().is_empty():
		return
	get_tree().set_meta("skyward_continue", true)
	get_tree().change_scene_to_file(GAME_SCENE)

func _exit_game() -> void:
	get_tree().quit()
