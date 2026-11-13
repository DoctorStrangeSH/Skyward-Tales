extends PanelContainer
class_name SkillTreePanel

## Skill tree window (T): four branch columns, tiers top to bottom.

signal learn_requested(skill_id: String)
signal reset_requested
signal keystone_requested

## Codex of elemental combos (ElementalCombos), shown on its own tab.
var combos: Object
var reset_button: Button
var keystone_button: Button
var keystone_line: Label

var header: Label
var columns: HBoxContainer
var detail: Label
var buttons: Dictionary = {}
var group: String = "warrior"
var group_bar: HBoxContainer
var _player: PlayerCharacter

func _ready() -> void:
	position = Vector2(20, 18)
	custom_minimum_size = Vector2(600, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.97)
	style.border_color = Color(0.93, 0.78, 0.47, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", UiStyle.panel(false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := _label("ДЕРЕВО НАВЫКОВ  [T — закрыть]", 14, Color(1.0, 0.87, 0.57))
	box.add_child(title)
	header = _label("", 10, Color(0.9, 0.92, 1.0))
	box.add_child(header)
	group_bar = HBoxContainer.new()
	group_bar.add_theme_constant_override("separation", 4)
	box.add_child(group_bar)
	for entry in SkillTree.GROUPS:
		var tab := Button.new()
		tab.text = str(entry["name"])
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(90, 20)
		tab.add_theme_font_size_override("font_size", UiFont.px(10))
		tab.focus_mode = Control.FOCUS_NONE
		UiStyle.small_toggle(tab)
		var group_id := str(entry["id"])
		tab.pressed.connect(func() -> void: show_group(group_id))
		group_bar.add_child(tab)
	var combo_tab := Button.new()
	combo_tab.text = "Комбинации"
	combo_tab.toggle_mode = true
	combo_tab.custom_minimum_size = Vector2(100, 20)
	combo_tab.add_theme_font_size_override("font_size", UiFont.px(10))
	combo_tab.focus_mode = Control.FOCUS_NONE
	UiStyle.small_toggle(combo_tab)
	combo_tab.pressed.connect(func() -> void: show_group("combos"))
	group_bar.add_child(combo_tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_bar.add_child(spacer)
	reset_button = Button.new()
	reset_button.custom_minimum_size = Vector2(170, 20)
	reset_button.add_theme_font_size_override("font_size", UiFont.px(9))
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	reset_button.mouse_entered.connect(func() -> void: detail.text = "Сброс навыков и ключевых талантов: нужна Книга забвения (первая победа над легендой ночи, чемпионы 10-го и 20-го этажей Башни, 14 печатей испытаний у входа в Башню, Хранитель Бездны). Очки и Печати Неба вернутся.")
	group_bar.add_child(reset_button)
	# Key talents (levels 5/10/15): what was chosen and a button for a choice due.
	var keystone_row := HBoxContainer.new()
	keystone_row.add_theme_constant_override("separation", 8)
	box.add_child(keystone_row)
	keystone_line = _label("", 9, Color(1.0, 0.82, 0.5))
	keystone_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keystone_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keystone_row.add_child(keystone_line)
	keystone_button = Button.new()
	keystone_button.custom_minimum_size = Vector2(170, 20)
	keystone_button.add_theme_font_size_override("font_size", UiFont.px(9))
	keystone_button.focus_mode = Control.FOCUS_NONE
	keystone_button.pressed.connect(func() -> void: keystone_requested.emit())
	keystone_row.add_child(keystone_button)
	columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 6)
	box.add_child(columns)
	detail = _label("Наведите на навык, чтобы прочитать описание.", 9, Color(0.82, 0.86, 0.92))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(580, 26)
	box.add_child(detail)
	visible = false

func arena_stars(player: PlayerCharacter) -> int:
	var arena := player.get_parent()
	return int(arena.stars.available()) if arena != null and arena.get("stars") != null else 0

func show_group(group_id: String) -> void:
	group = group_id
	if _player != null:
		populate(_player)

func populate(player: PlayerCharacter) -> void:
	_player = player
	for index in SkillTree.GROUPS.size():
		(group_bar.get_child(index) as Button).button_pressed = str(SkillTree.GROUPS[index]["id"]) == group
	(group_bar.get_child(SkillTree.GROUPS.size()) as Button).button_pressed = group == "combos"
	reset_button.text = "Сброс: книга (%d) + %d зол." % [SkillTree.tomes(player), SkillTree.reset_cost(player)]
	reset_button.disabled = (SkillTree.spent_points(player) <= 0 and player.keystones.is_empty()) or SkillTree.tomes(player) <= 0
	for child in columns.get_children():
		columns.remove_child(child)
		child.queue_free()
	buttons.clear()
	header.text = "Очки навыков: %d     Печати Неба: %d" % [SkillTree.available_points(player), SkillTree.seals(player)]
	var chosen: Array[String] = []
	var tiers := Keystones.TIERS.keys()
	tiers.sort()
	var due := 0
	for tier in tiers:
		var id := str(player.keystones.get(str(tier), ""))
		if not id.is_empty():
			chosen.append("%s (ур. %d)" % [Keystones.name_of(id), int(tier)])
		elif player.level >= int(tier) and due == 0:
			due = int(tier)
	keystone_line.text = ("Ключевые таланты: " + ", ".join(chosen)) if not chosen.is_empty() else "Ключевые таланты: на 5, 10 и 15 уровне — один из трёх, меняет стиль боя."
	keystone_button.visible = due > 0
	var free_stars := int(arena_stars(player))
	var arena := player.get_parent()
	if arena != null and arena.get("mastery") != null:
		keystone_line.text += "\n" + str(arena.mastery.summary())
	if arena != null and arena.get("stars") != null:
		keystone_line.text += "\n" + str(arena.stars.summary())
	if arena != null and arena.get("joint") != null and not str(arena.joint.summary()).is_empty():
		keystone_line.text += "\n" + str(arena.joint.summary())
	keystone_button.text = "Выбрать ключевой талант (ур. %d)" % due
	if due == 0 and free_stars > 0:
		keystone_button.visible = true
		keystone_button.text = "★ Звёзды мастерства: %d" % free_stars
	if group == "combos":
		_populate_combos()
		return
	var defs := SkillTree.definitions()
	for branch in SkillTree.BRANCHES:
		if str(branch.get("group", "")) != group:
			continue
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(192, 0)
		column.add_theme_constant_override("separation", 2)
		columns.add_child(column)
		column.add_child(_label(str(branch["name"]), 11, branch["color"]))
		var last_tier := 0
		for skill_id in SkillTree.branch_skills(str(branch["id"])):
			var definition: Dictionary = defs[skill_id]
			var tier := int(definition.get("tier", 1))
			if last_tier != 0 and tier != last_tier:
				var arrow := _label("  ↓", 7, Color(0.6, 0.6, 0.7))
				arrow.custom_minimum_size = Vector2(0, 6)
				column.add_child(arrow)
			last_tier = tier
			column.add_child(_skill_button(player, skill_id, definition, branch["color"]))

func _populate_combos() -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(584, 0)
	column.add_theme_constant_override("separation", 3)
	columns.add_child(column)
	column.add_child(_label("Стихии и клинок усиливают друг друга. Наложите эффект — и ударьте другой стихией или мечом.", 9, Color(0.85, 0.88, 0.95)))
	var entries: Array = combos.codex() if combos != null else []
	for entry in entries:
		var seen := bool(entry["seen"])
		var row := _label("%s  %s — %s. %s" % ["✦" if seen else "?", str(entry["name"]) if seen else "???", str(entry["recipe"]), str(entry["text"]) if seen else "Откройте в бою."], 9, Color(1.0, 0.88, 0.6) if seen else Color(0.6, 0.62, 0.7))
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(584, 0)
		column.add_child(row)
	detail.text = "Открыто комбинаций: %d из %d. «Зачарованный клинок» (умение с 6 ур.) даёт мечу стихию выбранного заклинания." % [entries.filter(func(e: Dictionary) -> bool: return e["seen"]).size(), entries.size()]

func _skill_button(player: PlayerCharacter, skill_id: String, definition: Dictionary, color: Color) -> Button:
	var rank := SkillTree.rank(player, skill_id)
	var max_rank := int(definition.get("max_rank", 1))
	var seal := bool(definition.get("seal", false))
	var button := Button.new()
	button.text = "%s%s  %d/%d" % ["✦ " if seal else "", str(definition.get("name", skill_id)), rank, max_rank]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", UiFont.px(9))
	button.custom_minimum_size = Vector2(192, 16)
	var reason := SkillTree.block_reason(player, skill_id)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(3)
	style.content_margin_left = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	if rank >= max_rank:
		style.bg_color = color.darkened(0.45)
		style.border_color = color
		style.set_border_width_all(1)
	elif reason.is_empty():
		style.bg_color = Color(0.16, 0.22, 0.4)
		style.border_color = Color(1.0, 0.85, 0.4)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.08, 0.1, 0.18)
		style.border_color = Color(0.3, 0.34, 0.5)
		style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = hover.bg_color.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color(1, 1, 1) if rank > 0 or reason.is_empty() else Color(0.6, 0.62, 0.7))
	var description := str(definition.get("description", ""))
	var status := "Можно изучить — нажмите." if reason.is_empty() else reason
	button.mouse_entered.connect(func() -> void: detail.text = "%s — %s\n%s" % [str(definition.get("name", "")), description, status])
	button.pressed.connect(func() -> void: learn_requested.emit(skill_id))
	buttons[skill_id] = button
	return button

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UiFont.px(size))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
