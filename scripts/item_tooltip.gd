extends RefCounted
class_name ItemTooltip

## The item card shown on hover in the bag and on the hero's slots (owner's
## list №1): name in the rarity colour, type and hands, every stat, what
## changes if the hero puts it on (▲ / ▼), what it would push off, the
## description, set bonuses and the price.

const RARITY_NAMES := {"common": "Обычный", "uncommon": "Необычный", "rare": "Редкий", "epic": "Эпический", "legendary": "Легендарный"}
const TYPE_NAMES := {"blade": "Оружие", "offhand": "Щит · левая рука", "armor": "Броня", "cloak": "Плащ", "amulet": "Амулет",
	"earrings": "Серьги", "ring": "Кольцо", "relic": "Реликвия"}
const KIND_NAMES := {"sword": "меч", "dagger": "кинжал", "spear": "копьё", "hammer": "молот", "staff": "посох", "bow": "лук"}
const WIDTH := 210.0
const UP := Color(0.55, 1.0, 0.55)
const DOWN := Color(1.0, 0.5, 0.45)
const STAT := Color(0.72, 0.93, 1.0)

## "Редкий · Двуручный посох".
static func type_line(player: PlayerCharacter, item_id: String) -> String:
	var definition := player.get_item_definition(item_id)
	var rarity := str(RARITY_NAMES.get(str(definition.get("rarity", "")), ""))
	var slot := player._slot_for_item(item_id)
	var type := ""
	if slot == "blade":
		var kind := str(KIND_NAMES.get(player.weapon_kind_of(item_id), "оружие"))
		type = ("Двуручный " if player.hands(item_id) >= 2 else "Одноручный ") + kind
		if kind in ["копьё"]:
			type = ("Двуручное " if player.hands(item_id) >= 2 else "Одноручное ") + kind
	elif not slot.is_empty():
		type = str(TYPE_NAMES.get(slot, slot))
	elif player.is_quest_item(item_id):
		type = "Предмет задания"
	elif bool(definition.get("material", false)) or definition.has("value") and not definition.has("use"):
		type = "Материал"
	elif definition.has("use"):
		type = "Расходник"
	var parts: Array[String] = []
	for part in [rarity, type]:
		if not str(part).is_empty():
			parts.append(str(part))
	return " · ".join(parts)

## Every stat of the item as lines: "+8 к урону оружием".
static func stat_lines(player: PlayerCharacter, item_id: String) -> Array[String]:
	var definition := player.get_item_definition(item_id)
	var lines: Array[String] = []
	for stat in PlayerCharacter.STAT_NAMES:
		var value := int(definition.get(stat, 0))
		if value == 0:
			continue
		var name := str(PlayerCharacter.STAT_NAMES[stat])
		if name.begins_with("%"):
			lines.append("%+d%s" % [value, name])
		else:
			lines.append("%+d %s" % [value, name])
	var spells: Variant = definition.get("spell_bonus", {})
	if spells is Dictionary:
		for spell in spells:
			var label: String = "всем заклинаниям" if str(spell) == "*" else {"fireball": "огненному шару", "frostbolt": "ледяной стреле", "chain_lightning": "цепной молнии", "fire_wave": "огненной волне", "ice_wall": "ледяной стене", "ball_lightning": "шаровой молнии"}.get(str(spell), str(spell))
			lines.append("+%d урона %s" % [int(spells[spell]), label])
	for extra in [["burn_damage_bonus", "+%d к урону горения"], ["chain_targets_bonus", "+%d прыжка молнии"]]:
		if int(definition.get(extra[0], 0)) != 0:
			lines.append(str(extra[1]) % int(definition[extra[0]]))
	if definition.has("slow_duration_bonus"):
		lines.append("+%.1f с замедления" % float(definition["slow_duration_bonus"]))
	return lines

static func make(player: PlayerCharacter, item_id: String, hint: String = "") -> Control:
	var definition := player.get_item_definition(item_id)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.055, 0.06, 0.97)
	var rarity := str(definition.get("rarity", ""))
	var accent: Color = InventoryItemButton.RARITY_COLORS.get(rarity, Color(0.6, 0.5, 0.4))
	if player.is_quest_item(item_id):
		accent = InventoryItemButton.QUEST_COLOR
	style.border_color = accent
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)
	box.add_child(_line(player.get_item_name(item_id), 11, accent.lightened(0.15)))
	var kind := type_line(player, item_id)
	if not kind.is_empty():
		box.add_child(_line(kind, 8, UiStyle.MUTED))
	var level := int(definition.get("upgrade", 0))
	if level > 0:
		box.add_child(_line("Заточка +%d" % level, 8, UiStyle.GOLD))
	var stats := stat_lines(player, item_id)
	if not stats.is_empty():
		box.add_child(_gap())
		for line in stats:
			box.add_child(_line(line, 9, STAT))
	# What changes if the hero puts it on.
	var comparison := player.get_equipment_comparison(item_id)
	var worn := item_id in player.equipment.values()
	if not comparison.is_empty() and not worn:
		var deltas: Array = comparison.get("stats", [])
		box.add_child(_gap())
		var instead := str(comparison.get("current_name", "Пусто"))
		box.add_child(_line("Если надеть" + (":" if str(comparison.get("current_item_id", "")).is_empty() else " вместо «%s»:" % instead), 8, UiStyle.MUTED))
		if deltas.is_empty():
			box.add_child(_line("  без изменений", 8, UiStyle.MUTED))
		for entry in deltas.slice(0, 8):
			var delta := float(entry.get("delta", 0.0))
			var shown := ("%+d" % roundi(delta)) if is_equal_approx(delta, roundf(delta)) else ("%+.1f" % delta)
			var unit := str(entry.get("unit", ""))
			box.add_child(_line("%s %s%s %s" % ["▲" if delta > 0 else "▼", shown, "%" if unit == "%" else "", str(entry.get("label", ""))], 9, UP if delta > 0 else DOWN))
		for lost in comparison.get("also_removes", []):
			box.add_child(_line("Снимет: %s (две руки)" % str(lost), 8, Color(1.0, 0.8, 0.45)))
	elif worn:
		box.add_child(_line("Надето", 8, Color(0.6, 1.0, 0.6)))
	var description := str(definition.get("description", ""))
	if not description.is_empty() and not definition.get("generated", false):
		box.add_child(_gap())
		box.add_child(_wrapped(description, Color(0.86, 0.84, 0.78)))
	if definition.has("mod_text"):
		box.add_child(_wrapped(str(definition["mod_text"]), Color(0.85, 0.7, 1.0)))
	var set_line := player.set_description(item_id)
	if not set_line.is_empty():
		box.add_child(_wrapped(set_line, Color(0.75, 0.95, 0.7)))
	var effect := str(_effects().get(str(definition.get("base_id", item_id)), ""))
	if not effect.is_empty():
		box.add_child(_wrapped("Особое: " + effect, Color(1.0, 0.75, 0.95)))
	if player.is_quest_item(item_id):
		box.add_child(_line("Предмет задания — хранится всегда, не продаётся", 8, InventoryItemButton.QUEST_COLOR))
	elif int(definition.get("value", 0)) > 0:
		box.add_child(_line("Ценность: %d золота" % int(definition["value"]), 8, UiStyle.GOLD))
	if not hint.is_empty():
		box.add_child(_gap())
		box.add_child(_line(hint, 8, UiStyle.MUTED))
	return panel

## GearEffects.DESCRIPTIONS, read without a class reference (a cycle through
## SkywardGame would stall loading).
static var _effect_texts: Dictionary = {}

static func _effects() -> Dictionary:
	if _effect_texts.is_empty():
		var script: GDScript = load("res://scripts/gear_effects.gd")
		_effect_texts = (script.get_script_constant_map().get("DESCRIPTIONS", {}) as Dictionary).duplicate()
		var trophies: GDScript = load("res://scripts/signature_gear.gd")
		_effect_texts.merge(trophies.get_script_constant_map().get("DESCRIPTIONS", {}))
	return _effect_texts

static func _line(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UiFont.px(font_size))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 2)
	return label

static func _wrapped(text: String, color: Color) -> Label:
	var label := _line(text, 8, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH, 0)
	return label

static func _gap() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 3)
	return gap
