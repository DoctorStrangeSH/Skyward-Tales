extends HBoxContainer
class_name SettingsPanel

## All settings in two columns — used by the pause menu and the title menu
## (owner's list №36). Sound (№5): master, music, effects, interface,
## ambience (wind, waves, caves), nature (birds and crickets), silence when
## the game window loses focus.

var hints_toggle: CheckButton
var damage_toggle: CheckButton
var shake_toggle: CheckButton
var music_slider: HSlider
var sfx_slider: HSlider
var resolution_picker: OptionButton
var window_picker: OptionButton
var sliders: Dictionary = {}
var difficulty_picker: OptionButton

func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var game_column := _column("Игра")
	hints_toggle = _toggle(game_column, "Обучающие советы", "hints")
	damage_toggle = _toggle(game_column, "Числа урона над врагами", "damage_numbers")
	shake_toggle = _toggle(game_column, "Тряска экрана", "screen_shake")
	_toggle(game_column, "Цветокоррекция и виньетка", "color_grade")
	_toggle(game_column, "Камера ближе к герою", "close_camera")
	# Этап 24: difficulty — of this save in a game, of new adventures in the title menu.
	var game := get_tree().current_scene as SkywardGame if is_inside_tree() else null
	var current := game.difficulty if game != null else Difficulty.default_level()
	difficulty_picker = _picker(game_column, "Сложность", Difficulty.names(), current)
	var difficulty_hint := _label(str(Difficulty.info(current)["text"]), 7, UiStyle.MUTED)
	difficulty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	difficulty_hint.custom_minimum_size = Vector2(190, 0)
	game_column.add_child(difficulty_hint)
	difficulty_picker.item_selected.connect(func(index: int) -> void:
		difficulty_hint.text = str(Difficulty.info(index)["text"])
		var running := get_tree().current_scene as SkywardGame
		if running != null:
			running.set_difficulty(index)
		else:
			GameSettings.set_float("difficulty", float(index)))
	# The pause menu is built before a save loads: show the save's level.
	visibility_changed.connect(func() -> void:
		var running := get_tree().current_scene as SkywardGame if is_inside_tree() else null
		if running != null and is_visible_in_tree():
			difficulty_picker.select(running.difficulty)
			difficulty_hint.text = str(Difficulty.info(running.difficulty)["text"]))
	var resolutions: Array = []
	for index in GameSettings.RESOLUTIONS.size():
		resolutions.append(GameSettings.resolution_label(index))
	resolution_picker = _picker(game_column, "Разрешение", resolutions, GameSettings.resolution_index())
	window_picker = _picker(game_column, "Режим", GameSettings.WINDOW_MODES, GameSettings.window_mode_index())
	# Resolution sizes the window; full screen and borderless always use the
	# monitor's own resolution, so the picker is off there (owner's list №37).
	var display_hint := _label("", 8, Color(0.75, 0.78, 0.85))
	display_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	display_hint.custom_minimum_size = Vector2(180, 0)
	game_column.add_child(display_hint)
	var refresh_hint := func() -> void:
		var windowed := window_picker.selected == 0
		resolution_picker.disabled = not windowed
		if windowed:
			var size: Vector2i = DisplayServer.window_get_size() if DisplayServer.get_name() != "headless" else GameSettings.RESOLUTIONS[resolution_picker.selected]
			display_hint.text = "Окно: %d × %d" % [size.x, size.y]
		else:
			display_hint.text = "Полный экран — родное разрешение монитора."
	var apply := func(_index: int) -> void:
		GameSettings.set_display(resolution_picker.selected, window_picker.selected)
		refresh_hint.call_deferred()
	resolution_picker.item_selected.connect(apply)
	window_picker.item_selected.connect(apply)
	refresh_hint.call()
	var tips := Button.new()
	tips.text = "Показать советы заново"
	tips.add_theme_font_size_override("font_size", UiFont.px(9))
	tips.pressed.connect(func() -> void: GameSettings.reset_tips())
	game_column.add_child(tips)

	var sound := _column("Звук")
	_slider(sound, "Общая", "master_volume")
	music_slider = _slider(sound, "Музыка", "music_volume")
	sfx_slider = _slider(sound, "Бой и мир", "sfx_volume")
	_slider(sound, "Интерфейс", "ui_volume")
	_slider(sound, "Окружение", "ambience_volume")
	_slider(sound, "Птицы, сверчки", "nature_volume")
	_toggle(sound, "Тишина, когда окно свёрнуто", "mute_unfocused")
	var note := _label("«Окружение» — ветер, волны, пещеры, огонь. «Птицы, сверчки» — голоса природы днём и ночью.", 7, UiStyle.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(190, 0)
	sound.add_child(note)

func _column(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.custom_minimum_size = Vector2(196, 0)
	box.add_child(_label(title, 11, Color(1.0, 0.85, 0.5)))
	add_child(box)
	return box

func _toggle(parent: VBoxContainer, title: String, key: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.add_theme_font_size_override("font_size", UiFont.px(9))
	toggle.button_pressed = GameSettings.get_bool(key)
	toggle.toggled.connect(func(on: bool) -> void:
		GameSettings.set_bool(key, on)
		GameAudio.apply_volumes()
		for grade in get_tree().get_nodes_in_group("screen_grade"):
			grade.apply()
		for node in get_tree().get_nodes_in_group("camera_owner"):
			node.call("apply_camera"))
	parent.add_child(toggle)
	return toggle

func _slider(parent: VBoxContainer, title: String, key: String) -> HSlider:
	var row := HBoxContainer.new()
	var label := _label(title, 9, Color(0.92, 0.92, 0.88))
	label.custom_minimum_size = Vector2(74, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(90, 14)
	slider.value = GameSettings.get_float(key)
	row.add_child(slider)
	var value := _label("%d%%" % roundi(slider.value * 100.0), 8, UiStyle.MUTED)
	value.custom_minimum_size = Vector2(28, 0)
	row.add_child(value)
	slider.value_changed.connect(func(v: float) -> void:
		GameSettings.set_float(key, v)
		value.text = "%d%%" % roundi(v * 100.0)
		GameAudio.apply_volumes())
	parent.add_child(row)
	sliders[key] = slider
	return slider

func _picker(parent: VBoxContainer, title: String, options: Array, selected: int) -> OptionButton:
	var row := HBoxContainer.new()
	var label := _label(title, 9, Color(0.92, 0.92, 0.88))
	label.custom_minimum_size = Vector2(62, 0)
	row.add_child(label)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(120, 14)
	picker.add_theme_font_size_override("font_size", UiFont.px(9))
	for option in options:
		picker.add_item(str(option))
	picker.get_popup().add_theme_font_size_override("font_size", UiFont.px(10))
	picker.select(selected)
	row.add_child(picker)
	parent.add_child(row)
	return picker

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UiFont.px(size))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
