extends PanelContainer
class_name PauseMenuPanel

## Pause menu with three pages: main actions, controls and settings.

signal resume_requested
signal save_requested
signal load_requested
signal menu_requested

const CONTROLS := [
	["WASD / стрелки", "движение"],
	["ЛКМ", "удар мечом, удерживать — вихрь"],
	["ПКМ", "выбранное заклинание"],
	["Колесо мыши", "сменить заклинание"],
	["1 – 4", "навыки на панели"],
	["Shift (держать)", "бег"],
	["Пробел", "рывок (неуязвимость)"],
	["F", "блок; вовремя — парирование и контратака"],
	["G", "совместный приём со спутником"],
	["E", "говорить, подбирать, открывать"],
	["Q / R", "зелье здоровья / маны"],
	["Tab", "меню игры (последняя вкладка)"],
	["I / C", "герой: снаряжение, навыки, отряд"],
	["J / M / T / K", "журнал / карта / таланты / бестиарий"],
	["L", "занятия мира"],
	["N", "календарь: праздники, ярмарки, дни рождения"],
	["B", "ремесло (Enter — создать)"],
	["F6 / F9", "быстрое сохранение / загрузка"],
	["Esc", "закрыть окно / пауза"],
]

var main_page: VBoxContainer
var controls_page: VBoxContainer
var settings_page: VBoxContainer
var hints_toggle: CheckButton
var damage_toggle: CheckButton
var shake_toggle: CheckButton
var music_slider: HSlider
var sfx_slider: HSlider
var resolution_picker: OptionButton
var window_picker: OptionButton
var settings: SettingsPanel

func _ready() -> void:
	position = Vector2(190, 40)
	custom_minimum_size = Vector2(260, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.11, 0.97)
	style.border_color = Color(0.93, 0.78, 0.47, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", UiStyle.panel(false))
	# Main page stays the first child (tests and HUD rely on it).
	main_page = _page("ПАУЗА")
	_button(main_page, "Продолжить", func() -> void: resume_requested.emit())
	_button(main_page, "Сохранить", func() -> void: save_requested.emit())
	_button(main_page, "Загрузить", func() -> void: load_requested.emit())
	_button(main_page, "Главное меню", func() -> void: menu_requested.emit())
	_button(main_page, "Управление", func() -> void: show_page(controls_page))
	_button(main_page, "Настройки", func() -> void: show_page(settings_page))

	controls_page = _page("УПРАВЛЕНИЕ")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 1)
	for row in CONTROLS:
		grid.add_child(_label(row[0], 9, Color(1.0, 0.85, 0.5)))
		grid.add_child(_label(row[1], 9, Color(0.92, 0.92, 0.88)))
	controls_page.add_child(grid)
	_button(controls_page, "Назад", func() -> void: show_page(main_page))

	settings_page = _page("НАСТРОЙКИ")
	settings = SettingsPanel.new()
	settings_page.add_child(settings)
	hints_toggle = settings.hints_toggle
	damage_toggle = settings.damage_toggle
	shake_toggle = settings.shake_toggle
	music_slider = settings.music_slider
	sfx_slider = settings.sfx_slider
	resolution_picker = settings.resolution_picker
	window_picker = settings.window_picker
	_button(settings_page, "Назад", func() -> void: show_page(main_page))
	show_page(main_page)
	visible = false

func show_page(page: VBoxContainer) -> void:
	for child in get_children():
		child.visible = child == page
	reset_size()
	# The settings page is wide: keep the panel centred.
	position = Vector2(roundf((640.0 - get_combined_minimum_size().x) / 2.0), 40.0 if page != settings_page else 24.0)

func _page(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.add_child(_label(title, 14, Color(0.96, 0.87, 0.65)))
	add_child(box)
	return box

func _toggle(parent: VBoxContainer, title: String, key: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.add_theme_font_size_override("font_size", UiFont.px(10))
	toggle.button_pressed = GameSettings.get_bool(key)
	toggle.toggled.connect(func(on: bool) -> void: GameSettings.set_bool(key, on))
	parent.add_child(toggle)
	return toggle

func _slider(parent: VBoxContainer, title: String, key: String) -> HSlider:
	var row := HBoxContainer.new()
	var label := _label(title, 10, Color(0.92, 0.92, 0.88))
	label.custom_minimum_size = Vector2(62, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(110, 14)
	slider.value = GameSettings.get_float(key)
	slider.value_changed.connect(func(value: float) -> void:
		GameSettings.set_float(key, value)
		GameAudio.apply_volumes())
	row.add_child(slider)
	parent.add_child(row)
	return slider

func _picker(parent: VBoxContainer, title: String, options: Array, selected: int) -> OptionButton:
	var row := HBoxContainer.new()
	var label := _label(title, 10, Color(0.92, 0.92, 0.88))
	label.custom_minimum_size = Vector2(62, 0)
	row.add_child(label)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(110, 14)
	picker.add_theme_font_size_override("font_size", UiFont.px(10))
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

func _button(parent: VBoxContainer, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.add_theme_font_size_override("font_size", UiFont.px(10))
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(callback)
	parent.add_child(button)
