extends CanvasLayer
class_name GameHud

var status_label: Label
var quest_label: Label
var message_label: Label
var prompt_label: Label
var dialogue_panel: PanelContainer
var dialogue_label: Label
var spell_label: Label
var spell_cooldown_bar: ProgressBar
var inventory_label: Label
var inventory_panel: PanelContainer
var inventory_list: VBoxContainer
var equipment_list: VBoxContainer
var inventory_open: bool = false
signal inventory_use_requested(item_id: String)
signal inventory_unequip_requested(slot: String)
var message_time: float = 0.0
var dialogue_visible: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var status_panel := PanelContainer.new()
	status_panel.position = Vector2(10, 10)
	status_panel.custom_minimum_size = Vector2(270, 64)
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.075, 0.09, 0.92)))
	root.add_child(status_panel)
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var status_box := VBoxContainer.new()
	status_panel.add_child(status_box)
	status_label = _make_label("УР. 1   ЗДОРОВЬЕ 100/100   МАНА 60/60", 11, Color(0.91, 0.94, 0.87))
	status_box.add_child(status_label)
	quest_label = _make_label("ЗАДАНИЕ: Поговорите со старейшиной", 10, Color(0.83, 0.88, 0.72))
	status_box.add_child(quest_label)

	# Compact battle information, without introducing mouse-blocking controls.
	var spell_panel := PanelContainer.new()
	spell_panel.position = Vector2(10, 83)
	spell_panel.custom_minimum_size = Vector2(230, 49)
	spell_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.075, 0.09, 0.88)))
	root.add_child(spell_panel)
	var spell_box := VBoxContainer.new()
	spell_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell_panel.add_child(spell_box)
	spell_label = _make_label("1 🔥 ОГНЕННЫЙ ШАР", 11, Color(0.98, 0.89, 0.70))
	spell_box.add_child(spell_label)
	spell_cooldown_bar = ProgressBar.new()
	spell_cooldown_bar.custom_minimum_size = Vector2(210, 8)
	spell_cooldown_bar.max_value = 1.0
	spell_cooldown_bar.value = 1.0
	spell_cooldown_bar.show_percentage = false
	spell_cooldown_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell_box.add_child(spell_cooldown_bar)

	inventory_label = _make_label("Q: Здоровье ×0   R: Мана ×0", 10, Color(0.92, 0.87, 0.77))
	inventory_label.position = Vector2(12, 144)
	inventory_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inventory_label)

	message_label = _make_label("", 12, Color(1.0, 0.91, 0.62))
	message_label.position = Vector2(180, 18)
	message_label.size = Vector2(450, 28)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(message_label)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	prompt_label = _make_label("", 10, Color(0.94, 0.94, 0.87))
	prompt_label.position = Vector2(12, 330)
	prompt_label.size = Vector2(500, 20)
	root.add_child(prompt_label)
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Interactive panel only intercepts clicks while opened.
	inventory_panel = PanelContainer.new()
	inventory_panel.position = Vector2(190, 48)
	inventory_panel.custom_minimum_size = Vector2(275, 220)
	inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.06, 0.09, 0.97)))
	root.add_child(inventory_panel)
	var contents := VBoxContainer.new()
	inventory_panel.add_child(contents)
	contents.add_child(_make_label("СУМКА  [I — закрыть]", 13, Color(1.0, 0.88, 0.56)))
	contents.add_child(_make_label("Экипировка (клик — снять)", 10, Color(0.91, 0.90, 0.75)))
	equipment_list = VBoxContainer.new()
	contents.add_child(equipment_list)
	inventory_list = VBoxContainer.new()
	contents.add_child(inventory_list)
	inventory_panel.visible = false

	dialogue_panel = PanelContainer.new()
	dialogue_panel.position = Vector2(140, 246)
	dialogue_panel.custom_minimum_size = Vector2(360, 100)
	dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.06, 0.08, 0.97)))
	root.add_child(dialogue_panel)
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_label = _make_label("", 11, Color(0.95, 0.93, 0.84))
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_panel.add_child(dialogue_label)
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.visible = false

func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var paused := not get_tree().paused
		get_tree().paused = paused
		show_message("ПАУЗА — Esc, чтобы продолжить" if paused else "Продолжаем приключение", 2.0)
		get_viewport().set_input_as_handled()

func toggle_inventory(player: PlayerCharacter) -> void:
	inventory_open = not inventory_open
	inventory_panel.visible = inventory_open
	if inventory_open:
		refresh_inventory(player)

func refresh_inventory(player: PlayerCharacter) -> void:
	if inventory_list == null:
		return
	for child in inventory_list.get_children():
		inventory_list.remove_child(child)
		child.queue_free()
	for child in equipment_list.get_children():
		equipment_list.remove_child(child)
		child.queue_free()
	var slots: Dictionary = {"weapon": "Оружие", "armor": "Броня", "amulet": "Амулет"}
	var gear_names: Dictionary = {"apprentice_staff": "Посох ученика", "leather_armor": "Кожаная броня", "mana_amulet": "Амулет маны"}
	for slot in ["weapon", "armor", "amulet"]:
		var equipped_item: String = str(player.equipment.get(slot, ""))
		var slot_button := Button.new()
		slot_button.text = "%s: %s" % [slots[slot], gear_names.get(equipped_item, "Пусто")]
		slot_button.disabled = equipped_item.is_empty()
		slot_button.pressed.connect(func() -> void: inventory_unequip_requested.emit(slot))
		equipment_list.add_child(slot_button)
	var order: Array[String] = ["health_potion", "mana_potion", "apprentice_staff", "leather_armor", "mana_amulet"]
	var names: Dictionary = {"health_potion": "Зелье здоровья", "mana_potion": "Зелье маны", "apprentice_staff": "Посох ученика", "leather_armor": "Кожаная броня", "mana_amulet": "Амулет маны"}
	var descriptions: Dictionary = {"health_potion": "+35 HP", "mana_potion": "+25 MP", "apprentice_staff": "+5 урона магией", "leather_armor": "-4 получаемого урона", "mana_amulet": "+20 макс. маны"}
	for item_id in order:
		var count: int = int(player.inventory.get(item_id, 0))
		var button := Button.new()
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		var equipped: bool = item_id in player.equipment.values()
		button.text = "%s ×%d — %s%s" % [names[item_id], count, descriptions[item_id], " [НАДЕТО]" if equipped else ""]
		button.tooltip_text = "Нажмите, чтобы использовать."
		button.disabled = count <= 0
		button.pressed.connect(func() -> void: inventory_use_requested.emit(item_id))
		inventory_list.add_child(button)

func update_status(player: PlayerCharacter, quests: QuestManager) -> void:
	status_label.text = "УР. %d   HP %d/%d   МАНА %d/%d   ЗОЛОТО %d" % [
		player.level, player.health, player.max_health, player.mana, player.max_mana, player.gold
	]
	quest_label.text = "ЗАДАНИЕ: " + quests.get_active_summary()
	inventory_label.text = "I: Сумка   Q: HP ×%d   R: MP ×%d" % [int(player.inventory.get("health_potion", 0)), int(player.inventory.get("mana_potion", 0))]
	if inventory_open:
		refresh_inventory(player)

func update_spell(spell_name: String, mana_cost: int, current_mana: int, remaining: float, total: float) -> void:
	if spell_label == null or spell_cooldown_bar == null:
		return
	var ready: bool = remaining <= 0.001
	var enough_mana: bool = current_mana >= mana_cost
	var state: String = "ГОТОВО" if ready else ("ОТКАТ %.1fс" % remaining)
	if not enough_mana:
		state = "НЕТ МАНЫ"
	spell_label.text = "%s  •  %d MP  •  %s" % [spell_name, mana_cost, state]
	spell_label.modulate = Color.WHITE if ready and enough_mana else Color(0.73, 0.8, 0.88)
	spell_cooldown_bar.value = 1.0 if total <= 0.0 else clampf(1.0 - remaining / total, 0.0, 1.0)

func show_message(message: String, duration: float = 3.0) -> void:
	message_label.text = message
	message_time = duration

func set_prompt(message: String) -> void:
	prompt_label.text = message

func show_dialogue(speaker: String, message: String) -> void:
	dialogue_label.text = speaker + "\n" + message + "\n\n[ E — закрыть ]"
	dialogue_panel.visible = true
	dialogue_visible = true

func close_dialogue() -> void:
	dialogue_panel.visible = false
	dialogue_visible = false

func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _panel_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.35, 0.47, 0.45, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
