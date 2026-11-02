extends CanvasLayer
class_name GameHud

const INVENTORY_PREFERRED_ORDER := ["health_potion", "mana_potion", "apprentice_staff", "leather_armor", "mana_amulet", "pyromancer_core", "frost_heart", "storm_eye", "ancient_relic", "starlight_essence"]
const INVENTORY_FALLBACK_NAMES := {"health_potion": "Зелье здоровья", "mana_potion": "Зелье маны", "ancient_relic": "Древний артефакт", "starlight_essence": "Звёздная эссенция"}
const INVENTORY_FALLBACK_DESCRIPTIONS := {"health_potion": "+35 HP", "mana_potion": "+25 MP", "ancient_relic": "Трофей победы над хранителем", "starlight_essence": "Постоянно +5 к максимальной мане"}
const INVENTORY_RARITY_NAMES := {"common": "ОБЫЧНЫЙ", "uncommon": "НЕОБЫЧНЫЙ", "rare": "РЕДКИЙ"}
const INVENTORY_CONSUMABLE_IDS := ["health_potion", "mana_potion", "starlight_essence"]

var status_label: Label
var quest_label: Label
var message_label: Label
var prompt_label: Label
var dialogue_panel: PanelContainer
var dialogue_label: Label
var spell_label: Label
var spell_cooldown_bar: ProgressBar
var dodge_label: Label
var dodge_cooldown_bar: ProgressBar
var inventory_label: Label
var inventory_panel: PanelContainer
var inventory_list: VBoxContainer
var equipment_list: VBoxContainer
var inventory_filter: OptionButton
var inventory_sort: OptionButton
var inventory_player: PlayerCharacter
var inventory_filter_index: int = 0
var inventory_sort_index: int = 0
var inventory_open: bool = false
signal inventory_use_requested(item_id: String)
signal inventory_unequip_requested(slot: String)
signal pause_save_requested
signal pause_load_requested
signal pause_menu_requested
signal defeat_restart_requested
signal defeat_load_requested
signal defeat_menu_requested
signal talent_selected(talent_id: String)
var pause_panel: PanelContainer
var defeat_panel: PanelContainer
var defeat_hint_label: Label
var defeat_load_button: Button
var defeat_visible: bool = false
var talent_panel: PanelContainer
var talent_list: VBoxContainer
var talent_visible: bool = false
var bestiary_panel: PanelContainer
var bestiary_list: VBoxContainer
var bestiary_visible: bool = false
var minimap: WorldMinimap
var world_map_panel: PanelContainer
var world_map: WorldMinimap
var world_map_quest: Label
var world_map_visible: bool = false
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

	minimap = preload("res://scripts/world_minimap.gd").new() as WorldMinimap
	minimap.position = Vector2(498, 8)
	root.add_child(minimap)

	world_map_panel = PanelContainer.new()
	world_map_panel.position = Vector2(94, 7)
	world_map_panel.custom_minimum_size = Vector2(452, 345)
	world_map_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	world_map_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.055, 0.075, 0.99)))
	root.add_child(world_map_panel)
	var map_box := VBoxContainer.new()
	map_box.add_theme_constant_override("separation", 7)
	world_map_panel.add_child(map_box)
	map_box.add_child(_make_label("КАРТА РЕГИОНА — [M закрыть]", 15, Color(0.99, 0.87, 0.58)))
	var map_canvas := Control.new()
	map_canvas.custom_minimum_size = Vector2(428, 268)
	map_box.add_child(map_canvas)
	world_map = preload("res://scripts/world_minimap.gd").new() as WorldMinimap
	world_map.position = Vector2(42, 3)
	world_map.scale = Vector2(2.4, 2.4)
	map_canvas.add_child(world_map)
	world_map_quest = _make_label("Задание: исследуйте мир.", 10, Color(0.83, 0.89, 0.91))
	world_map_quest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_box.add_child(world_map_quest)
	world_map_panel.visible = false

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

	var dodge_panel := PanelContainer.new()
	dodge_panel.position = Vector2(10, 137)
	dodge_panel.custom_minimum_size = Vector2(230, 38)
	dodge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dodge_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.075, 0.09, 0.88)))
	root.add_child(dodge_panel)
	var dodge_box := VBoxContainer.new()
	dodge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dodge_panel.add_child(dodge_box)
	dodge_label = _make_label("SHIFT — РЫВОК: ГОТОВО", 10, Color(0.65, 0.90, 1.0))
	dodge_box.add_child(dodge_label)
	dodge_cooldown_bar = ProgressBar.new()
	dodge_cooldown_bar.custom_minimum_size = Vector2(210, 7)
	dodge_cooldown_bar.max_value = 1.0
	dodge_cooldown_bar.value = 1.0
	dodge_cooldown_bar.show_percentage = false
	dodge_cooldown_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dodge_box.add_child(dodge_cooldown_bar)

	inventory_label = _make_label("Q: Здоровье ×0   R: Мана ×0", 10, Color(0.92, 0.87, 0.77))
	inventory_label.position = Vector2(12, 187)
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
	inventory_panel.position = Vector2(190, 30)
	inventory_panel.custom_minimum_size = Vector2(275, 300)
	inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.06, 0.09, 0.97)))
	root.add_child(inventory_panel)
	var contents := VBoxContainer.new()
	inventory_panel.add_child(contents)
	contents.add_child(_make_label("СУМКА  [I — закрыть]", 13, Color(1.0, 0.88, 0.56)))
	contents.add_child(_make_label("Экипировка (клик — снять)", 10, Color(0.91, 0.90, 0.75)))
	equipment_list = VBoxContainer.new()
	contents.add_child(equipment_list)
	var inventory_controls := HBoxContainer.new()
	inventory_controls.add_theme_constant_override("separation", 4)
	contents.add_child(inventory_controls)
	inventory_filter = OptionButton.new()
	inventory_filter.custom_minimum_size = Vector2(118, 26)
	inventory_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_filter.add_item("Все предметы", 0)
	inventory_filter.add_item("Экипировка", 1)
	inventory_filter.add_item("Расходники", 2)
	inventory_filter.tooltip_text = "Фильтр содержимого сумки"
	inventory_filter.item_selected.connect(_on_inventory_filter_selected)
	inventory_controls.add_child(inventory_filter)
	inventory_sort = OptionButton.new()
	inventory_sort.custom_minimum_size = Vector2(118, 26)
	inventory_sort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_sort.add_item("Порядок", 0)
	inventory_sort.add_item("По названию", 1)
	inventory_sort.add_item("По редкости", 2)
	inventory_sort.tooltip_text = "Порядок отображения предметов"
	inventory_sort.item_selected.connect(_on_inventory_sort_selected)
	inventory_controls.add_child(inventory_sort)
	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.custom_minimum_size = Vector2(250, 90)
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents.add_child(inventory_scroll)
	inventory_list = VBoxContainer.new()
	inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.add_child(inventory_list)
	inventory_panel.visible = false

	pause_panel = PanelContainer.new()
	pause_panel.position = Vector2(200, 65)
	pause_panel.custom_minimum_size = Vector2(240, 210)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.06, 0.09, 0.98)))
	root.add_child(pause_panel)
	var pause_box := VBoxContainer.new()
	pause_panel.add_child(pause_box)
	pause_box.add_child(_make_label("ПАУЗА", 16, Color(0.96, 0.87, 0.65)))
	_pause_button(pause_box, "Продолжить", func() -> void: _set_paused(false))
	_pause_button(pause_box, "Сохранить", func() -> void: pause_save_requested.emit())
	_pause_button(pause_box, "Загрузить", func() -> void: pause_load_requested.emit())
	_pause_button(pause_box, "Главное меню", func() -> void: pause_menu_requested.emit())
	pause_panel.visible = false

	defeat_panel = PanelContainer.new()
	defeat_panel.position = Vector2(150, 66)
	defeat_panel.custom_minimum_size = Vector2(340, 228)
	defeat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	defeat_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.035, 0.045, 0.99)))
	root.add_child(defeat_panel)
	var defeat_box := VBoxContainer.new()
	defeat_box.add_theme_constant_override("separation", 9)
	defeat_panel.add_child(defeat_box)
	var defeat_title := _make_label("ПУТЕШЕСТВИЕ ПРЕРВАНО", 17, Color(1.0, 0.56, 0.48))
	defeat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeat_box.add_child(defeat_title)
	var defeat_description := _make_label("Герой пал в бою. Но это ещё не конец истории.", 11, Color(0.91, 0.87, 0.82))
	defeat_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeat_box.add_child(defeat_description)
	defeat_hint_label = _make_label("Выберите, как продолжить.", 10, Color(0.76, 0.82, 0.87))
	defeat_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	defeat_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeat_box.add_child(defeat_hint_label)
	_pause_button(defeat_box, "Начать заново", func() -> void: defeat_restart_requested.emit())
	defeat_load_button = Button.new()
	defeat_load_button.text = "Загрузить сохранение"
	defeat_load_button.pressed.connect(func() -> void: defeat_load_requested.emit())
	defeat_box.add_child(defeat_load_button)
	_pause_button(defeat_box, "Главное меню", func() -> void: defeat_menu_requested.emit())
	defeat_panel.visible = false

	talent_panel = PanelContainer.new()
	talent_panel.position = Vector2(128, 35)
	talent_panel.custom_minimum_size = Vector2(384, 290)
	talent_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	talent_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.085, 0.99)))
	root.add_child(talent_panel)
	var talent_box := VBoxContainer.new()
	talent_box.add_theme_constant_override("separation", 8)
	talent_panel.add_child(talent_box)
	var talent_title := _make_label("НОВЫЙ УРОВЕНЬ — ВЫБЕРИТЕ ТАЛАНТ", 14, Color(1.0, 0.87, 0.58))
	talent_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	talent_box.add_child(talent_title)
	var talent_subtitle := _make_label("Выбор изменит ваш стиль игры. Каждый талант можно усилить до III ранга.", 10, Color(0.77, 0.83, 0.88))
	talent_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talent_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	talent_box.add_child(talent_subtitle)
	talent_list = VBoxContainer.new()
	talent_list.add_theme_constant_override("separation", 7)
	talent_box.add_child(talent_list)
	talent_panel.visible = false

	bestiary_panel = PanelContainer.new()
	bestiary_panel.position = Vector2(110, 22)
	bestiary_panel.custom_minimum_size = Vector2(420, 310)
	bestiary_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	bestiary_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.06, 0.08, 0.98)))
	root.add_child(bestiary_panel)
	var bestiary_box := VBoxContainer.new()
	bestiary_box.add_theme_constant_override("separation", 8)
	bestiary_panel.add_child(bestiary_box)
	bestiary_box.add_child(_make_label("БЕСТИАРИЙ  [K — закрыть]", 15, Color(1.0, 0.87, 0.57)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 265)
	bestiary_box.add_child(scroll)
	bestiary_list = VBoxContainer.new()
	bestiary_list.custom_minimum_size = Vector2(382, 0)
	scroll.add_child(bestiary_list)
	bestiary_panel.visible = false

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
	if world_map_visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
			close_world_map()
			get_viewport().set_input_as_handled()
		return
	if defeat_visible or talent_visible or bestiary_visible:
		return
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()

func _pause_button(parent: VBoxContainer, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(callback)
	parent.add_child(button)

func _set_paused(paused: bool) -> void:
	if (defeat_visible or talent_visible) and not paused:
		return
	get_tree().paused = paused
	pause_panel.visible = paused

func open_world_map(region: String, hero: Vector2, landmarks: Dictionary, quest: String) -> void:
	if world_map_visible or defeat_visible or talent_visible:
		return
	world_map.update_map(region, hero, landmarks)
	world_map_quest.text = "ЗАДАНИЕ: " + quest
	world_map_visible = true
	world_map_panel.visible = true
	get_tree().paused = true

func close_world_map() -> void:
	if not world_map_visible:
		return
	world_map_visible = false
	world_map_panel.visible = false
	get_tree().paused = false

func toggle_inventory(player: PlayerCharacter) -> void:
	inventory_open = not inventory_open
	inventory_panel.visible = inventory_open
	if inventory_open:
		refresh_inventory(player)

func _on_inventory_filter_selected(index: int) -> void:
	inventory_filter_index = clampi(index, 0, 2)
	if inventory_open and inventory_player != null:
		refresh_inventory(inventory_player)

func _on_inventory_sort_selected(index: int) -> void:
	inventory_sort_index = clampi(index, 0, 2)
	if inventory_open and inventory_player != null:
		refresh_inventory(inventory_player)

func _inventory_item_category(player: PlayerCharacter, item_id: String) -> String:
	if not str(player.get_item_definition(item_id).get("slot", "")).is_empty():
		return "equipment"
	if INVENTORY_CONSUMABLE_IDS.has(item_id):
		return "consumable"
	return "other"

func _inventory_item_name(player: PlayerCharacter, item_id: String) -> String:
	return str(INVENTORY_FALLBACK_NAMES.get(item_id, player.get_item_name(item_id)))

func _inventory_rarity_rank(player: PlayerCharacter, item_id: String) -> int:
	match str(player.get_item_definition(item_id).get("rarity", "")):
		"rare":
			return 3
		"uncommon":
			return 2
		"common":
			return 1
		_:
			return 0

func _sort_inventory_items(player: PlayerCharacter, item_ids: Array[String]) -> void:
	if inventory_sort_index == 1:
		item_ids.sort_custom(func(a: String, b: String) -> bool:
			return _inventory_item_name(player, a).to_lower() < _inventory_item_name(player, b).to_lower()
		)
	elif inventory_sort_index == 2:
		item_ids.sort_custom(func(a: String, b: String) -> bool:
			var rank_a: int = _inventory_rarity_rank(player, a)
			var rank_b: int = _inventory_rarity_rank(player, b)
			if rank_a != rank_b:
				return rank_a > rank_b
			return _inventory_item_name(player, a).to_lower() < _inventory_item_name(player, b).to_lower()
		)

func refresh_inventory(player: PlayerCharacter) -> void:
	if inventory_list == null:
		return
	inventory_player = player
	for child in inventory_list.get_children():
		inventory_list.remove_child(child)
		child.queue_free()
	for child in equipment_list.get_children():
		equipment_list.remove_child(child)
		child.queue_free()
	var slots: Dictionary = {"weapon": "Оружие", "armor": "Броня", "amulet": "Амулет", "relic": "Реликвия"}
	for slot in ["weapon", "armor", "amulet", "relic"]:
		var equipped_item: String = str(player.equipment.get(slot, ""))
		var slot_button := Button.new()
		slot_button.text = "%s: %s" % [slots[slot], player.get_item_name(equipped_item) if not equipped_item.is_empty() else "Пусто"]
		slot_button.disabled = equipped_item.is_empty()
		slot_button.pressed.connect(func() -> void: inventory_unequip_requested.emit(slot))
		equipment_list.add_child(slot_button)
	var available_item_ids: Array[String] = []
	for item_id in INVENTORY_PREFERRED_ORDER:
		if int(player.inventory.get(item_id, 0)) > 0:
			available_item_ids.append(item_id)
	var additional_item_ids: Array[String] = []
	for key in player.inventory.keys():
		var item_id: String = str(key)
		if not INVENTORY_PREFERRED_ORDER.has(item_id) and int(player.inventory.get(item_id, 0)) > 0:
			additional_item_ids.append(item_id)
	additional_item_ids.sort()
	available_item_ids.append_array(additional_item_ids)
	var item_ids: Array[String] = []
	for item_id in available_item_ids:
		var category: String = _inventory_item_category(player, item_id)
		if inventory_filter_index == 1 and category != "equipment":
			continue
		if inventory_filter_index == 2 and category != "consumable":
			continue
		item_ids.append(item_id)
	_sort_inventory_items(player, item_ids)
	if item_ids.is_empty():
		var empty_message: String = "Сумка пуста." if available_item_ids.is_empty() else "Нет предметов в этой категории."
		inventory_list.add_child(_make_label(empty_message, 10, Color(0.78, 0.82, 0.85)))
	for item_id in item_ids:
		var count: int = int(player.inventory.get(item_id, 0))
		var button := Button.new()
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var equipped: bool = item_id in player.equipment.values()
		var definition: Dictionary = player.get_item_definition(item_id)
		var item_name: String = _inventory_item_name(player, item_id)
		var description: String = str(INVENTORY_FALLBACK_DESCRIPTIONS.get(item_id, player.get_item_description(item_id)))
		var rarity: String = str(definition.get("rarity", ""))
		var rarity_label: String = " • " + str(INVENTORY_RARITY_NAMES.get(rarity, rarity)).to_lower() if not rarity.is_empty() else ""
		var can_equip: bool = not str(definition.get("slot", "")).is_empty()
		var can_consume: bool = INVENTORY_CONSUMABLE_IDS.has(item_id)
		var action_hint: String = "Клик: экипировать" if can_equip else ("Клик: использовать" if can_consume else "Этот предмет нельзя использовать.")
		button.text = "%s ×%d — %s%s%s" % [item_name, count, description, rarity_label, " [НАДЕТО]" if equipped else ""]
		button.tooltip_text = (description + "\n" if not description.is_empty() else "") + action_hint
		button.disabled = count <= 0 or not (can_equip or can_consume)
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

func update_dodge(remaining: float, cooldown: float, dodging: bool) -> void:
	if dodge_label == null or dodge_cooldown_bar == null:
		return
	dodge_label.text = "SHIFT — УКЛОНЕНИЕ" if dodging else ("SHIFT — ГОТОВО" if remaining <= 0.001 else "SHIFT — ОТКАТ %.1fс" % remaining)
	dodge_label.modulate = Color(0.65, 0.95, 1.0) if remaining <= 0.001 else Color(0.67, 0.73, 0.8)
	dodge_cooldown_bar.value = 1.0 if cooldown <= 0.0 else clampf(1.0 - remaining / cooldown, 0.0, 1.0)

func toggle_bestiary(entries: Dictionary, discovered: Dictionary) -> void:
	bestiary_visible = not bestiary_visible
	bestiary_panel.visible = bestiary_visible
	if not bestiary_visible:
		return
	for child in bestiary_list.get_children():
		bestiary_list.remove_child(child)
		child.queue_free()
	for id in entries:
		var entry: Dictionary = entries[id]
		var seen: bool = bool(discovered.get(id, false))
		var name_label := _make_label(str(entry.get("name", id)) if seen else "??? — Не обнаружен", 12, Color(1.0, 0.88, 0.65))
		bestiary_list.add_child(name_label)
		if seen:
			var detail := _make_label("Место: %s\nАтака: %s\nСлабость: %s\nЗащита: %s" % [str(entry.get("habitat", "")), str(entry.get("attack", "")), str(entry.get("weakness", "")), str(entry.get("resistance", ""))], 9, Color(0.81, 0.88, 0.9))
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.custom_minimum_size = Vector2(365, 70)
			bestiary_list.add_child(detail)

func show_talent_choices(choices: Array[Dictionary]) -> void:
	for child in talent_list.get_children():
		talent_list.remove_child(child)
		child.queue_free()
	for choice in choices:
		var talent_id: String = str(choice.get("id", ""))
		var rank: int = int(choice.get("rank", 0))
		var entry := VBoxContainer.new()
		var button := Button.new()
		button.text = "%s   РАНГ %d → %d" % [str(choice.get("name", talent_id)), rank, rank + 1]
		button.custom_minimum_size = Vector2(340, 34)
		button.tooltip_text = str(choice.get("description", ""))
		button.pressed.connect(func() -> void: talent_selected.emit(talent_id))
		entry.add_child(button)
		var description := _make_label(str(choice.get("description", "")), 9, Color(0.78, 0.84, 0.89))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_child(description)
		talent_list.add_child(entry)
	talent_visible = true
	talent_panel.visible = true

func hide_talent_choices() -> void:
	talent_visible = false
	if talent_panel != null:
		talent_panel.visible = false

func show_defeat(can_load: bool) -> void:
	defeat_visible = true
	if world_map_visible:
		close_world_map()
	if bestiary_visible:
		bestiary_panel.visible = false
		bestiary_visible = false
	hide_talent_choices()
	pause_panel.visible = false
	inventory_panel.visible = false
	inventory_open = false
	dialogue_panel.visible = false
	dialogue_visible = false
	defeat_load_button.disabled = not can_load
	defeat_hint_label.text = "Сохранение найдено. Можно вернуться к последней записи." if can_load else "Сохранений пока нет. Начните новое приключение."
	defeat_panel.visible = true

func set_defeat_message(message: String) -> void:
	if defeat_hint_label != null:
		defeat_hint_label.text = message

func hide_defeat() -> void:
	defeat_visible = false
	if defeat_panel != null:
		defeat_panel.visible = false
	if get_tree().paused:
		get_tree().paused = false

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
