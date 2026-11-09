extends PanelContainer
class_name ActionBar

## The bottom panel: mouse attacks (ЛКМ/ПКМ), skills 1–4 (drop targets),
## dodge, potions, the experience line and buttons for every window.

signal skill_dropped(slot_index: int, skill_id: String)
## Asks main to act as if this key was pressed (C, J, M, T, B, K).
signal menu_requested(keycode: int)

## One button for the one tabbed window (owner's list №28).
const MENU := [
	["hero", KEY_TAB, "Меню игры — Tab\nГерой I · Журнал J · Карта M · Таланты T · Бестиарий K · Занятия L · Ремесло B"],
]

var mouse_slots: Array = []
## The seven slots main fills: skills 1–4, dodge, Q, R.
var slots: Array = []
var xp_bar: ProgressBar
var xp_label: Label
var menu_buttons: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", UiStyle.small_panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	for index in 2:
		var slot := HotbarSlot.new()
		row.add_child(slot)
		mouse_slots.append(slot)
	_divider(row)
	for index in 7:
		if index == 4 or index == 5:
			_divider(row)
		var slot := HotbarSlot.new()
		if index < 4:
			slot.skill_index = index
			slot.skill_dropped.connect(func(i: int, id: String) -> void: skill_dropped.emit(i, id))
		row.add_child(slot)
		slots.append(slot)
	_divider(row)
	var menu := GridContainer.new()
	menu.columns = 1
	menu.add_theme_constant_override("h_separation", 1)
	menu.add_theme_constant_override("v_separation", 0)
	row.add_child(menu)
	for entry in MENU:
		var button := Button.new()
		button.custom_minimum_size = Vector2(34, 24)
		button.text = "Меню"
		button.add_theme_font_size_override("font_size", UiFont.px(7))
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = str(entry[2])
		button.icon = load("res://assets/ui/menu_%s.png" % entry[0]) if ResourceLoader.exists("res://assets/ui/menu_%s.png" % entry[0]) else null
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = false
		for state in ["normal", "hover", "pressed"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(0.3, 0.2, 0.12, 0.9) if state == "hover" else (Color(0.5, 0.33, 0.15) if state == "pressed" else Color(0, 0, 0, 0))
			box.set_corner_radius_all(2)
			box.set_content_margin_all(0)
			button.add_theme_stylebox_override(state, box)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var keycode: int = entry[1]
		button.pressed.connect(func() -> void: menu_requested.emit(keycode))
		menu.add_child(button)
		menu_buttons[str(entry[0])] = button
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 4)
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(xp_row)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 3)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_bar.max_value = 1.0
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.04, 0.05, 0.9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.62, 0.86, 0.38)
	xp_bar.add_theme_stylebox_override("background", back)
	xp_bar.add_theme_stylebox_override("fill", fill)
	xp_row.add_child(xp_bar)
	xp_label = UiStyle.label("", 6, Color(0.75, 0.9, 0.6))
	xp_row.add_child(xp_label)

func _divider(row: HBoxContainer) -> void:
	var line := ColorRect.new()
	line.color = Color(0.62, 0.45, 0.27, 0.45)
	line.custom_minimum_size = Vector2(1, 20)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 2)
	pad.add_theme_constant_override("margin_right", 2)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(line)
	row.add_child(pad)

func set_experience(level: int, current: int, needed: int) -> void:
	xp_bar.value = clampf(float(current) / maxf(1.0, float(needed)), 0.0, 1.0)
	xp_label.text = "ур. %d · %d/%d" % [level, current, needed]
	xp_bar.tooltip_text = "Опыт до следующего уровня"

## Keep the bar centred at the bottom whatever its width.
func _process(_delta: float) -> void:
	var view := get_viewport_rect().size
	position = Vector2(round((view.x - size.x) * 0.5), view.y - size.y - 3)
