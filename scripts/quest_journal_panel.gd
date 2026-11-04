extends PanelContainer
class_name QuestJournalPanel

## Quest journal (J): active quests with progress, completed quests with the
## decision the player made.

var entry_list: VBoxContainer

func _ready() -> void:
	position = Vector2(110, 22)
	custom_minimum_size = Vector2(420, 310)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.06, 0.08, 0.98)
	style.border_color = Color(0.85, 0.7, 0.42, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.add_child(_label("ЖУРНАЛ ЗАДАНИЙ  [J — закрыть]", 15, Color(1.0, 0.87, 0.57)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 265)
	box.add_child(scroll)
	entry_list = VBoxContainer.new()
	entry_list.custom_minimum_size = Vector2(382, 0)
	entry_list.add_theme_constant_override("separation", 4)
	scroll.add_child(entry_list)
	visible = false

## Returns plain data so the journal can be tested without reading labels.
static func build_entries(quests: QuestManager) -> Dictionary:
	var active: Array[Dictionary] = []
	var completed: Array[Dictionary] = []
	for quest_id in quests.definitions:
		var definition: Dictionary = quests.definitions[quest_id]
		var state: Dictionary = quests.states.get(quest_id, {})
		if not bool(state.get("started", false)):
			continue
		var entry := {
			"id": str(quest_id),
			"title": str(definition.get("title", quest_id)),
			"description": str(definition.get("description", "")),
			"progress": int(state.get("progress", 0)),
			"target": int(definition.get("target", 1)),
			"decision": "",
			"main": bool(definition.get("main", false))
		}
		var choice_id := str(state.get("choice", ""))
		var choices: Variant = definition.get("choices", {})
		if not choice_id.is_empty() and choices is Dictionary and choices.has(choice_id):
			entry["decision"] = str(choices[choice_id].get("label", choice_id))
		if bool(state.get("completed", false)):
			completed.append(entry)
		else:
			active.append(entry)
	return {"active": active, "completed": completed}

func populate(quests: QuestManager) -> void:
	for child in entry_list.get_children():
		entry_list.remove_child(child)
		child.queue_free()
	var entries := build_entries(quests)
	var active: Array = entries["active"]
	var completed: Array = entries["completed"]
	var main_active := active.filter(func(e: Dictionary) -> bool: return e["main"])
	var side_active := active.filter(func(e: Dictionary) -> bool: return not e["main"])
	entry_list.add_child(_label("Главная история", 12, Color(1.0, 0.8, 0.45)))
	if main_active.is_empty():
		entry_list.add_child(_wrapped("Поговорите с жителями — история ждёт.", Color(0.7, 0.75, 0.8)))
	for entry in main_active:
		_add_active(entry, Color(1.0, 0.86, 0.5))
	entry_list.add_child(_label("Побочные задания", 12, Color(0.6, 0.85, 1.0)))
	if side_active.is_empty():
		entry_list.add_child(_wrapped("Нет активных побочных заданий.", Color(0.7, 0.75, 0.8)))
	for entry in side_active:
		_add_active(entry, Color(0.85, 0.92, 1.0))
	entry_list.add_child(_label("Выполненные", 12, Color(0.6, 0.95, 0.7)))
	if completed.is_empty():
		entry_list.add_child(_wrapped("Пока ничего.", Color(0.7, 0.75, 0.8)))
	for entry in completed:
		entry_list.add_child(_label(("✓ ★ " if entry["main"] else "✓ ") + str(entry["title"]), 11, Color(0.75, 0.9, 0.75)))
		if not str(entry["decision"]).is_empty():
			entry_list.add_child(_wrapped("Ваше решение: " + str(entry["decision"]), Color(0.85, 0.8, 0.95)))

func _add_active(entry: Dictionary, color: Color) -> void:
	var ready: bool = entry["progress"] >= entry["target"]
	entry_list.add_child(_label("%s %s  [%d/%d]%s" % ["★" if entry["main"] else "◆", entry["title"], entry["progress"], entry["target"], "  — можно сдать" if ready else ""], 11, color))
	entry_list.add_child(_wrapped(StoryText.format(entry["description"]), Color(0.81, 0.88, 0.9)))

func _wrapped(value: String, color: Color) -> Label:
	var label := _label(value, 9, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(370, 0)
	return label

func _label(value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", UiFont.px(font_size))
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
