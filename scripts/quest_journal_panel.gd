extends PanelContainer
class_name QuestJournalPanel

## Quest journal (J): active quests with progress, completed quests with the
## decision the player made.

var entry_list: VBoxContainer
var detail_box: VBoxContainer
var tab: String = "main"
var tab_buttons: Dictionary = {}
var selected_id: String = ""
var _quests: QuestManager
var _player: PlayerCharacter
const TABS := [["main", "Сюжет"], ["side", "Побочные"], ["done", "Выполненные"], ["fish", "Рыбалка"]]

func _ready() -> void:
	position = Vector2(30, 18)
	custom_minimum_size = Vector2(580, 320)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.panel(false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	box.add_child(top)
	var title := _label("ЖУРНАЛ  [J — закрыть]", 14, Color(1.0, 0.87, 0.57))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	for entry in TABS:
		var button := Button.new()
		button.text = entry[1]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(78, 20)
		button.add_theme_font_size_override("font_size", UiFont.px(10))
		UiStyle.small_toggle(button)
		var tab_id: String = entry[0]
		button.pressed.connect(func() -> void: show_tab(tab_id))
		top.add_child(button)
		tab_buttons[tab_id] = button
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(210, 272)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	entry_list = VBoxContainer.new()
	entry_list.custom_minimum_size = Vector2(200, 0)
	entry_list.add_theme_constant_override("separation", 3)
	scroll.add_child(entry_list)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(350, 272)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.08, 0.75)
	style.border_color = Color(0.5, 0.38, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8)
	detail_panel.add_theme_stylebox_override("panel", style)
	row.add_child(detail_panel)
	detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 5)
	detail_panel.add_child(detail_box)
	visible = false

func show_tab(tab_id: String) -> void:
	tab = tab_id
	selected_id = ""
	if _quests != null:
		populate(_quests, _player)

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

func populate(quests: QuestManager, player: PlayerCharacter = null) -> void:
	_quests = quests
	if player != null:
		_player = player
	for tab_id in tab_buttons:
		(tab_buttons[tab_id] as Button).button_pressed = tab_id == tab
	for child in entry_list.get_children() + detail_box.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	if tab == "fish":
		_populate_fishing()
		return
	var entries := build_entries(quests)
	var list: Array = entries["completed"] if tab == "done" else (entries["active"] as Array).filter(func(e: Dictionary) -> bool: return e["main"] == (tab == "main"))
	if list.is_empty():
		entry_list.add_child(_wrapped({"main": "Поговорите с жителями — история ждёт.", "side": "Нет побочных заданий. Ищите жителей с «!» над головой.", "done": "Пока ничего."}[tab], Color(0.7, 0.75, 0.8)))
		return
	if selected_id.is_empty() or not list.any(func(e: Dictionary) -> bool: return e["id"] == selected_id):
		selected_id = str(list[0]["id"])
	for entry in list:
		var button := Button.new()
		var ready: bool = entry["progress"] >= entry["target"] and tab != "done"
		button.text = "%s %s%s" % ["✓" if tab == "done" else ("★" if entry["main"] else "◆"), entry["title"], "  ✓" if ready else ""]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = entry["id"] == selected_id
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.custom_minimum_size = Vector2(198, 20)
		button.add_theme_font_size_override("font_size", UiFont.px(9))
		UiStyle.small_toggle(button)
		if ready:
			button.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		var quest_id := str(entry["id"])
		button.pressed.connect(func() -> void:
			selected_id = quest_id
			populate(_quests, _player))
		entry_list.add_child(button)
	for entry in list:
		if entry["id"] == selected_id:
			_show_detail(entry, quests)

func _show_detail(entry: Dictionary, quests: QuestManager) -> void:
	var color := Color(1.0, 0.86, 0.5) if entry["main"] else Color(0.7, 0.88, 1.0)
	detail_box.add_child(_label(str(entry["title"]), 13, color))
	var giver := giver_name(str(entry["id"]))
	if not giver.is_empty():
		detail_box.add_child(_label("Даёт: " + giver, 9, UiStyle.MUTED))
	detail_box.add_child(_wrapped(StoryText.format(str(entry["description"])), Color(0.86, 0.9, 0.92), 330.0))
	var done := tab == "done"
	if not done:
		var target := int(entry["target"])
		detail_box.add_child(_label("Прогресс: %d / %d%s" % [entry["progress"], target, "  — можно сдать!" if entry["progress"] >= target else ""], 10, Color(0.6, 1.0, 0.6) if entry["progress"] >= target else UiStyle.TEXT))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(330, 6)
		bar.show_percentage = false
		bar.max_value = target
		bar.value = int(entry["progress"])
		detail_box.add_child(bar)
	var reward: Dictionary = quests.definitions.get(entry["id"], {}).get("reward", {})
	var parts: Array[String] = []
	if int(reward.get("experience", 0)) > 0:
		parts.append("%d опыта" % int(reward["experience"]))
	if int(reward.get("gold", 0)) > 0:
		parts.append("%d золота" % int(reward["gold"]))
	var items: Variant = reward.get("items", {})
	if items is Dictionary and _player != null:
		for item_id in items:
			parts.append("%s ×%d" % [_player.get_item_name(str(item_id)), int(items[item_id])])
	if not parts.is_empty():
		detail_box.add_child(_label("Награда: " + ", ".join(parts), 10, Color(1.0, 0.85, 0.45)))
	if not str(entry["decision"]).is_empty():
		detail_box.add_child(_wrapped("Ваше решение: " + str(entry["decision"]), Color(0.85, 0.8, 0.95), 330.0))

static var _givers: Dictionary = {}

static func giver_name(quest_id: String) -> String:
	if _givers.is_empty():
		var file := FileAccess.open("res://data/quest_givers.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				for giver in parsed.values():
					for id in giver.get("quests", []):
						_givers[str(id)] = str(giver.get("speaker", ""))
	return str(_givers.get(quest_id, ""))

func _populate_fishing() -> void:
	var species: Dictionary = {}
	var file := FileAccess.open("res://data/fish.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			species = parsed.get("species", {})
	var log: Dictionary = _player.fish_log if _player != null else {}
	entry_list.add_child(_wrapped("Журнал рыбака: %d из %d видов." % [log.size(), species.size()], UiStyle.TITLE))
	entry_list.add_child(_wrapped("Рыбные места — у воды, отмечены кругами на воде. Нажмите E рядом.", Color(0.7, 0.75, 0.8)))
	detail_box.add_child(_label("Улов", 13, UiStyle.TITLE))
	for fish_id in species:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var caught := log.has(fish_id)
		if ResourceLoader.exists("res://assets/icons/%s.png" % fish_id):
			icon.texture = WorldArt.texture("icons/%s.png" % fish_id)
		if not caught:
			icon.modulate = Color(0.1, 0.1, 0.12)
		row.add_child(icon)
		var text := "???"
		if caught and _player != null:
			var entry: Dictionary = log[fish_id]
			text = "%s — поймано %d, рекорд %d см" % [_player.get_item_name(str(fish_id)), int(entry.get("count", 0)), int(entry.get("best", 0))]
		row.add_child(_label(text, 9, UiStyle.TEXT if caught else UiStyle.MUTED))
		detail_box.add_child(row)

func _wrapped(value: String, color: Color, width: float = 196.0) -> Label:
	var label := _label(value, 9, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label

func _label(value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", UiFont.px(font_size))
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
