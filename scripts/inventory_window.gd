extends PanelContainer
class_name InventoryWindow

## The hero window (I or C). Tab "Снаряжение": the hero doll with five
## equipment slots and her characteristics on the left, the bag as a grid of
## item cells on the right — drag an item onto a slot to wear it, drag a worn
## item back to the bag (or click it) to take it off. Tab "Навыки": active
## skills for the 1–4 bar and passives.

signal filter_selected(index: int)
signal sort_selected(index: int)
signal use_requested(item_id: String)
signal compare_requested(item_id: String)
signal compare_cleared
signal unequip_requested(slot: String)
signal craft_requested
signal assign_requested(slot_index: int, skill_id: String)
## A piece dropped on a particular slot (the second ring slot, say).
signal equip_to_requested(item_id: String, slot: String)
## The bag was rearranged by hand.
signal reordered

## Left of the hero: hands and rings; right: armour, cloak and jewellery.
const SLOT_POSITIONS := {"blade": Vector2(4, 4), "offhand": Vector2(4, 36), "ring1": Vector2(4, 82), "ring2": Vector2(4, 114),
	"armor": Vector2(154, 4), "cloak": Vector2(154, 36), "amulet": Vector2(154, 68), "earrings": Vector2(154, 100), "relic": Vector2(154, 132)}
const GRID_COLUMNS := 10
const HINT := "Перетащите вещь на слот героя — надеть, из слота в сумку — снять, по сумке — переложить. Наведите — подробности и сравнение."

var tab: String = "gear"
var tab_buttons: Dictionary = {}
var gear_page: HBoxContainer
var skills_view: SkillsPage
## «Отряд»: companions' level, skills, gear and tactics (owner's list №19).
var party_view: PartyPage
## The five EquipSlot buttons live here (positioned around the hero).
var equipment_list: Control
var slot_buttons: Dictionary = {}
var stats_label: Label
var stats_grid: GridContainer
var item_list: GridContainer
var bag_area: BagDropArea
var filter_button: OptionButton
var sort_button: OptionButton
var detail: Label
var bag_caption: Label
## Category tabs over the bag: all, equipment, consumables, resources.
var category_tabs: Array = []
const CATEGORIES := [["Всё", "ui/menu_bag.png"], ["Снаряжение", "icons/iron_sword.png"], ["Расходники", "icons/health_potion.png"], ["Ресурсы", "icons/wood.png"]]
const MIN_ROWS := 6
var _portrait: AtlasTexture
var _portrait_rect: TextureRect
var _frame := 0
var _clock := 0.0
var _player: PlayerCharacter
var _skills: CombatSkills
## The bag cells in the order shown (for drag reordering).
var _shown: Array[String] = []

func _reorder(item_id: String, before_id: String) -> void:
	if _player == null or item_id.is_empty() or item_id == before_id:
		return
	_player.move_in_bag(item_id, before_id, _shown)
	reordered.emit()

func _ready() -> void:
	position = Vector2(12, 12)
	custom_minimum_size = Vector2(616, 334)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.panel(false))
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 4)
	add_child(contents)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	contents.add_child(top)
	var title := _label("ГЕРОЙ", 14, Color(1.0, 0.88, 0.56))
	title.custom_minimum_size = Vector2(70, 0)
	top.add_child(title)
	for entry in [["gear", "Снаряжение"], ["skills", "Навыки"], ["party", "Отряд"]]:
		var button := Button.new()
		button.text = entry[1]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(92, 20)
		button.add_theme_font_size_override("font_size", UiFont.px(10))
		UiStyle.small_toggle(button)
		var tab_id: String = entry[0]
		button.pressed.connect(func() -> void: show_tab(tab_id))
		top.add_child(button)
		tab_buttons[tab_id] = button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var craft := Button.new()
	craft.text = "Ремесло [B]"
	craft.add_theme_font_size_override("font_size", UiFont.px(9))
	craft.focus_mode = Control.FOCUS_NONE
	UiStyle.small_toggle(craft)
	craft.pressed.connect(func() -> void: craft_requested.emit())
	top.add_child(craft)
	top.add_child(_label("  I / C — закрыть", 8, UiStyle.MUTED))
	_build_gear_page(contents)
	skills_view = SkillsPage.new()
	skills_view.visible = false
	skills_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skills_view.assign_requested.connect(func(index: int, skill_id: String) -> void: assign_requested.emit(index, skill_id))
	skills_view.detail_changed.connect(func(text: String) -> void: detail.text = text)
	contents.add_child(skills_view)
	party_view = PartyPage.new()
	party_view.visible = false
	party_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	party_view.changed.connect(func() -> void:
		if _player != null:
			_player.stats_changed.emit())
	contents.add_child(party_view)
	detail = _label("", 9, Color(0.86, 0.9, 0.95))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(596, 26)
	detail.text = HINT
	contents.add_child(detail)
	visible = false

func _build_gear_page(contents: VBoxContainer) -> void:
	gear_page = HBoxContainer.new()
	gear_page.add_theme_constant_override("separation", 10)
	contents.add_child(gear_page)
	# Left: the doll and characteristics.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(188, 0)
	left.add_theme_constant_override("separation", 4)
	gear_page.add_child(left)
	var doll := Control.new()
	doll.custom_minimum_size = Vector2(188, 162)
	left.add_child(doll)
	var stage := Panel.new()
	stage.position = Vector2(42, 4)
	stage.size = Vector2(104, 150)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.16, 0.22, 0.2, 0.9)
	frame.border_color = Color(0.62, 0.45, 0.27)
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(4)
	stage.add_theme_stylebox_override("panel", frame)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll.add_child(stage)
	_portrait_rect = TextureRect.new()
	_portrait_rect.position = Vector2(46, 14)
	_portrait_rect.size = Vector2(96, 96)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll.add_child(_portrait_rect)
	equipment_list = Control.new()
	equipment_list.size = Vector2(188, 160)
	equipment_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll.add_child(equipment_list)
	stats_label = _label("", 9, UiStyle.TITLE)
	stats_label.position = Vector2(46, 116)
	stats_label.size = Vector2(96, 30)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	doll.add_child(stats_label)
	stats_grid = GridContainer.new()
	stats_grid.columns = 4
	stats_grid.add_theme_constant_override("h_separation", 4)
	stats_grid.add_theme_constant_override("v_separation", 0)
	left.add_child(stats_grid)
	# Right: the bag.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 3)
	gear_page.add_child(right)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 4)
	right.add_child(controls)
	bag_caption = _label("СУМКА", 11, UiStyle.TITLE)
	bag_caption.custom_minimum_size = Vector2(150, 0)
	bag_caption.clip_text = true
	controls.add_child(bag_caption)
	for index in CATEGORIES.size():
		var tab_button := Button.new()
		tab_button.toggle_mode = true
		tab_button.focus_mode = Control.FOCUS_NONE
		tab_button.custom_minimum_size = Vector2(0, 18)
		tab_button.tooltip_text = str(CATEGORIES[index][0])
		var icon_path := str(CATEGORIES[index][1])
		if ResourceLoader.exists("res://assets/" + icon_path):
			tab_button.icon = WorldArt.texture(icon_path)
		tab_button.expand_icon = false
		UiStyle.fit_icon(tab_button, 14)
		tab_button.add_theme_font_size_override("font_size", UiFont.px(8))
		tab_button.add_theme_constant_override("h_separation", 2)
		UiStyle.small_toggle(tab_button)
		var category_index: int = index
		tab_button.pressed.connect(func() -> void:
			filter_button.select(category_index)
			filter_selected.emit(category_index))
		controls.add_child(tab_button)
		category_tabs.append(tab_button)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(grow)
	filter_button = OptionButton.new()
	filter_button.visible = false
	filter_button.add_theme_font_size_override("font_size", UiFont.px(9))
	filter_button.custom_minimum_size = Vector2(104, 18)
	filter_button.focus_mode = Control.FOCUS_NONE
	filter_button.add_item("Все предметы", 0)
	filter_button.add_item("Снаряжение", 1)
	filter_button.add_item("Расходники", 2)
	filter_button.add_item("Материалы", 3)
	filter_button.tooltip_text = "Фильтр содержимого сумки"
	filter_button.item_selected.connect(func(index: int) -> void: filter_selected.emit(index))
	controls.add_child(filter_button)
	sort_button = OptionButton.new()
	sort_button.custom_minimum_size = Vector2(70, 18)
	sort_button.add_theme_font_size_override("font_size", UiFont.px(9))
	sort_button.focus_mode = Control.FOCUS_NONE
	sort_button.add_item("Обычно", 0)
	sort_button.add_item("А–Я", 1)
	sort_button.add_item("Редкость", 2)
	sort_button.tooltip_text = "Порядок отображения предметов"
	sort_button.item_selected.connect(func(index: int) -> void: sort_selected.emit(index))
	controls.add_child(sort_button)
	bag_area = BagDropArea.new()
	bag_area.custom_minimum_size = Vector2(0, 238)
	bag_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag_area.unequip_requested.connect(func(slot: String) -> void: unequip_requested.emit(slot))
	bag_area.reorder_requested.connect(_reorder)
	var bag_bg := StyleBoxFlat.new()
	bag_bg.bg_color = Color(0.06, 0.045, 0.04, 0.7)
	bag_bg.set_corner_radius_all(3)
	bag_bg.set_content_margin_all(4)
	bag_area.add_theme_stylebox_override("panel", bag_bg)
	right.add_child(bag_area)
	item_list = GridContainer.new()
	item_list.columns = GRID_COLUMNS
	item_list.add_theme_constant_override("h_separation", 3)
	item_list.add_theme_constant_override("v_separation", 3)
	bag_area.add_child(item_list)

func _label(value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", UiFont.px(font_size))
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func show_tab(tab_id: String) -> void:
	tab = tab_id
	for id in tab_buttons:
		(tab_buttons[id] as Button).button_pressed = id == tab
	gear_page.visible = tab == "gear"
	skills_view.visible = tab == "skills"
	party_view.visible = tab == "party"
	detail.text = HINT if tab == "gear" else ("Компаньоны растут вместе с вами: очки навыков — за уровни, вещи — из вашей сумки." if tab == "party" else "")
	if tab == "skills" and _player != null:
		skills_view.populate(_player, _skills)
	if tab == "party" and _skills != null:
		party_view.populate(_skills.game.crew)

func set_skills(skills: CombatSkills) -> void:
	_skills = skills

func _process(delta: float) -> void:
	if not visible or _portrait == null:
		return
	_clock += delta
	if _clock >= 0.16:
		_clock = 0.0
		_frame = (_frame + 1) % 6
		_portrait.region = Rect2(16 + 64 * _frame, 12, 32, 32)

func populate(player: PlayerCharacter, filter_index: int, sort_index: int, preferred_order: Array, fallback_names: Dictionary, fallback_descriptions: Dictionary, rarity_names: Dictionary, consumable_ids: Array) -> void:
	_player = player
	for id in tab_buttons:
		(tab_buttons[id] as Button).button_pressed = id == tab
	if tab == "skills":
		skills_view.populate(player, _skills)
	if tab == "party" and _skills != null:
		party_view.populate(_skills.game.crew)
	_populate_doll(player)
	for child in item_list.get_children():
		item_list.remove_child(child)
		child.queue_free()
	var available_item_ids: Array[String] = []
	for item_id in preferred_order:
		if int(player.inventory.get(item_id, 0)) > 0:
			available_item_ids.append(item_id)
	var additional_item_ids: Array[String] = []
	for key in player.inventory.keys():
		var item_id: String = str(key)
		if not preferred_order.has(item_id) and int(player.inventory.get(item_id, 0)) > 0:
			additional_item_ids.append(item_id)
	additional_item_ids.sort()
	available_item_ids.append_array(additional_item_ids)
	var item_ids: Array[String] = []
	var counts := [available_item_ids.size(), 0, 0, 0]
	for item_id in available_item_ids:
		counts[{"equipment": 1, "consumable": 2}.get(InventoryItemOrder.category(player, item_id, consumable_ids), 3)] += 1
	for index in category_tabs.size():
		var tab_button: Button = category_tabs[index]
		tab_button.button_pressed = index == filter_index
		tab_button.text = str(counts[index])
	for item_id in available_item_ids:
		var category_name: String = InventoryItemOrder.category(player, item_id, consumable_ids)
		if filter_index == 1 and category_name != "equipment":
			continue
		if filter_index == 2 and category_name != "consumable":
			continue
		if filter_index == 3 and category_name != "other":
			continue
		item_ids.append(item_id)
	InventoryItemOrder.sort_items(player, item_ids, sort_index, fallback_names)
	if sort_index == 0:
		# "Обычно": gear first, then consumables, then resources — or the
		# player's own order once the bag was rearranged (new items go last).
		var rank := {"equipment": 0, "consumable": 1, "other": 2}
		var grouped: Array[String] = []
		for wanted in [0, 1, 2]:
			for item_id in item_ids:
				if int(rank.get(InventoryItemOrder.category(player, item_id, consumable_ids), 2)) == wanted:
					grouped.append(item_id)
		item_ids = grouped
		if not player.bag_order.is_empty():
			var placed: Array[String] = []
			for id in player.bag_order:
				if item_ids.has(str(id)):
					placed.append(str(id))
			for id in item_ids:
				if not placed.has(id):
					placed.append(id)
			item_ids = placed
	_shown = item_ids.duplicate()
	bag_caption.text = "СУМКА · %s" % str(CATEGORIES[clampi(filter_index, 0, CATEGORIES.size() - 1)][0]).to_upper()
	if item_ids.is_empty():
		bag_caption.text += "  — пусто" if available_item_ids.is_empty() else ""
	for item_id in item_ids:
		var button := InventoryItemButton.new()
		button.configure(player, item_id, fallback_names, fallback_descriptions, rarity_names, consumable_ids)
		button.use_requested.connect(func(requested_id: String) -> void: use_requested.emit(requested_id))
		# The item card (tooltip) now shows the comparison itself.
		button.unequip_requested.connect(func(slot: String) -> void: unequip_requested.emit(slot))
		button.reorder_requested.connect(_reorder)
		var line := button.summary
		var hints := button.tooltip_text.split("\n")
		var hint: String = hints[mini(hints.size() - 1, 1)] if hints.size() > 1 else hints[0]
		button.hovered.connect(func(_id: String) -> void: detail.text = line + "   ·   " + hint)
		button.unhovered.connect(func() -> void: compare_cleared.emit())
		item_list.add_child(button)
	# Empty cells make the bag read as a bag.
	var shown := item_list.get_child_count()
	var cells := maxi(MIN_ROWS * GRID_COLUMNS, int(ceil(float(shown) / GRID_COLUMNS)) * GRID_COLUMNS)
	for index in cells - shown:
		item_list.add_child(EmptyBagCell.new())

func _populate_doll(player: PlayerCharacter) -> void:
	for child in equipment_list.get_children():
		equipment_list.remove_child(child)
		child.queue_free()
	slot_buttons.clear()
	for slot in PlayerCharacter.SLOTS:
		var button := EquipSlot.new()
		button.setup(player, slot)
		button.position = SLOT_POSITIONS[slot]
		button.equip_requested.connect(func(item_id: String, target: String) -> void: equip_to_requested.emit(item_id, target))
		button.unequip_requested.connect(func(s: String) -> void: unequip_requested.emit(s))
		button.hovered.connect(func(s: String) -> void:
			var worn := str(player.equipment.get(s, ""))
			var empty_line := "занята: двуручное оружие держат обеими руками" if s == "offhand" and player.two_handed() else "пусто — перетащите сюда подходящий предмет из сумки"
			detail.text = "%s: %s" % [EquipSlot.NAMES[s], (player.get_item_name(worn) + "   ·   клик или перетащите в сумку — снять") if not worn.is_empty() else empty_line])
		equipment_list.add_child(button)
		slot_buttons[slot] = button
	var sheet := WorldArt.texture("sprites/chibi/%s/idle.png" % player._chibi_id())
	if sheet != null:
		if _portrait == null:
			_portrait = AtlasTexture.new()
			_portrait.region = Rect2(16, 12, 32, 32)
		_portrait.atlas = sheet
		_portrait_rect.texture = _portrait
	stats_label.text = "%s\nур. %d" % [player.hero_name, player.level]
	for child in stats_grid.get_children():
		stats_grid.remove_child(child)
		child.queue_free()
	var regen := player._equipped_stat("hp_regen")
	var lines := [
		["Здоровье", "%d/%d" % [player.health, player.max_health]], ["Мана", "%d/%d" % [player.mana, player.max_mana]],
		["Физ. урон", "%d · %s" % [player.get_melee_damage() if not player.has_bow() else player.get_ranged_damage(), str(SkywardGame.WEAPON_PROFILES.get(player.weapon_kind(), {}).get("name", "Меч")).to_lower()]],
		["Маг. урон", "+%d%%" % roundi((player.get_spell_power_multiplier() - 1.0) * 100.0)],
		["Крит", "%d%%" % roundi(player.get_crit_chance() * 100.0)], ["Крит. урон", "×%.1f" % player.get_crit_multiplier()],
		["Броня", str(player.get_armor())], ["Маг. защ.", str(player.get_resist())],
		["Блок", ("%d%%" % roundi(player.get_block() * 100.0)) if player.has_shield() else "нет щита"], ["Реген", ("+%d/5с" % regen) if regen > 0 else "—"],
		["Ловкость", str(player.get_stat("agility"))], ["Воля", str(player.get_stat("will"))],
		["Сила маг.", str(player.get_stat("power"))], ["Опыт", "%d/%d" % [player.experience, player.experience_to_next]],
		["Золото", str(player.gold)],
	]
	for line in lines:
		var name_label := _label(line[0], 7, UiStyle.MUTED)
		name_label.custom_minimum_size = Vector2(40, 0)
		stats_grid.add_child(name_label)
		var value_label := _label(line[1], 7, UiStyle.TEXT)
		value_label.custom_minimum_size = Vector2(52, 0)
		value_label.clip_text = true
		stats_grid.add_child(value_label)
	# Old callers read the compact line too.
	stats_label.tooltip_text = "Сила магии %d (+%d%% урона) · Воля %d · Ловкость %d · Броня %d" % [
		player.get_stat("power"), roundi((player.get_spell_power_multiplier() - 1.0) * 100.0),
		player.get_stat("will"), player.get_stat("agility"), player.get_armor()]
