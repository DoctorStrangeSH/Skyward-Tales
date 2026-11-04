extends VBoxContainer
class_name SkillsPage

## "Навыки" tab of the hero window: active skills with 1–4 buttons that put
## them on the bar, passives that switch on with levels.

signal assign_requested(slot_index: int, skill_id: String)
signal detail_changed(text: String)

var skill_rows: Dictionary = {}
var _player: PlayerCharacter
var _skills: CombatSkills

func populate(player: PlayerCharacter, skills: CombatSkills) -> void:
	_player = player
	_skills = skills
	for child in get_children():
		remove_child(child)
		child.queue_free()
	skill_rows.clear()
	_build_skills()

func _set_detail(text: String) -> void:
	detail_changed.emit(text)

func _build_skills() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	row.add_child(left)
	left.add_child(_label("Активные навыки — кнопки 1–4 ставят на панель", 10, UiStyle.TITLE))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	var actives := CombatSkills.actives()
	for skill_id in actives:
		list.add_child(_active_row(str(skill_id), actives[skill_id]))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(_label("Пассивные — открываются с уровнем", 10, UiStyle.TITLE))
	var passives := CombatSkills.passives()
	for passive_id in passives:
		right.add_child(_passive_row(str(passive_id), passives[passive_id]))

func _active_row(skill_id: String, data: Dictionary) -> Control:
	var reason := _skills.lock_reason(skill_id) if _skills != null else ""
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 4)
	row.add_child(_icon(CombatSkills.icon_path(skill_id), not reason.is_empty()))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var title := str(data.get("name", skill_id))
	if not reason.is_empty():
		title += "  · " + (("откроется на ур. " + reason.trim_prefix("Ур. ")) if reason.begins_with("Ур.") else reason.to_lower())
	elif not CombatSkills.is_spell(skill_id):
		title += "  · откат %s с" % str(data.get("cooldown", 0))
	text.add_child(_label(title, 9, UiStyle.TEXT if reason.is_empty() else UiStyle.MUTED))
	var description := _label(str(data.get("description", "")), 8, Color(0.75, 0.78, 0.85))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(200, 0)
	text.add_child(description)
	var buttons: Array = []
	for index in PlayerCharacter.SKILL_SLOT_COUNT:
		var button := Button.new()
		button.text = str(index + 1)
		button.toggle_mode = true
		button.button_pressed = index < _player.skill_slots.size() and str(_player.skill_slots[index]) == skill_id
		button.custom_minimum_size = Vector2(15, 15)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", UiFont.px(8))
		UiStyle.small_toggle(button)
		var slot_index: int = index
		button.pressed.connect(func() -> void: assign_requested.emit(slot_index, skill_id))
		row.add_child(button)
		buttons.append(button)
	row.mouse_entered.connect(func() -> void: _set_detail("%s — %s" % [str(data.get("name", skill_id)), str(data.get("description", ""))]))
	skill_rows[skill_id] = buttons
	return row

func _passive_row(passive_id: String, data: Dictionary) -> Control:
	var active := _player.has_passive(passive_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_icon(CombatSkills.icon_path(passive_id), not active))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var state := "✓ действует" if active else "ур. %d" % int(data.get("level", 1))
	text.add_child(_label("%s  · %s" % [str(data.get("name", passive_id)), state], 9, Color(0.7, 1.0, 0.7) if active else UiStyle.MUTED))
	var description := _label(str(data.get("description", "")), 8, Color(0.75, 0.78, 0.85))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(190, 0)
	text.add_child(description)
	skill_rows[passive_id] = active
	return row

func _icon(path: String, dim: bool) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(24, 24)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/" + path):
		rect.texture = WorldArt.texture(path)
	if dim:
		rect.modulate = Color(0.45, 0.45, 0.5)
	return rect

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UiFont.px(font_size))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
