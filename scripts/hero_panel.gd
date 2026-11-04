extends PanelContainer
class_name HeroPanel

## Hero window (C): "Снаряжение" — the hero with equipment slots around her
## and all characteristics; "Навыки" — active skills with buttons to put
## them on the 1–4 bar, and passives that switch on with levels.

signal unequip_requested(slot: String)
signal assign_requested(slot_index: int, skill_id: String)

const SLOT_NAMES := {"blade": "Клинок", "weapon": "Посох", "armor": "Броня", "amulet": "Амулет", "relic": "Реликвия"}
const LEFT_SLOTS := ["blade", "weapon"]
const RIGHT_SLOTS := ["armor", "amulet", "relic"]
const RARITY_NAMES := {"common": "обычный", "uncommon": "необычный", "rare": "редкий", "epic": "эпический", "legendary": "легендарный"}

var tab: String = "gear"
var tab_buttons: Dictionary = {}
var body: Control
var slot_buttons: Dictionary = {}
var skill_rows: Dictionary = {}
var stats_grid: GridContainer
var detail: Label
var _player: PlayerCharacter
var _skills: CombatSkills
var _portrait: AtlasTexture
var _frame := 0
var _clock := 0.0

func _ready() -> void:
	position = Vector2(20, 16)
	custom_minimum_size = Vector2(600, 324)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.panel(false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)
	top.add_child(_label("ГЕРОЙ  [C — закрыть]", 14, UiStyle.TITLE))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	for entry in [["gear", "Снаряжение"], ["skills", "Навыки"]]:
		var button := Button.new()
		button.text = entry[1]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(96, 20)
		button.add_theme_font_size_override("font_size", UiFont.px(10))
		UiStyle.small_toggle(button)
		var tab_id: String = entry[0]
		button.pressed.connect(func() -> void: show_tab(tab_id))
		top.add_child(button)
		tab_buttons[tab_id] = button
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	detail = _label("", 9, Color(0.85, 0.88, 0.95))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(580, 24)
	box.add_child(detail)
	visible = false

func populate(player: PlayerCharacter, skills: CombatSkills) -> void:
	_player = player
	_skills = skills
	for tab_id in tab_buttons:
		(tab_buttons[tab_id] as Button).button_pressed = tab_id == tab
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	slot_buttons.clear()
	skill_rows.clear()
	_portrait = null
	if tab == "gear":
		_build_gear()
	else:
		_build_skills()

func show_tab(tab_id: String) -> void:
	tab = tab_id
	detail.text = ""
	if _player != null:
		populate(_player, _skills)

func _process(delta: float) -> void:
	if not visible or _portrait == null:
		return
	_clock += delta
	if _clock >= 0.16:
		_clock = 0.0
		_frame = (_frame + 1) % 6
		_portrait.region = Rect2(16 + 64 * _frame, 12, 32, 32)

# --- Equipment tab -------------------------------------------------------------

func _build_gear() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	var doll := HBoxContainer.new()
	doll.add_theme_constant_override("separation", 4)
	row.add_child(doll)
	doll.add_child(_slot_column(LEFT_SLOTS))
	var figure := PanelContainer.new()
	figure.custom_minimum_size = Vector2(150, 200)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.16, 0.24, 0.2, 0.9)
	frame.border_color = Color(0.62, 0.45, 0.27)
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(4)
	figure.add_theme_stylebox_override("panel", frame)
	doll.add_child(figure)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	figure.add_child(stack)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(144, 144)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sheet := WorldArt.texture("sprites/chibi/%s/idle.png" % _player._chibi_id())
	if sheet != null:
		_portrait = AtlasTexture.new()
		_portrait.atlas = sheet
		_portrait.region = Rect2(16, 12, 32, 32)
		art.texture = _portrait
	stack.add_child(art)
	var name_label := _label("%s · ур. %d" % [_player.hero_name, _player.level], 11, UiStyle.TITLE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(name_label)
	var xp := ProgressBar.new()
	xp.custom_minimum_size = Vector2(120, 5)
	xp.show_percentage = false
	xp.max_value = maxi(1, _player.experience_to_next)
	xp.value = _player.experience
	stack.add_child(xp)
	doll.add_child(_slot_column(RIGHT_SLOTS))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(_label("Характеристики", 11, UiStyle.TITLE))
	stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 12)
	stats_grid.add_theme_constant_override("v_separation", 2)
	right.add_child(stats_grid)
	for line in stat_lines(_player):
		stats_grid.add_child(_label(line[0], 9, UiStyle.MUTED))
		stats_grid.add_child(_label(line[1], 9, UiStyle.TEXT))
	right.add_child(_label("Клик по слоту — снять. Сумка — I, таланты — T.", 8, UiStyle.MUTED))

static func stat_lines(player: PlayerCharacter) -> Array:
	return [
		["Здоровье", "%d / %d" % [player.health, player.max_health]],
		["Мана", "%d / %d" % [player.mana, player.max_mana]],
		["Опыт", "%d / %d" % [player.experience, player.experience_to_next]],
		["Урон мечом", str(player.get_melee_damage())],
		["Шанс крита", "%d%%" % roundi(player.get_crit_chance() * 100.0)],
		["Сила магии", "%d (+%d%%)" % [player.get_stat("power"), roundi((player.get_spell_power_multiplier() - 1.0) * 100.0)]],
		["Броня", str(player.get_armor())],
		["Ловкость", str(player.get_stat("agility"))],
		["Воля", str(player.get_stat("will"))],
		["Скорость", "%d" % roundi(player.get_move_speed())],
		["Вампиризм", "%d HP за удар" % player.get_melee_lifesteal()],
		["Золото", str(player.gold)],
	]

func _slot_column(slots: Array) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	for slot in slots:
		column.add_child(_label(SLOT_NAMES[slot], 8, UiStyle.MUTED))
		column.add_child(_slot_button(str(slot)))
	return column

func _slot_button(slot: String) -> Button:
	var item_id := str(_player.equipment.get(slot, ""))
	var definition := _player.get_item_definition(item_id) if not item_id.is_empty() else {}
	var rarity := str(definition.get("rarity", "common"))
	var button := Button.new()
	button.custom_minimum_size = Vector2(36, 36)
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.06, 0.92)
	style.border_color = InventoryItemButton.RARITY_COLORS.get(rarity, Color(0.6, 0.5, 0.4)) if not item_id.is_empty() else Color(0.35, 0.27, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.14, 0.1, 0.95)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", style)
	var icon_id := str(definition.get("icon", item_id))
	if not item_id.is_empty() and ResourceLoader.exists("res://assets/icons/%s.png" % icon_id):
		button.icon = WorldArt.texture("icons/%s.png" % icon_id)
	button.disabled = item_id.is_empty()
	var info := "%s — пусто" % SLOT_NAMES[slot]
	if not item_id.is_empty():
		info = "%s: %s (%s). %s" % [SLOT_NAMES[slot], _player.get_item_name(item_id), RARITY_NAMES.get(rarity, rarity), _player.get_item_description(item_id)]
	button.mouse_entered.connect(func() -> void: detail.text = info)
	button.pressed.connect(func() -> void: unequip_requested.emit(slot))
	slot_buttons[slot] = button
	return button

# --- Skills tab ----------------------------------------------------------------

func _build_skills() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	row.add_child(left)
	left.add_child(_label("Активные навыки — кнопки 1–4 ставят на панель", 10, UiStyle.TITLE))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	var actives := CombatSkills.actives()
	for skill_id in actives:
		list.add_child(_active_row(str(skill_id), actives[skill_id]))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(_label("Пассивные — открываются с уровнем", 10, UiStyle.TITLE))
	var passives := CombatSkills.passives()
	for passive_id in passives:
		right.add_child(_passive_row(str(passive_id), passives[passive_id]))

func _active_row(skill_id: String, data: Dictionary) -> Control:
	var reason := _skills.lock_reason(skill_id) if _skills != null else ""
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 4)
	row.add_child(_icon(CombatSkills.icon_path(skill_id), not reason.is_empty()))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var title := str(data.get("name", skill_id))
	if not reason.is_empty():
		title += "  · " + (("откроется на ур. " + reason.trim_prefix("Ур. ")) if reason.begins_with("Ур.") else reason.to_lower())
	elif not CombatSkills.is_spell(skill_id):
		title += "  · откат %s с" % str(data.get("cooldown", 0))
	text.add_child(_label(title, 9, UiStyle.TEXT if reason.is_empty() else UiStyle.MUTED))
	var description := _label(str(data.get("description", "")), 8, Color(0.75, 0.78, 0.85))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(200, 0)
	text.add_child(description)
	var buttons: Array = []
	for index in PlayerCharacter.SKILL_SLOT_COUNT:
		var button := Button.new()
		button.text = str(index + 1)
		button.toggle_mode = true
		button.button_pressed = index < _player.skill_slots.size() and str(_player.skill_slots[index]) == skill_id
		button.custom_minimum_size = Vector2(15, 15)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", UiFont.px(8))
		UiStyle.small_toggle(button)
		var slot_index: int = index
		button.pressed.connect(func() -> void: assign_requested.emit(slot_index, skill_id))
		row.add_child(button)
		buttons.append(button)
	row.mouse_entered.connect(func() -> void: detail.text = "%s — %s" % [str(data.get("name", skill_id)), str(data.get("description", ""))])
	skill_rows[skill_id] = buttons
	return row

func _passive_row(passive_id: String, data: Dictionary) -> Control:
	var active := _player.has_passive(passive_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_icon(CombatSkills.icon_path(passive_id), not active))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var state := "✓ действует" if active else "ур. %d" % int(data.get("level", 1))
	text.add_child(_label("%s  · %s" % [str(data.get("name", passive_id)), state], 9, Color(0.7, 1.0, 0.7) if active else UiStyle.MUTED))
	var description := _label(str(data.get("description", "")), 8, Color(0.75, 0.78, 0.85))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(190, 0)
	text.add_child(description)
	skill_rows[passive_id] = active
	return row

func _icon(path: String, dim: bool) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(24, 24)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/" + path):
		rect.texture = WorldArt.texture(path)
	if dim:
		rect.modulate = Color(0.45, 0.45, 0.5)
	return rect

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UiFont.px(font_size))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
