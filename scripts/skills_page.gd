extends VBoxContainer
class_name SkillsPage

## "Навыки" tab of the hero window. On top — the four slots of the action bar
## (drop targets); below — active skills as cards you drag onto a slot
## (or onto the bar at the bottom of the screen), passives on the right.
## Double click a card — into the first free slot; drag a slot out — clear it.

signal assign_requested(slot_index: int, skill_id: String)
signal detail_changed(text: String)

## skill_id -> its card (actives) or bool (passives).
var skill_rows: Dictionary = {}
var bar_slots: Array = []
var _player: PlayerCharacter
var _skills: CombatSkills

func populate(player: PlayerCharacter, skills: CombatSkills) -> void:
	_player = player
	_skills = skills
	for child in get_children():
		remove_child(child)
		child.queue_free()
	skill_rows.clear()
	bar_slots.clear()
	_build_skills()

func _set_detail(text: String) -> void:
	detail_changed.emit(text)

func _build_skills() -> void:
	add_theme_constant_override("separation", 4)
	# The bar strip.
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", UiStyle.inset(Color(0.1, 0.07, 0.06, 0.85)))
	add_child(strip)
	var strip_row := HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 6)
	strip.add_child(strip_row)
	var caption := VBoxContainer.new()
	caption.add_theme_constant_override("separation", 0)
	caption.custom_minimum_size = Vector2(180, 0)
	caption.add_child(UiStyle.label("ПАНЕЛЬ НАВЫКОВ", 10, UiStyle.TITLE))
	caption.add_child(UiStyle.label("Перетащите навык в ячейку 1–4", 8, UiStyle.MUTED))
	strip_row.add_child(caption)
	for index in PlayerCharacter.SKILL_SLOT_COUNT:
		var slot := SkillBarSlot.new()
		slot.slot_index = index
		slot.skill_id = str(_player.skill_slots[index]) if index < _player.skill_slots.size() else ""
		slot.dropped.connect(func(target: int, skill_id: String) -> void: assign_requested.emit(target, skill_id))
		slot.cleared.connect(func(target: int) -> void: assign_requested.emit(target, ""))
		slot.mouse_entered.connect(func() -> void:
			var id := slot.skill_id
			_set_detail("Ячейка %d: %s" % [slot.slot_index + 1, (_name(id) + " — перетащите из ячейки, чтобы убрать или поменять местами") if not id.is_empty() else "пусто"]))
		strip_row.add_child(slot)
		bar_slots.append(slot)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_row.add_child(spacer)
	strip_row.add_child(UiStyle.label("Дерево талантов — T", 8, UiStyle.MUTED))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	left.add_theme_constant_override("separation", 2)
	row.add_child(left)
	left.add_child(UiStyle.section("Активные навыки"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 196)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(grid)
	var actives := CombatSkills.actives()
	for skill_id in actives:
		grid.add_child(_active_card(str(skill_id), actives[skill_id]))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 2)
	row.add_child(right)
	right.add_child(UiStyle.section("Пассивные — с уровнем"))
	var passives := CombatSkills.passives()
	for passive_id in passives:
		right.add_child(_passive_row(str(passive_id), passives[passive_id]))

func _name(skill_id: String) -> String:
	return str(CombatSkills.actives().get(skill_id, {}).get("name", skill_id))

func _active_card(skill_id: String, data: Dictionary) -> Control:
	var reason := _skills.lock_reason(skill_id) if _skills != null else ""
	var card := SkillCard.new()
	card.setup(skill_id, data, reason, _player.skill_slots.has(skill_id))
	card.double_clicked.connect(func(id: String) -> void:
		var target := _player.skill_slots.find("")
		if target < 0:
			target = 0
		assign_requested.emit(target, id))
	card.mouse_entered.connect(func() -> void:
		var extra := "  ·  перетащите на панель или дважды щёлкните" if reason.is_empty() else "  ·  " + reason
		_set_detail("%s — %s%s" % [str(data.get("name", skill_id)), str(data.get("description", "")), extra]))
	skill_rows[skill_id] = card
	return card

func _passive_row(passive_id: String, data: Dictionary) -> Control:
	var active := _player.has_passive(passive_id)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiStyle.inset(Color(0.2, 0.3, 0.2, 0.35) if active else Color(0.08, 0.06, 0.05, 0.6)))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	row.add_child(line)
	line.add_child(UiStyle.icon(CombatSkills.icon_path(passive_id), 18, not active))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	var state := "✓" if active else "ур. %d" % int(data.get("level", 1))
	text.add_child(UiStyle.label("%s  %s" % [str(data.get("name", passive_id)), state], 8, Color(0.7, 1.0, 0.7) if active else UiStyle.MUTED))
	var description := UiStyle.label(str(data.get("description", "")), 7, Color(0.75, 0.78, 0.85))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(170, 0)
	text.add_child(description)
	skill_rows[passive_id] = active
	return row
