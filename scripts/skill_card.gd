extends PanelContainer
class_name SkillCard

## An active skill in the hero window: icon, name, cooldown/mana. Drag it
## onto a bar slot; double click puts it into the first free slot.

signal double_clicked(skill_id: String)

var skill_id: String = ""
var locked: String = ""
var _icon_path: String = ""
var _hover := false
var _on_bar := false

func setup(id: String, data: Dictionary, lock_reason: String, on_bar: bool) -> void:
	skill_id = id
	locked = lock_reason
	_on_bar = on_bar
	_icon_path = CombatSkills.icon_path(id)
	custom_minimum_size = Vector2(176, 30)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG if locked.is_empty() else Control.CURSOR_ARROW
	_restyle()
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	line.add_child(UiStyle.icon(_icon_path, 22, not locked.is_empty()))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	text.add_child(UiStyle.label(str(data.get("name", id)), 9, UiStyle.TEXT if locked.is_empty() else UiStyle.MUTED))
	var info := ""
	if not locked.is_empty():
		info = ("откроется на ур. " + locked.trim_prefix("Ур. ")) if locked.begins_with("Ур.") else (locked if locked.begins_with("Учит") or locked.begins_with("Придёт") else locked.to_lower())
	elif CombatSkills.is_spell(id):
		info = "заклинание"
	else:
		info = "откат %s с" % str(data.get("cooldown", 0))
		if int(data.get("mana", 0)) > 0:
			info += " · %d MP" % int(data.get("mana", 0))
	if _on_bar:
		info += " · на панели"
	text.add_child(UiStyle.label(info, 7, Color(0.62, 0.9, 0.62) if _on_bar else Color(0.72, 0.74, 0.8)))
	mouse_entered.connect(func() -> void:
		_hover = true
		_restyle())
	mouse_exited.connect(func() -> void:
		_hover = false
		_restyle())

func _restyle() -> void:
	var box := UiStyle.inset(Color(0.24, 0.17, 0.11, 0.95) if _hover else Color(0.12, 0.085, 0.07, 0.9))
	if _on_bar:
		box.border_color = Color(0.55, 0.8, 0.45)
	elif _hover and locked.is_empty():
		box.border_color = UiStyle.GOLD
	add_theme_stylebox_override("panel", box)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.double_click and locked.is_empty():
		double_clicked.emit(skill_id)
		accept_event()

func _get_drag_data(_at: Vector2) -> Variant:
	if not locked.is_empty():
		return null
	set_drag_preview(UiStyle.drag_preview(_icon_path))
	return {"skill_id": skill_id, "from_slot": -1}
