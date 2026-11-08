extends Control

const GAME_SCENE: String = "res://scenes/main.tscn"

var continue_button: Button
var menu_column: VBoxContainer
var creation: HeroCreationPanel
var _menu_frame: PanelContainer

static var _display_applied := false

func _ready() -> void:
	get_tree().paused = false
	GameAudio.music("sky")
	if not _display_applied:
		_display_applied = true
		GameSettings.apply_display()
	# CI smoke test of exported builds: `SkywardTales -- --smoke` opens the world.
	if "--smoke" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
	_set_menu_background()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var side := MarginContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	side.offset_left = 28
	side.offset_right = 268
	side.add_theme_constant_override("margin_top", 54)
	add_child(side)
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
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiStyle.panel(true))
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side.add_child(frame)
	menu_column = VBoxContainer.new()
	menu_column.custom_minimum_size = Vector2(220, 0)
	menu_column.add_theme_constant_override("separation", 7)
	frame.add_child(menu_column)
	_menu_frame = frame
	var heading := Label.new()
	heading.text = "SKYWARD TALES"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", UiFont.px(24))
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
	spacer.custom_minimum_size = Vector2(0, 8)
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
		menu_column.visible = true
		_menu_frame.visible = true)
	center.add_child(creation)

func _set_menu_background() -> void:
	# Sky gradient, far clouds, the whole first island floating and bobbing,
	# near clouds drifting in front of its cliffs.
	var sky := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.55, 0.74, 0.93))
	gradient.set_color(1, Color(0.84, 0.92, 0.99))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 8
	texture.height = 128
	sky.texture = texture
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	var holder := SubViewportContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var view := SubViewport.new()
	view.size = Vector2i(640, 360)
	view.transparent_bg = true
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	holder.add_child(view)
	view.add_child(_cloud_layer(Rect2(-120, 20, 880, 340), 12, 0.5, 4.0))
	# Islands: two small ones far away, the big one with the village.
	_floating(view, "ui/title_islet_1.png", Vector2(604, 318), 5.0, 2.6)
	_floating(view, "ui/title_islet_0.png", Vector2(250, 300), 6.0, 3.6)
	_floating(view, "ui/title_island.png", Vector2(440, 170), 7.0, 3.2)
	view.add_child(_cloud_layer(Rect2(-120, 260, 880, 140), 8, 1.0, 9.0))
	var tint := ColorRect.new()
	tint.color = Color(0.06, 0.04, 0.14, 0.12)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

func _floating(view: SubViewport, art: String, at: Vector2, lift: float, period: float) -> void:
	var sprite := Sprite2D.new()
	var hd := art.replace(".png", "_hd.png")
	if ResourceLoader.exists("res://assets/" + hd):
		sprite.texture = WorldArt.texture(hd)
		sprite.scale = Vector2(0.5, 0.5)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		sprite.texture = WorldArt.texture(art)
	sprite.position = at
	view.add_child(sprite)
	var bob := sprite.create_tween().set_loops()
	bob.set_trans(Tween.TRANS_SINE)
	bob.tween_property(sprite, "position:y", at.y + lift, period)
	bob.tween_property(sprite, "position:y", at.y, period)

func _cloud_layer(area: Rect2, count: int, scale_value: float, speed: float) -> Node2D:
	var layer := Node2D.new()
	layer.set_script(preload("res://scripts/sky_clouds.gd"))
	layer.set("area", area)
	layer.set("count", count)
	layer.set("speed_scale", speed / 7.0)
	layer.scale = Vector2(scale_value, scale_value)
	if scale_value != 1.0:
		layer.set("area", Rect2(area.position / scale_value, area.size / scale_value))
	return layer

func _add_button(parent: VBoxContainer, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(220, 30)
	button.add_theme_font_size_override("font_size", UiFont.px(15))
	UiStyle.style_button(button)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _start_new() -> void:
	_menu_frame.visible = false
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
