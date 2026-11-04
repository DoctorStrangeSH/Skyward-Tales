extends PanelContainer
class_name SkillTreePanel

## Skill tree window (T): four branch columns, tiers top to bottom.

signal learn_requested(skill_id: String)

var header: Label
var columns: HBoxContainer
var detail: Label
var buttons: Dictionary = {}

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
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := _label("ДЕРЕВО НАВЫКОВ  [T — закрыть]", 14, Color(1.0, 0.87, 0.57))
	box.add_child(title)
	header = _label("", 10, Color(0.9, 0.92, 1.0))
	box.add_child(header)
	columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 6)
	box.add_child(columns)
	detail = _label("Наведите на навык, чтобы прочитать описание.", 9, Color(0.82, 0.86, 0.92))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(580, 26)
	box.add_child(detail)
	visible = false

func populate(player: PlayerCharacter) -> void:
	for child in columns.get_children():
		columns.remove_child(child)
		child.queue_free()
	buttons.clear()
	header.text = "Очки навыков: %d     Печати Неба: %d" % [SkillTree.available_points(player), SkillTree.seals(player)]
	var defs := SkillTree.definitions()
	for branch in SkillTree.BRANCHES:
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(142, 0)
		column.add_theme_constant_override("separation", 3)
		columns.add_child(column)
		column.add_child(_label(str(branch["name"]), 12, branch["color"]))
		var last_tier := 0
		for skill_id in SkillTree.branch_skills(str(branch["id"])):
			var definition: Dictionary = defs[skill_id]
			var tier := int(definition.get("tier", 1))
			if last_tier != 0 and tier != last_tier:
				column.add_child(_label("  ↓", 9, Color(0.6, 0.6, 0.7)))
			last_tier = tier
			column.add_child(_skill_button(player, skill_id, definition, branch["color"]))

func _skill_button(player: PlayerCharacter, skill_id: String, definition: Dictionary, color: Color) -> Button:
	var rank := SkillTree.rank(player, skill_id)
	var max_rank := int(definition.get("max_rank", 1))
	var seal := bool(definition.get("seal", false))
	var button := Button.new()
	button.text = "%s%s  %d/%d" % ["✦ " if seal else "", str(definition.get("name", skill_id)), rank, max_rank]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", UiFont.px(9))
	button.custom_minimum_size = Vector2(142, 22)
	var reason := SkillTree.block_reason(player, skill_id)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(3)
	style.content_margin_left = 5
	if rank >= max_rank:
		style.bg_color = color.darkened(0.45)
		style.border_color = color
		style.set_border_width_all(1)
	elif reason.is_empty():
		style.bg_color = Color(0.2, 0.17, 0.1)
		style.border_color = Color(1.0, 0.85, 0.4)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.12, 0.11, 0.16)
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
