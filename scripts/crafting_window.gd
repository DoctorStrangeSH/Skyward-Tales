extends PanelContainer
class_name CraftingWindow

## The crafting window (stations and B — crafting on the road).
## Left: categories, "only what I can make", the recipe list with how many
## times each can be made. Right: the chosen recipe — result, description,
## ingredients with have/need, gold, and buttons to make one or all.

signal craft_requested(recipe_id: String, times: int)
signal closed

const CATEGORIES := [["all", "Всё"], ["consumable", "Зелья и еда"], ["equipment", "Снаряжение"], ["other", "Материалы"], ["book", "Книга рецептов"]]

var game: SkywardGame
var station_id: String = ""
var recipe_ids: Array[String] = []
var selected: String = ""
var category: String = "all"
var only_ready: bool = false

var title_label: Label
var hint_label: Label
var category_buttons: Dictionary = {}
var ready_toggle: CheckButton
var list: VBoxContainer
var rows: Dictionary = {}
var detail_icon: TextureRect
var detail_name: Label
var detail_kind: Label
var detail_text: Label
var needs_box: VBoxContainer
var make_button: Button
var make_all_button: Button
var pin_button: Button
var status_label: Label

func _ready() -> void:
	position = Vector2(12, 12)
	custom_minimum_size = Vector2(616, 324)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.panel(false))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	column.add_child(top)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	title_label = UiStyle.label("РЕМЕСЛО", 14, Color(1.0, 0.88, 0.56))
	heading.add_child(title_label)
	hint_label = UiStyle.label("", 8, UiStyle.MUTED)
	hint_label.clip_text = true
	hint_label.custom_minimum_size = Vector2(100, 0)
	heading.add_child(hint_label)
	var close := Button.new()
	close.text = "Закрыть · Esc"
	close.custom_minimum_size = Vector2(84, 18)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", UiFont.px(9))
	UiStyle.small_toggle(close)
	close.pressed.connect(func() -> void: closed.emit())
	top.add_child(close)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	# Left: filters and the list.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(232, 0)
	left.add_theme_constant_override("separation", 3)
	body.add_child(left)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	left.add_child(tabs)
	for entry in CATEGORIES:
		var button := Button.new()
		button.text = str(entry[1])
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 16)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", UiFont.px(7))
		UiStyle.small_toggle(button)
		var id: String = entry[0]
		button.pressed.connect(func() -> void:
			category = id
			_rebuild_list())
		tabs.add_child(button)
		category_buttons[id] = button
	ready_toggle = CheckButton.new()
	ready_toggle.text = "Только то, что можно сделать"
	ready_toggle.focus_mode = Control.FOCUS_NONE
	ready_toggle.add_theme_font_size_override("font_size", UiFont.px(8))
	ready_toggle.add_theme_color_override("font_color", UiStyle.MUTED)
	ready_toggle.toggled.connect(func(on: bool) -> void:
		only_ready = on
		_rebuild_list())
	left.add_child(ready_toggle)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel", UiStyle.inset(Color(0.06, 0.045, 0.04, 0.75)))
	left.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	# Right: the recipe card.
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiStyle.inset(Color(0.1, 0.075, 0.06, 0.9), UiStyle.SLOT_EDGE, 8))
	body.add_child(card)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	card.add_child(right)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	right.add_child(head)
	var icon_frame := PanelContainer.new()
	icon_frame.add_theme_stylebox_override("panel", UiStyle.inset(UiStyle.SLOT_BG, UiStyle.GOLD, 4))
	head.add_child(icon_frame)
	detail_icon = UiStyle.icon("", 32)
	icon_frame.add_child(detail_icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	detail_name = UiStyle.label("", 12, UiStyle.TITLE)
	names.add_child(detail_name)
	detail_kind = UiStyle.label("", 8, UiStyle.MUTED)
	names.add_child(detail_kind)
	detail_text = UiStyle.label("", 8, Color(0.85, 0.87, 0.9))
	detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_text.custom_minimum_size = Vector2(320, 0)
	right.add_child(detail_text)
	right.add_child(UiStyle.section("Нужно"))
	needs_box = VBoxContainer.new()
	needs_box.add_theme_constant_override("separation", 2)
	needs_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(needs_box)
	status_label = UiStyle.label("", 8, Color(1.0, 0.9, 0.6))
	right.add_child(status_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(buttons)
	pin_button = Button.new()
	pin_button.focus_mode = Control.FOCUS_NONE
	pin_button.custom_minimum_size = Vector2(76, 20)
	pin_button.add_theme_font_size_override("font_size", UiFont.px(9))
	pin_button.tooltip_text = "Держать список нужного на экране"
	UiStyle.style_button(pin_button)
	pin_button.pressed.connect(toggle_pin)
	buttons.add_child(pin_button)
	make_all_button = Button.new()
	make_all_button.focus_mode = Control.FOCUS_NONE
	make_all_button.custom_minimum_size = Vector2(100, 20)
	make_all_button.add_theme_font_size_override("font_size", UiFont.px(9))
	UiStyle.style_button(make_all_button)
	make_all_button.pressed.connect(func() -> void: craft_requested.emit(selected, craftable_times(selected)))
	buttons.add_child(make_all_button)
	make_button = Button.new()
	make_button.text = "Создать  Enter"
	make_button.focus_mode = Control.FOCUS_NONE
	make_button.custom_minimum_size = Vector2(110, 20)
	make_button.add_theme_font_size_override("font_size", UiFont.px(10))
	UiStyle.style_button(make_button)
	make_button.pressed.connect(func() -> void: craft_requested.emit(selected, 1))
	buttons.add_child(make_button)
	visible = false

func open(owner_game: SkywardGame, station: String, title: String, hint: String, ids: Array[String]) -> void:
	game = owner_game
	var same := station == station_id and visible
	station_id = station
	recipe_ids = ids
	title_label.text = title.to_upper()
	hint_label.text = hint
	if not same:
		category = "all"
		if not recipe_ids.has(selected):
			selected = ""
	visible = true
	_rebuild_list()

## How many times the recipe can be made right now.
func craftable_times(recipe_id: String) -> int:
	if game == null or recipe_id.is_empty():
		return 0
	var recipe: Dictionary = game.crafting_service.recipes.get(recipe_id, {})
	if not bool(game.crafting_service.get_recipe_status(game.player, recipe_id).get("success", false)):
		return 0
	if bool(recipe.get("unique_output", false)):
		return 1
	var times := 99
	for ingredient in recipe.get("ingredients", []):
		times = mini(times, int(game.player.inventory.get(str(ingredient.get("item_id", "")), 0)) / maxi(1, int(ingredient.get("amount", 1))))
	var gold := int(recipe.get("gold_cost", 0))
	if gold > 0:
		times = mini(times, game.player.gold / gold)
	return times

func _output_id(recipe_id: String) -> String:
	return str(game.crafting_service.recipes.get(recipe_id, {}).get("output", {}).get("item_id", ""))

func _category_of(recipe_id: String) -> String:
	var output := _output_id(recipe_id)
	var definition := game.player.get_item_definition(output)
	if not str(definition.get("slot", "")).is_empty():
		return "equipment"
	if definition.has("use") or ["health_potion", "mana_potion"].has(output):
		return "consumable"
	return "other"

func _icon_path(item_id: String) -> String:
	var icon_id := str(game.player.get_item_definition(item_id).get("icon", item_id))
	return "icons/%s.png" % icon_id

func _rebuild_list() -> void:
	for id in category_buttons:
		(category_buttons[id] as Button).button_pressed = id == category
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	rows.clear()
	var shown: Array[String] = []
	if category == "book":
		# Этап 24: every recipe of the world — known ones first, then the
		# ones still to learn (where to make them and how to learn them).
		for pass_known in [true, false]:
			for recipe_id in game.crafting_service.recipes:
				if _known(str(recipe_id)) == pass_known:
					shown.append(str(recipe_id))
	# Ready recipes first, the rest after.
	for pass_ready in ([] if category == "book" else [true, false]):
		for recipe_id in recipe_ids:
			if category != "all" and _category_of(recipe_id) != category:
				continue
			var times := craftable_times(recipe_id)
			if (times > 0) != pass_ready or (only_ready and times <= 0):
				continue
			shown.append(recipe_id)
	for recipe_id in shown:
		var row := _row(recipe_id)
		list.add_child(row)
		rows[recipe_id] = row
	if shown.is_empty():
		list.add_child(UiStyle.label("  Нет рецептов в этом разделе.", 8, UiStyle.MUTED))
	if not shown.has(selected):
		selected = shown[0] if not shown.is_empty() else ""
	_show_detail()

func _known(recipe_id: String) -> bool:
	var needs := str(game.crafting_service.recipes.get(recipe_id, {}).get("requires_recipe", ""))
	return needs.is_empty() or game.player.learned_recipes.has(needs)

func _station_name(recipe_id: String) -> String:
	var station := str(game.crafting_service.recipes.get(recipe_id, {}).get("station", ""))
	return str(game.crafting.station(station).get("name", station))

func _row(recipe_id: String) -> Button:
	var recipe: Dictionary = game.crafting_service.recipes[recipe_id]
	var times := craftable_times(recipe_id)
	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 22)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon = WorldArt.texture(_icon_path(_output_id(recipe_id))) if ResourceLoader.exists("res://assets/" + _icon_path(_output_id(recipe_id))) else null
	button.expand_icon = false
	UiStyle.fit_icon(button, 18)
	button.text = str(recipe.get("name", recipe_id))
	if category == "book":
		button.text = ("" if _known(recipe_id) else "? ") + button.text + "  · " + _station_name(recipe_id)
		if not recipe_ids.has(recipe_id):
			times = 0
	button.add_theme_font_size_override("font_size", UiFont.px(8))
	button.add_theme_constant_override("h_separation", 4)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var on: bool = state.contains("pressed")
		var box := UiStyle.inset(Color(0.4, 0.27, 0.13, 0.95) if on else (Color(0.2, 0.14, 0.1, 0.95) if state == "hover" else Color(0.11, 0.08, 0.065, 0.9)), UiStyle.GOLD if on else UiStyle.SLOT_EDGE, 2)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ready_color := Color(0.75, 1.0, 0.7)
	button.add_theme_color_override("font_color", ready_color if times > 0 else UiStyle.MUTED)
	button.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.8))
	button.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.8))
	button.button_pressed = recipe_id == selected
	var badge := UiStyle.label(("×%d" % times) if times > 0 else "", 8, ready_color)
	badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	badge.position.x -= 6
	button.add_child(badge)
	button.pressed.connect(func() -> void:
		selected = recipe_id
		for id in rows:
			(rows[id] as Button).button_pressed = id == recipe_id
		_show_detail())
	return button

func _show_detail() -> void:
	for child in needs_box.get_children():
		needs_box.remove_child(child)
		child.queue_free()
	if selected.is_empty():
		detail_name.text = "—"
		detail_kind.text = ""
		detail_text.text = "Новые рецепты находят в сундуках, покупают и получают в награду."
		detail_icon.texture = null
		make_button.disabled = true
		make_all_button.visible = false
		pin_button.visible = false
		return
	var recipe: Dictionary = game.crafting_service.recipes[selected]
	var output := _output_id(selected)
	var amount := maxi(1, int(recipe.get("output", {}).get("amount", 1)))
	detail_icon.texture = WorldArt.texture(_icon_path(output)) if ResourceLoader.exists("res://assets/" + _icon_path(output)) else null
	detail_name.text = game.player.get_item_name(output) + (" ×%d" % amount if amount > 1 else "")
	var rarity := str(game.player.get_item_definition(output).get("rarity", ""))
	detail_name.add_theme_color_override("font_color", InventoryItemButton.RARITY_COLORS.get(rarity, UiStyle.TITLE))
	detail_kind.text = {"equipment": "Снаряжение", "consumable": "Расходник", "other": "Материал"}[_category_of(selected)] + ("  ·  " + str(recipe.get("name", "")) if str(recipe.get("name", "")) != game.player.get_item_name(output) else "")
	var description := game.player.get_item_description(output)
	if description.is_empty():
		description = str(recipe.get("description", ""))
	if category == "book":
		var where := "Где готовить: %s." % _station_name(selected)
		if not _known(selected):
			var scroll := str(recipe.get("requires_recipe", ""))
			var source := ItemSources.describe(game, scroll)
			where += " Не изучен: нужен свиток «%s»%s." % [game.player.get_item_name(scroll), (" — " + source) if not source.is_empty() else ""]
		description = where + "\n" + description
	detail_text.text = description
	for ingredient in recipe.get("ingredients", []):
		var item_id := str(ingredient.get("item_id", ""))
		var need := int(ingredient.get("amount", 1))
		var have := int(game.player.inventory.get(item_id, 0))
		needs_box.add_child(_need_row(_icon_path(item_id), game.player.get_item_name(item_id), have, need))
		if have < need:
			# Where to get what is missing.
			var source := ItemSources.describe(game, item_id)
			if not source.is_empty():
				var hint := UiStyle.label("   ↳ " + source, 8, Color(0.72, 0.8, 0.95))
				hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				hint.custom_minimum_size = Vector2(150, 0)
				needs_box.add_child(hint)
	var gold := int(recipe.get("gold_cost", 0))
	if gold > 0:
		needs_box.add_child(_need_row("props/loot_coins.png", "Золото", game.player.gold, gold))
	pin_button.visible = true
	pin_button.text = "Открепить" if game.pin.is_pinned("recipe", selected) else "Закрепить"
	var times := craftable_times(selected) if recipe_ids.has(selected) else 0
	make_button.disabled = times <= 0
	make_all_button.visible = times > 1
	make_all_button.text = "Создать все ×%d" % times
	status_label.text = "" if times > 0 else str(game.crafting_service.get_recipe_status(game.player, selected).get("message", ""))
	if not recipe_ids.has(selected):
		status_label.text = "Готовится не здесь: %s." % _station_name(selected) if _known(selected) else "Сначала выучите рецепт."

func _need_row(icon_path: String, item_name: String, have: int, need: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(UiStyle.icon(icon_path, 16, have < need))
	var name_label := UiStyle.label(item_name, 9, UiStyle.TEXT if have >= need else UiStyle.MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiStyle.label("%d / %d" % [have, need], 9, Color(0.6, 1.0, 0.6) if have >= need else Color(1.0, 0.5, 0.45)))
	return row

## Pins / unpins the selected recipe to the quest tracker.
func toggle_pin() -> void:
	if selected.is_empty():
		return
	if game.pin.is_pinned("recipe", selected):
		game.pin.clear()
	else:
		game.pin.pin("recipe", selected)
	_show_detail()

func set_status(text: String) -> void:
	status_label.text = text

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER] and not make_button.disabled:
		craft_requested.emit(selected, 1)
		get_viewport().set_input_as_handled()
