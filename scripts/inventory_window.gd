extends PanelContainer
class_name InventoryWindow

signal filter_selected(index: int)
signal sort_selected(index: int)
signal use_requested(item_id: String)
signal compare_requested(item_id: String)
signal unequip_requested(slot: String)
signal craft_requested

var equipment_list: VBoxContainer
var stats_label: Label
var item_list: VBoxContainer
var filter_button: OptionButton
var sort_button: OptionButton

func _ready() -> void:
	position = Vector2(8, 26)
	custom_minimum_size = Vector2(286, 318)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.06, 0.09, 0.97)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", UiStyle.panel(false))
	var contents := VBoxContainer.new()
	add_child(contents)
	var top := HBoxContainer.new()
	contents.add_child(top)
	var title := _label("СУМКА  [I — закрыть]", 13, Color(1.0, 0.88, 0.56))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var craft := Button.new()
	craft.text = "Ремесло [B]"
	craft.add_theme_font_size_override("font_size", UiFont.px(9))
	craft.focus_mode = Control.FOCUS_NONE
	UiStyle.small_toggle(craft)
	craft.pressed.connect(func() -> void: craft_requested.emit())
	top.add_child(craft)
	stats_label = _label("", 9, Color(0.75, 0.92, 1.0))
	contents.add_child(stats_label)
	contents.add_child(_label("Экипировка (клик — снять)", 10, Color(0.91, 0.90, 0.75)))
	equipment_list = VBoxContainer.new()
	contents.add_child(equipment_list)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 4)
	contents.add_child(controls)
	filter_button = OptionButton.new()
	filter_button.add_theme_font_size_override("font_size", UiFont.px(9))
	filter_button.custom_minimum_size = Vector2(118, 18)
	filter_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_button.add_item("Все предметы", 0)
	filter_button.add_item("Экипировка", 1)
	filter_button.add_item("Расходники", 2)
	filter_button.tooltip_text = "Фильтр содержимого сумки"
	filter_button.item_selected.connect(func(index: int) -> void: filter_selected.emit(index))
	controls.add_child(filter_button)
	sort_button = OptionButton.new()
	sort_button.add_theme_font_size_override("font_size", UiFont.px(9))
	sort_button.custom_minimum_size = Vector2(118, 18)
	sort_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort_button.add_item("Порядок", 0)
	sort_button.add_item("По названию", 1)
	sort_button.add_item("По редкости", 2)
	sort_button.tooltip_text = "Порядок отображения предметов"
	sort_button.item_selected.connect(func(index: int) -> void: sort_selected.emit(index))
	controls.add_child(sort_button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 170)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents.add_child(scroll)
	item_list = VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(item_list)
	visible = false

func _label(value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", UiFont.px(font_size))
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func populate(player: PlayerCharacter, filter_index: int, sort_index: int, preferred_order: Array, fallback_names: Dictionary, fallback_descriptions: Dictionary, rarity_names: Dictionary, consumable_ids: Array) -> void:
	for child in item_list.get_children():
		item_list.remove_child(child)
		child.queue_free()
	for child in equipment_list.get_children():
		equipment_list.remove_child(child)
		child.queue_free()
	stats_label.text = "Сила магии %d (+%d%% урона) · Воля %d · Ловкость %d · Броня %d" % [
		player.get_stat("power"), roundi((player.get_spell_power_multiplier() - 1.0) * 100.0),
		player.get_stat("will"), player.get_stat("agility"), player.get_armor()]
	var slots: Dictionary = {"blade": "Клинок", "weapon": "Посох", "armor": "Броня", "amulet": "Амулет", "relic": "Реликвия"}
	for slot in ["blade", "weapon", "armor", "amulet", "relic"]:
		var equipped_item: String = str(player.equipment.get(slot, ""))
		var slot_button := Button.new()
		slot_button.text = "%s: %s" % [slots[slot], player.get_item_name(equipped_item) if not equipped_item.is_empty() else "Пусто"]
		slot_button.disabled = equipped_item.is_empty()
		slot_button.add_theme_font_size_override("font_size", UiFont.px(9))
		slot_button.custom_minimum_size = Vector2(0, 16)
		slot_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_button.pressed.connect(func() -> void: unequip_requested.emit(slot))
		equipment_list.add_child(slot_button)
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
	for item_id in available_item_ids:
		var category_name: String = InventoryItemOrder.category(player, item_id, consumable_ids)
		if filter_index == 1 and category_name != "equipment":
			continue
		if filter_index == 2 and category_name != "consumable":
			continue
		item_ids.append(item_id)
	InventoryItemOrder.sort_items(player, item_ids, sort_index, fallback_names)
	if item_ids.is_empty():
		var empty_message: String = "Сумка пуста." if available_item_ids.is_empty() else "Нет предметов в этой категории."
		item_list.add_child(_label(empty_message, 10, Color(0.78, 0.82, 0.85)))
	for item_id in item_ids:
		var button := InventoryItemButton.new()
		button.configure(player, item_id, fallback_names, fallback_descriptions, rarity_names, consumable_ids)
		button.use_requested.connect(func(requested_id: String) -> void: use_requested.emit(requested_id))
		button.compare_requested.connect(func(requested_id: String) -> void: compare_requested.emit(requested_id))
		item_list.add_child(button)
