extends HBoxContainer
class_name MenuTabs

## Owner's list №28: one game window with tabs instead of many buttons.
## The strip sits on top of whichever window is open (hero, journal, map,
## talents, bestiary, activities, crafting) — every one of them takes the
## same frame under it, so switching tabs feels like one book.

signal tab_requested(tab_id: String)

const TABS := [
	["hero", "Герой", "I"], ["journal", "Журнал", "J"], ["map", "Карта", "M"], ["talents", "Таланты", "T"],
	["bestiary", "Бестиарий", "K"], ["activities", "Занятия", "L"], ["calendar", "Календарь", "N"], ["craft", "Ремесло", "B"],
]
## The common frame of every tabbed window.
const FRAME := Rect2(12, 21, 616, 335)

var buttons: Dictionary = {}

func _ready() -> void:
	position = Vector2(14, 3)
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry in TABS:
		var button := Button.new()
		button.text = "%s  %s" % [entry[1], entry[2]]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(76, 17)
		button.add_theme_font_size_override("font_size", UiFont.px(9))
		button.tooltip_text = "%s — клавиша %s" % [entry[1], entry[2]]
		UiStyle.small_toggle(button)
		var tab_id: String = entry[0]
		button.pressed.connect(func() -> void:
			button.button_pressed = true
			tab_requested.emit(tab_id))
		add_child(button)
		buttons[tab_id] = button
	visible = false

func select(tab_id: String) -> void:
	visible = not tab_id.is_empty()
	for id in buttons:
		(buttons[id] as Button).set_pressed_no_signal(id == tab_id)

## Puts a window into the common frame.
static func fit(window: Control) -> void:
	window.position = FRAME.position
	window.custom_minimum_size = FRAME.size
	window.size = FRAME.size
	window.clip_contents = true
