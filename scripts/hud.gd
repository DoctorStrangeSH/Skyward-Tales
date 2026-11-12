extends CanvasLayer
class_name GameHud

const INVENTORY_PREFERRED_ORDER := ["health_potion", "mana_potion", "apprentice_staff", "leather_armor", "mana_amulet", "pyromancer_core", "frost_heart", "storm_eye", "ancient_relic", "starlight_essence"]
const INVENTORY_FALLBACK_NAMES := {"health_potion": "Зелье здоровья", "mana_potion": "Зелье маны", "ancient_relic": "Древний артефакт", "starlight_essence": "Звёздная эссенция"}
const INVENTORY_FALLBACK_DESCRIPTIONS := {"health_potion": "+35 HP", "mana_potion": "+25 MP", "ancient_relic": "Трофей победы над хранителем", "starlight_essence": "Постоянно +5 к максимальной мане"}
const INVENTORY_RARITY_NAMES := {"common": "ОБЫЧНЫЙ", "uncommon": "НЕОБЫЧНЫЙ", "rare": "РЕДКИЙ", "epic": "ЭПИЧЕСКИЙ", "legendary": "ЛЕГЕНДАРНЫЙ"}
const INVENTORY_CONSUMABLE_IDS := ["health_potion", "mana_potion", "starlight_essence"]

var status_label: Label
var toasts: ToastStack
var vitals: HudVitals
var quest_label: Label
var side_quest_label: Label
var quest_tracker: QuestTracker
var buff_label: Label
var buff_bar: BuffBar
var message_label: Label
var prompt_label: Label
var dialogue_panel: PanelContainer
var dialogue_label: Label
var dialogue_speaker_label: Label
var dialogue_hint_label: Label
var dialogue_portrait: TextureRect
var title_card: Label
var save_indicator: Control
var spell_label: Label
var spell_cooldown_bar: ProgressBar
var dodge_label: Label
var dodge_cooldown_bar: ProgressBar
var inventory_label: Label
var inventory_panel: PanelContainer
var inventory_view: InventoryWindow
var inventory_list: Container
var equipment_list: Control
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
signal inventory_equip_to_requested(item_id: String, slot: String)
signal inventory_unequip_requested(slot: String)
signal pause_save_requested
signal pause_load_requested
signal pause_menu_requested
signal defeat_restart_requested
signal defeat_load_requested
signal defeat_menu_requested
signal talent_selected(talent_id: String)
signal dialogue_choice_selected(choice_id: String)
var dialogue_choices_container: VBoxContainer
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
var journal_view: QuestJournalPanel
var skills_view: SkillTreePanel
var skills_visible: bool = false
## The hero window is the bag window now (I and C open it).
var hero_visible: bool:
	get: return inventory_open
var fishing_view: FishingPanel
var hotbar: ActionBar
var action_bar: ActionBar
var crafting_view: CraftingWindow
var crafting_visible: bool:
	get:
		return crafting_view != null and crafting_view.visible
signal menu_key_requested(keycode: int)
var hotbar_slots: Array = []
signal hero_unequip_requested(slot: String)
signal handcraft_requested
signal hero_assign_requested(slot_index: int, skill_id: String)
signal skill_learn_requested(skill_id: String)
signal skills_reset_requested
var journal_visible: bool = false
## «Занятия» (owner's list №33) and the tab strip over every window (№28).
var activities_view: ActivitiesPanel
var activities_visible: bool = false
var menu_tabs: MenuTabs
signal menu_tab_requested(tab_id: String)
## Main tells which tab is open ("" — none).
var tab_provider: Callable = func() -> String: return ""
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
	# Above the world's colour pass (ScreenGrade, layer 1).
	layer = 2
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Compact layout: vitals top-left, quest tracker under it, minimap
	# top-right, spells bottom-left. Text uses outlines instead of panels so
	# the world stays visible.
	vitals = HudVitals.new()
	vitals.position = Vector2(6, 6)
	root.add_child(vitals)
	status_label = _make_label("", 9, Color(0.91, 0.94, 0.87))
	status_label.visible = false
	root.add_child(status_label)
	quest_label = _make_label("", 9, Color(1.0, 0.93, 0.72))
	quest_label.position = Vector2(8, 68)
	quest_label.size = Vector2(300, 14)
	root.add_child(quest_label)
	side_quest_label = _make_label("", 9, Color(0.78, 0.9, 1.0))
	side_quest_label.position = Vector2(8, 81)
	side_quest_label.size = Vector2(300, 40)
	root.add_child(side_quest_label)
	# The tracker panel replaces the two plain lines (kept for old callers).
	quest_label.visible = false
	side_quest_label.visible = false
	quest_tracker = QuestTracker.new()
	root.add_child(quest_tracker)
	buff_label = _make_label("", 9, Color(0.72, 1.0, 0.72))
	buff_label.position = Vector2(486, 126)
	buff_label.size = Vector2(132, 30)
	root.add_child(buff_label)
	buff_label.visible = false
	buff_bar = BuffBar.new()
	buff_bar.position = Vector2(446, 129)
	buff_bar.size = Vector2(180, 40)
	root.add_child(buff_bar)

	minimap = preload("res://scripts/world_minimap.gd").new() as WorldMinimap
	minimap.position = Vector2(484, 6)
	root.add_child(minimap)

	world_map_view = WorldMapPanel.new()
	root.add_child(world_map_view)
	world_map_panel = world_map_view
	world_map = world_map_view.map_view
	world_map_quest = world_map_view.quest_label

	var spell_panel := PanelContainer.new()
	spell_panel.position = Vector2(6, 318)
	spell_panel.custom_minimum_size = Vector2(150, 0)
	spell_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell_panel.add_theme_stylebox_override("panel", UiStyle.small_panel())
	root.add_child(spell_panel)
	# The action bar shows the attacks now; the panel stays for its labels.
	spell_panel.visible = false
	var spell_box := VBoxContainer.new()
	spell_box.add_theme_constant_override("separation", 1)
	spell_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell_panel.add_child(spell_box)
	spell_label = _make_label("Огненный шар", 9, Color(0.98, 0.89, 0.70))
	spell_box.add_child(spell_label)
	spell_cooldown_bar = _make_bar(Color(1.0, 0.62, 0.3), 136, 3)
	spell_box.add_child(spell_cooldown_bar)

	var dodge_panel := PanelContainer.new()
	dodge_panel.position = Vector2(162, 318)
	dodge_panel.custom_minimum_size = Vector2(92, 0)
	dodge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dodge_panel.add_theme_stylebox_override("panel", UiStyle.small_panel())
	root.add_child(dodge_panel)
	var dodge_box := VBoxContainer.new()
	dodge_box.add_theme_constant_override("separation", 1)
	dodge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dodge_panel.add_child(dodge_box)
	dodge_label = _make_label("SHIFT — ГОТОВО", 9, Color(0.65, 0.90, 1.0))
	dodge_box.add_child(dodge_label)
	dodge_cooldown_bar = _make_bar(Color(0.55, 0.9, 1.0), 78, 3)
	dodge_box.add_child(dodge_cooldown_bar)

	inventory_label = _make_label("", 9, Color(0.95, 0.9, 0.8))
	inventory_label.position = Vector2(260, 330)
	root.add_child(inventory_label)
	# The skill bar replaces the old dodge box and potion line.
	dodge_panel.visible = false
	inventory_label.visible = false
	action_bar = ActionBar.new()
	root.add_child(action_bar)
	crafting_view = CraftingWindow.new()
	root.add_child(crafting_view)
	hotbar = action_bar
	hotbar_slots = action_bar.slots
	action_bar.skill_dropped.connect(func(index: int, skill_id: String) -> void: hero_assign_requested.emit(index, skill_id))
	action_bar.menu_requested.connect(func(keycode: int) -> void: menu_key_requested.emit(keycode))

	# message_label keeps the latest message (used by code and tests); the
	# player sees the ToastStack instead.
	message_label = _make_label("", 10, Color(1.0, 0.91, 0.62))
	message_label.visible = false
	root.add_child(message_label)
	toasts = ToastStack.new()
	toasts.position = Vector2(160, 6)
	toasts.size = Vector2(330, 60)
	toasts.custom_minimum_size = Vector2(330, 0)
	root.add_child(toasts)

	prompt_label = _make_label("", 9, Color(0.97, 0.97, 0.9))
	prompt_label.position = Vector2(110, 284)
	prompt_label.size = Vector2(420, 28)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.visible = false  # the floating InteractPrompt replaces it
	root.add_child(prompt_label)

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
	inventory_view.equip_to_requested.connect(func(id: String, slot: String) -> void: inventory_equip_to_requested.emit(id, slot))
	inventory_view.reordered.connect(func() -> void:
		inventory_sort_index = 0
		inventory_sort.select(0)
		refresh_inventory(inventory_player))
	inventory_view.mark_changed.connect(func(id: String, mark: String) -> void:
		refresh_inventory(inventory_player)
		show_message({"fav": "★ Избранное: «%s» не продаётся.", "junk": "✕ Хлам: «%s» уйдёт торговцу одной кнопкой.", "": "Метка с «%s» снята."}[mark] % inventory_player.get_item_name(id), 2.5))
	inventory_view.compare_requested.connect(func(id: String) -> void: _show_equipment_comparison(inventory_player, id))
	inventory_view.unequip_requested.connect(func(slot: String) -> void: inventory_unequip_requested.emit(slot))
	inventory_view.craft_requested.connect(func() -> void: handcraft_requested.emit())
	inventory_view.assign_requested.connect(func(index: int, skill_id: String) -> void: hero_assign_requested.emit(index, skill_id))
	inventory_view.compare_cleared.connect(func() -> void:
		if comparison_panel != null:
			comparison_panel.visible = false)

	comparison_view = EquipmentComparisonPanel.new()
	root.add_child(comparison_view)
	comparison_panel = comparison_view
	comparison_title = comparison_view.title_label
	comparison_subtitle = comparison_view.subtitle_label
	comparison_grid = comparison_view.stats_grid
	comparison_description = comparison_view.description_label

	fishing_view = FishingPanel.new()
	root.add_child(fishing_view)


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
	journal_view = QuestJournalPanel.new()
	root.add_child(journal_view)
	skills_view = SkillTreePanel.new()
	root.add_child(skills_view)
	skills_view.learn_requested.connect(func(id: String) -> void: skill_learn_requested.emit(id))
	skills_view.reset_requested.connect(func() -> void: skills_reset_requested.emit())
	activities_view = ActivitiesPanel.new()
	root.add_child(activities_view)
	# Owner's list №28: one window with tabs — every book takes the same
	# frame under the tab strip.
	for window in [inventory_view, journal_view, world_map_view, skills_view, bestiary_view, activities_view, crafting_view]:
		MenuTabs.fit(window)
	menu_tabs = MenuTabs.new()
	root.add_child(menu_tabs)
	menu_tabs.tab_requested.connect(func(id: String) -> void: menu_tab_requested.emit(id))

	# Dialogue box: portrait on the left, name tag, text and choices.
	dialogue_panel = PanelContainer.new()
	dialogue_panel.position = Vector2(12, 262)
	dialogue_panel.custom_minimum_size = Vector2(616, 90)
	var dialogue_style := _panel_style(Color(0.08, 0.07, 0.13, 0.96))
	dialogue_style.set_border_width_all(2)
	dialogue_style.set_corner_radius_all(5)
	dialogue_style.set_content_margin_all(8)
	dialogue_panel.add_theme_stylebox_override("panel", UiStyle.panel(false, 10))
	root.add_child(dialogue_panel)
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dialogue_row := HBoxContainer.new()
	dialogue_row.add_theme_constant_override("separation", 10)
	dialogue_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.add_child(dialogue_row)
	var portrait_frame := PanelContainer.new()
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.2, 0.32, 0.36)
	portrait_style.border_color = Color(0.93, 0.78, 0.47)
	portrait_style.set_border_width_all(1)
	portrait_style.set_corner_radius_all(3)
	portrait_frame.add_theme_stylebox_override("panel", UiStyle.panel(true, 4))
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_row.add_child(portrait_frame)
	dialogue_portrait = TextureRect.new()
	dialogue_portrait.custom_minimum_size = Vector2(64, 64)
	dialogue_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialogue_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dialogue_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialogue_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(dialogue_portrait)
	var dialogue_column := VBoxContainer.new()
	dialogue_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_column.add_theme_constant_override("separation", 3)
	dialogue_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_row.add_child(dialogue_column)
	dialogue_speaker_label = _make_label("", 11, Color(1.0, 0.85, 0.5))
	dialogue_column.add_child(dialogue_speaker_label)
	dialogue_label = _make_label("", 10, Color(0.97, 0.95, 0.88))
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.custom_minimum_size = Vector2(510, 0)
	dialogue_column.add_child(dialogue_label)
	dialogue_choices_container = VBoxContainer.new()
	dialogue_choices_container.add_theme_constant_override("separation", 2)
	dialogue_column.add_child(dialogue_choices_container)
	dialogue_hint_label = _make_label("E — продолжить", 8, Color(0.7, 0.72, 0.8))
	dialogue_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialogue_column.add_child(dialogue_hint_label)
	dialogue_panel.visible = false

func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message_label.text = ""
	# Toasts hide under big windows (the windows show their own status).
	if toasts != null:
		toasts.visible = not (inventory_open or crafting_visible or journal_visible or skills_visible or bestiary_visible or world_map_visible or activities_visible)
	if menu_tabs != null:
		var open_tab: String = str(tab_provider.call())
		if open_tab.is_empty() != not menu_tabs.visible or (not open_tab.is_empty() and not (menu_tabs.buttons[open_tab] as Button).button_pressed):
			menu_tabs.select(open_tab)
		if menu_tabs.visible:
			menu_tabs.move_to_front()
	# Big title cards hide while a window (journal, bag...) covers the screen.
	if title_card != null and is_instance_valid(title_card):
		title_card.visible = not (journal_view.visible or inventory_open or world_map_visible or overlay_visible())

func _unhandled_input(event: InputEvent) -> void:
	if world_map_visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_M, KEY_ESCAPE]:
			close_world_map()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_I, KEY_TAB, KEY_C, KEY_J, KEY_T, KEY_K, KEY_L, KEY_B]:
			# Another tab's key while the (pausing) map is open.
			close_world_map()
			menu_key_requested.emit(event.keycode)
			get_viewport().set_input_as_handled()
		return
	if defeat_visible or talent_visible:
		return
	if event.is_action_pressed("pause"):
		# Esc: first close whatever window is open; with none — the menu.
		if get_tree().paused and pause_panel.visible:
			_set_paused(false)
		elif not close_top_window():
			_set_paused(true)
		get_viewport().set_input_as_handled()

signal dialogue_dismissed
## Story scenes can't be skipped with Esc; main sets this.
var can_dismiss_dialogue: Callable = func() -> bool: return true

## Closes the top-most window (Esc). Returns false when nothing was open.
func close_top_window() -> bool:
	if dialogue_visible:
		if not bool(can_dismiss_dialogue.call()):
			return true
		close_dialogue()
		dialogue_dismissed.emit()
		return true
	if crafting_visible:
		crafting_view.closed.emit()
		return true
	if inventory_open:
		inventory_open = false
		inventory_panel.visible = false
		if comparison_panel != null:
			comparison_panel.visible = false
		return true
	if journal_visible:
		journal_visible = false
		journal_view.visible = false
		return true
	if skills_visible:
		skills_visible = false
		skills_view.visible = false
		return true
	if bestiary_visible:
		bestiary_visible = false
		bestiary_panel.visible = false
		return true
	if activities_visible:
		activities_visible = false
		activities_view.visible = false
		return true
	return false

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
	if paused:
		pause_view.show_page(pause_view.main_page)

func open_world_map(region: String, hero: Vector2, landmarks: Dictionary, quest: String) -> void:
	if world_map_visible or defeat_visible or talent_visible:
		return
	world_map_view.show_region(region, hero, landmarks, quest)
	world_map_view.move_to_front()
	world_map_visible = true
	get_tree().paused = true

func close_world_map() -> void:
	if not world_map_visible:
		return
	world_map_visible = false
	world_map_view.visible = false
	get_tree().paused = false

## Opens the hero window on «Отряд».
func open_party_page(player: PlayerCharacter) -> void:
	if not inventory_open:
		toggle_inventory(player)
	inventory_view.show_tab("party")

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
	inventory_filter_index = clampi(index, 0, 3)
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
	if vitals != null:
		vitals.set_values(player)
	if action_bar != null:
		action_bar.set_experience(player.level, player.experience, player.experience_to_next)
	quest_label.text = "◆ " + quests.get_active_summary()
	quest_tracker.refresh(quests)
	var effects: Array[String] = []
	for type in player.buffs:
		var buff: Dictionary = player.buffs[type]
		effects.append("%s %d с" % [str(buff.get("label", type)), int(ceil(float(buff.get("time", 0.0))))])
	buff_label.text = ("✦ " + " · ".join(effects)) if not effects.is_empty() else ""
	buff_bar.set_buffs(player.buffs)
	var side := quests.get_side_summaries()
	side_quest_label.text = "\n".join(side.slice(0, 3).map(func(line: String) -> String: return "◇ " + line))
	inventory_label.text = "Q  Зелье HP ×%d     R  Зелье MP ×%d" % [int(player.inventory.get("health_potion", 0)), int(player.inventory.get("mana_potion", 0))]
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
	spell_label.text = "%s · %d MP · %s" % [spell_name, mana_cost, state]
	spell_label.modulate = Color.WHITE if ready and enough_mana else Color(0.73, 0.8, 0.88)
	spell_cooldown_bar.value = 1.0 if total <= 0.0 else clampf(1.0 - remaining / total, 0.0, 1.0)

func update_dodge(remaining: float, cooldown: float, dodging: bool) -> void:
	if dodge_label == null or dodge_cooldown_bar == null:
		return
	dodge_label.text = "ПРОБЕЛ — РЫВОК" if dodging else ("ПРОБЕЛ — ГОТОВО" if remaining <= 0.001 else "ПРОБЕЛ — ОТКАТ %.1fс" % remaining)
	dodge_label.modulate = Color(0.65, 0.95, 1.0) if remaining <= 0.001 else Color(0.67, 0.73, 0.8)
	dodge_cooldown_bar.value = 1.0 if cooldown <= 0.0 else clampf(1.0 - remaining / cooldown, 0.0, 1.0)

func toggle_bestiary(entries: Dictionary, discovered: Dictionary) -> void:
	bestiary_visible = not bestiary_visible
	bestiary_panel.visible = bestiary_visible
	if bestiary_visible:
		bestiary_view.populate(entries, discovered)

## True while a full-screen book (bestiary or quest journal) is open.
func overlay_visible() -> bool:
	return bestiary_visible or journal_visible or skills_visible or activities_visible

func toggle_activities(rows: Array[Dictionary]) -> void:
	activities_visible = not activities_visible
	activities_view.visible = activities_visible
	if activities_visible:
		activities_view.populate(rows)

func show_fishing(fishing: Fishing) -> void:
	fishing_view.show_for(fishing)

func update_fishing(_fishing: Fishing) -> void:
	fishing_view.refresh()

func hide_fishing() -> void:
	fishing_view.visible = false

## The two mouse slots: {"icon", "key", "name", "cooldown", "locked", "note"}.
func set_mouse_slots(left: Dictionary, right: Dictionary) -> void:
	if action_bar == null:
		return
	(action_bar.mouse_slots[0] as HotbarSlot).apply(left)
	(action_bar.mouse_slots[1] as HotbarSlot).apply(right)

func update_hotbar(entries: Array) -> void:
	for index in mini(entries.size(), hotbar_slots.size()):
		(hotbar_slots[index] as HotbarSlot).apply(entries[index])

func toggle_hero_panel(player: PlayerCharacter, skills: CombatSkills) -> void:
	inventory_view.set_skills(skills)
	toggle_inventory(player)

func refresh_hero_panel(player: PlayerCharacter, _skills: CombatSkills) -> void:
	if inventory_open:
		refresh_inventory(player)

func toggle_skill_tree(player: PlayerCharacter) -> void:
	skills_visible = not skills_visible
	skills_view.visible = skills_visible
	if skills_visible:
		skills_view.populate(player)

func refresh_skill_tree(player: PlayerCharacter) -> void:
	if skills_visible:
		skills_view.populate(player)

func toggle_journal(quests: QuestManager, player: PlayerCharacter = null) -> void:
	journal_visible = not journal_visible
	journal_view.visible = journal_visible
	if journal_visible:
		journal_view.populate(quests, player)

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
	if journal_visible:
		journal_view.visible = false
		journal_visible = false
	if skills_visible:
		skills_view.visible = false
		skills_visible = false
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
	message = StoryText.format(message)
	message_label.text = message
	message_time = duration
	if toasts != null:
		toasts.push(message, duration)

## A one-time tutorial tip; silent if already seen or hints are off.
func show_tip(tip_id: String, message: String, duration: float = 5.0) -> void:
	if toasts != null and GameSettings.consume_tip(tip_id):
		toasts.push(message, duration, "tip")

func set_prompt(message: String) -> void:
	prompt_label.text = message

## Maps a speaker's name to an NPC sprite sheet for the portrait.
const PORTRAITS := {"Элиан": "elder", "Мира": "cartographer", "Бран": "merchant", "Торен": "hunter", "Борин": "blacksmith", "Илара": "grove_warden", "Дорн": "miner", "Ориэн": "archivist", "Вейл": "vail", "Ведана": "herbalist", "Лира": "alchemist", "Ярош": "settler_woodcutter", "Марта": "settler_cook", "Ульф": "settler_fisher", "Морен": "keeper", "Гунхильд": "smith_master", "Игнат": "ash_hermit", "Аэлла": "aella"}

func _set_speaker(speaker: String) -> void:
	dialogue_speaker_label.text = "" if speaker == StoryScene.NARRATOR else speaker
	var portrait: Texture2D = null
	for key in PORTRAITS:
		if speaker.contains(key):
			var face: Texture2D = WorldArt.texture("sprites/portraits/%s.png" % PORTRAITS[key]) if ResourceLoader.exists("res://assets/sprites/portraits/%s.png" % PORTRAITS[key]) else null
			var sheet: Texture2D = WorldArt.texture("sprites/npcs/%s.png" % PORTRAITS[key]) if face == null and ResourceLoader.exists("res://assets/sprites/npcs/%s.png" % PORTRAITS[key]) else null
			if face != null:
				portrait = face
			elif sheet != null:
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(4, 0, 24, 24)  # head and shoulders of the idle frame
				portrait = atlas
			break
	if portrait == null and not speaker.is_empty():
		# Newer villagers: the portrait of their own look (regions.json).
		var face_id := RegionCatalog.portrait_id(speaker)
		if not face_id.is_empty():
			portrait = WorldArt.texture("sprites/portraits/%s.png" % face_id)
	dialogue_portrait.texture = portrait
	dialogue_portrait.get_parent().visible = portrait != null

func _set_portrait(rel_path: String) -> void:
	var portrait: Texture2D = null
	if not rel_path.is_empty():
		var sheet := WorldArt.texture(rel_path)
		if sheet != null and rel_path.begins_with("sprites/portraits/"):
			portrait = sheet
		elif sheet != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(4, 0, 24, 24)
			portrait = atlas
	dialogue_portrait.texture = portrait
	dialogue_portrait.get_parent().visible = portrait != null

## One line of a story scene (StoryScene); E continues.
func show_scene_line(speaker: String, message: String, portrait_path: String) -> void:
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_dialogue_choices()
	dialogue_speaker_label.text = speaker
	_set_portrait(portrait_path)
	dialogue_label.text = message
	# The narrator reads like the author's text in a book: no name, softer
	# and cooler than the characters' lines.
	var narrator := speaker == StoryScene.NARRATOR
	dialogue_label.self_modulate = Color(0.8, 0.88, 1.05) if narrator else Color.WHITE
	if narrator:
		dialogue_speaker_label.text = ""
	dialogue_hint_label.text = "E — дальше"
	dialogue_panel.visible = true
	dialogue_visible = true
	_layout_dialogue()

## Big chapter title in the middle of the screen that fades in and out.
## Hit streak counter under the minimap: "×12 В УДАРЕ!".
var streak_label: Label

func set_streak(count: int, left: float) -> void:
	if streak_label == null:
		streak_label = Label.new()
		streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		streak_label.position = Vector2(500, 128)
		streak_label.size = Vector2(132, 30)
		streak_label.add_theme_font_size_override("font_size", UiFont.px(16))
		streak_label.add_theme_constant_override("outline_size", 4)
		streak_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03))
		dialogue_panel.get_parent().add_child(streak_label)
	streak_label.visible = count >= 3
	if count < 3:
		return
	var hot := count >= 20
	streak_label.text = "×%d%s" % [count, "  В УДАРЕ!" if count >= 10 else ""]
	streak_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.25) if hot else (Color(1.0, 0.8, 0.3) if count >= 10 else Color(0.95, 0.95, 0.9)))
	streak_label.modulate.a = clampf(0.35 + left, 0.0, 1.0)

## A small "saved" badge in the corner: a spinning gem, then a check mark.
func show_save_indicator() -> void:
	if save_indicator == null:
		save_indicator = SaveIndicator.new()
		dialogue_panel.get_parent().add_child(save_indicator)
	(save_indicator as SaveIndicator).play()

func show_title_card(text: String, duration: float = 3.0) -> void:
	# A newer card replaces the old one instead of piling on top of it.
	if title_card != null and is_instance_valid(title_card):
		title_card.queue_free()
	var card := Label.new()
	card.text = text
	card.add_theme_font_size_override("font_size", UiFont.px(20))
	card.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	card.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	card.add_theme_constant_override("outline_size", 5)
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.position = Vector2(0, 110)
	card.size = Vector2(640, 40)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	dialogue_panel.get_parent().add_child(card)
	var tween := card.create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.6)
	tween.tween_interval(maxf(0.2, duration - 1.4))
	tween.tween_property(card, "modulate:a", 0.0, 0.8)
	tween.tween_callback(card.queue_free)
	title_card = card

## Full-screen colour that fades away (screen flashes, fade from black).
## Story scenes on the engine (stage 20): black bars top and bottom.
var letterbox_bars: Array[ColorRect] = []
var fade_rect: ColorRect
const LETTERBOX := 30.0

func set_letterbox(on: bool, time: float = 0.45) -> void:
	if letterbox_bars.is_empty():
		for top in [true, false]:
			var bar := ColorRect.new()
			bar.color = Color(0.02, 0.02, 0.04)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.size = Vector2(640, LETTERBOX)
			bar.position = Vector2(0, -LETTERBOX if top else 360)
			bar.set_meta("top", top)
			dialogue_panel.get_parent().add_child(bar)
			dialogue_panel.get_parent().move_child(bar, 0)
			letterbox_bars.append(bar)
	# The game's own panels step aside while a scene plays.
	for panel in [vitals, minimap, quest_tracker, action_bar]:
		if panel != null and is_instance_valid(panel):
			(panel as CanvasItem).create_tween().tween_property(panel, "modulate:a", 0.0 if on else 1.0, maxf(0.01, time))
	for bar in letterbox_bars:
		var top := bool(bar.get_meta("top"))
		var target := (0.0 if on else -LETTERBOX) if top else (360.0 - LETTERBOX if on else 360.0)
		if time <= 0.0:
			bar.position.y = target
		else:
			bar.create_tween().tween_property(bar, "position:y", target, time).set_trans(Tween.TRANS_SINE)

func letterbox_on() -> bool:
	return not letterbox_bars.is_empty() and letterbox_bars[0].position.y > -LETTERBOX * 0.5

## Fades the world to a colour (alpha 1) or back (alpha 0); the dialogue box
## stays on top.
func fade_world(alpha: float, time: float = 0.6, color: Color = Color(0.01, 0.01, 0.03)) -> void:
	if fade_rect == null or not is_instance_valid(fade_rect):
		fade_rect = ColorRect.new()
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_rect.size = Vector2(640, 360)
		fade_rect.modulate.a = 0.0
		dialogue_panel.get_parent().add_child(fade_rect)
		dialogue_panel.get_parent().move_child(fade_rect, 0)
	fade_rect.color = color
	if time <= 0.0:
		fade_rect.modulate.a = alpha
	else:
		fade_rect.create_tween().tween_property(fade_rect, "modulate:a", alpha, time)

func flash_screen(color: Color, duration: float = 0.4) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.size = Vector2(640, 360)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.get_parent().add_child(rect)
	dialogue_panel.get_parent().move_child(rect, 0)
	var tween := rect.create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration)
	tween.tween_callback(rect.queue_free)

func _layout_dialogue() -> void:
	# Grow upwards from the bottom edge so long choice lists stay on screen.
	dialogue_panel.reset_size()
	dialogue_panel.position.y = 352.0 - dialogue_panel.get_combined_minimum_size().y

func show_dialogue(speaker: String, message: String) -> void:
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_dialogue_choices()
	_set_speaker(speaker)
	dialogue_label.self_modulate = Color.WHITE
	dialogue_label.text = message
	dialogue_hint_label.text = "E — продолжить"
	dialogue_panel.visible = true
	dialogue_visible = true
	_layout_dialogue()

func show_dialogue_choices(speaker: String, message: String, choices: Array[Dictionary]) -> void:
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_clear_dialogue_choices()
	_set_speaker(speaker)
	dialogue_label.self_modulate = Color.WHITE
	dialogue_label.text = message
	dialogue_hint_label.text = "Выберите ответ · E — закрыть"
	for choice in choices:
		var choice_id: String = str(choice.get("id", ""))
		var choice_label: String = str(choice.get("label", "Выбрать"))
		if choice_id.is_empty():
			continue
		var button := Button.new()
		button.text = "▸ " + choice_label
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 15)
		button.add_theme_font_size_override("font_size", UiFont.px(9))
		_style_choice(button)
		button.pressed.connect(_on_dialogue_choice_pressed.bind(choice_id))
		dialogue_choices_container.add_child(button)
	dialogue_panel.visible = true
	dialogue_visible = true
	_layout_dialogue()

func _style_choice(button: Button) -> void:
	UiStyle.style_button(button)

func _on_dialogue_choice_pressed(choice_id: String) -> void:
	dialogue_choice_selected.emit(choice_id)

func _clear_dialogue_choices() -> void:
	if dialogue_choices_container == null:
		return
	for child in dialogue_choices_container.get_children():
		dialogue_choices_container.remove_child(child)
		child.queue_free()

func close_dialogue() -> void:
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_dialogue_choices()
	dialogue_panel.visible = false
	dialogue_visible = false

func _make_bar(color: Color, width: float, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, height)
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.13, 0.11, 0.18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", UiFont.px(font_size))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _panel_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.93, 0.78, 0.47, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
