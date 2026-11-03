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
var inventory_view: InventoryWindow
var inventory_list: VBoxContainer
var equipment_list: VBoxContainer
var inventory_filter: OptionButton
var inventory_sort: OptionButton
var inventory_player: PlayerCharacter
var comparison_panel: PanelContainer
var comparison_view: EquipmentComparisonPanel
var comparison_title: Label
var comparison_subtitle: Label
var comparison_grid: GridContainer
var comparison_description: Label
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
var pause_view: PauseMenuPanel
var defeat_panel: PanelContainer
var defeat_view: DefeatPanel
var defeat_hint_label: Label
var defeat_load_button: Button
var defeat_visible: bool = false
var talent_panel: PanelContainer
var talent_view: TalentChoicePanel
var talent_list: VBoxContainer
var talent_visible: bool = false
var bestiary_panel: PanelContainer
var bestiary_view: BestiaryPanel
var bestiary_list: VBoxContainer
var bestiary_visible: bool = false
var minimap: WorldMinimap
var world_map_panel: PanelContainer
var world_map_view: WorldMapPanel
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

	world_map_view = WorldMapPanel.new()
	root.add_child(world_map_view)
	world_map_panel = world_map_view
	world_map = world_map_view.map_view
	world_map_quest = world_map_view.quest_label

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

	# Keep public HUD references for existing save, input and regression code.
	inventory_view = InventoryWindow.new()
	root.add_child(inventory_view)
	inventory_panel = inventory_view
	inventory_list = inventory_view.item_list
	equipment_list = inventory_view.equipment_list
	inventory_filter = inventory_view.filter_button
	inventory_sort = inventory_view.sort_button
	inventory_view.filter_selected.connect(_on_inventory_filter_selected)
	inventory_view.sort_selected.connect(_on_inventory_sort_selected)
	inventory_view.use_requested.connect(func(id: String) -> void: inventory_use_requested.emit(id))
	inventory_view.compare_requested.connect(func(id: String) -> void: _show_equipment_comparison(inventory_player, id))
	inventory_view.unequip_requested.connect(func(slot: String) -> void: inventory_unequip_requested.emit(slot))

	comparison_view = EquipmentComparisonPanel.new()
	root.add_child(comparison_view)
	comparison_panel = comparison_view
	comparison_title = comparison_view.title_label
	comparison_subtitle = comparison_view.subtitle_label
	comparison_grid = comparison_view.stats_grid
	comparison_description = comparison_view.description_label

	pause_view = PauseMenuPanel.new()
	root.add_child(pause_view)
	pause_panel = pause_view
	pause_view.resume_requested.connect(func() -> void: _set_paused(false))
	pause_view.save_requested.connect(func() -> void: pause_save_requested.emit())
	pause_view.load_requested.connect(func() -> void: pause_load_requested.emit())
	pause_view.menu_requested.connect(func() -> void: pause_menu_requested.emit())

	defeat_view = DefeatPanel.new()
	root.add_child(defeat_view)
	defeat_panel = defeat_view
	defeat_hint_label = defeat_view.hint_label
	defeat_load_button = defeat_view.load_button
	defeat_view.restart_requested.connect(func() -> void: defeat_restart_requested.emit())
	defeat_view.load_requested.connect(func() -> void: defeat_load_requested.emit())
	defeat_view.menu_requested.connect(func() -> void: defeat_menu_requested.emit())

	talent_view = TalentChoicePanel.new()
	root.add_child(talent_view)
	talent_panel = talent_view
	talent_list = talent_view.choice_list
	talent_view.talent_chosen.connect(func(id: String) -> void: talent_selected.emit(id))

	bestiary_view = BestiaryPanel.new()
	root.add_child(bestiary_view)
	bestiary_panel = bestiary_view
	bestiary_list = bestiary_view.entry_list

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
	world_map_view.show_region(region, hero, landmarks, quest)
	world_map_visible = true
	get_tree().paused = true

func close_world_map() -> void:
	if not world_map_visible:
		return
	world_map_visible = false
	world_map_view.visible = false
	get_tree().paused = false

func toggle_inventory(player: PlayerCharacter) -> void:
	inventory_open = not inventory_open
	inventory_panel.visible = inventory_open
	if not inventory_open and comparison_panel != null:
		comparison_panel.visible = false
	if inventory_open:
		refresh_inventory(player)

func _format_comparison_value(value: float, unit: String) -> String:
	return InventoryComparisonFormatter.value_text(value, unit)

func _format_comparison_delta(value: float, unit: String) -> String:
	return InventoryComparisonFormatter.delta_text(value, unit)

func _comparison_label(text_value: String, color: Color, font_size: int = 9) -> Label:
	var label := _make_label(text_value, font_size, color)
	label.custom_minimum_size.x = 82
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _show_equipment_comparison(player: PlayerCharacter, item_id: String) -> void:
	if comparison_view == null:
		return
	comparison_view.show_item(player.get_equipment_comparison(item_id), item_id)


func _on_inventory_filter_selected(index: int) -> void:
	inventory_filter_index = clampi(index, 0, 2)
	if inventory_open and inventory_player != null:
		refresh_inventory(inventory_player)

func _on_inventory_sort_selected(index: int) -> void:
	inventory_sort_index = clampi(index, 0, 2)
	if inventory_open and inventory_player != null:
		refresh_inventory(inventory_player)

func _inventory_item_category(player: PlayerCharacter, item_id: String) -> String:
	return InventoryItemOrder.category(player, item_id, INVENTORY_CONSUMABLE_IDS)

func _inventory_item_name(player: PlayerCharacter, item_id: String) -> String:
	return InventoryItemOrder.display_name(player, item_id, INVENTORY_FALLBACK_NAMES)

func _inventory_rarity_rank(player: PlayerCharacter, item_id: String) -> int:
	return InventoryItemOrder.rarity_rank(player, item_id)

func _sort_inventory_items(player: PlayerCharacter, item_ids: Array[String]) -> void:
	InventoryItemOrder.sort_items(player, item_ids, inventory_sort_index, INVENTORY_FALLBACK_NAMES)

func refresh_inventory(player: PlayerCharacter) -> void:
	if inventory_list == null:
		return
	inventory_player = player
	if comparison_panel != null:
		comparison_panel.visible = false
	inventory_view.populate(player, inventory_filter_index, inventory_sort_index, INVENTORY_PREFERRED_ORDER, INVENTORY_FALLBACK_NAMES, INVENTORY_FALLBACK_DESCRIPTIONS, INVENTORY_RARITY_NAMES, INVENTORY_CONSUMABLE_IDS)

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
	if bestiary_visible:
		bestiary_view.populate(entries, discovered)

func show_talent_choices(choices: Array[Dictionary]) -> void:
	talent_view.populate(choices)
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
	defeat_view.show_defeat(can_load)

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
