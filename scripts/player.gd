extends CharacterBody2D
class_name PlayerCharacter

signal stats_changed
signal level_up(new_level: int)
signal died
## Sprint or a roll while a charged attack is held cancels it.
signal charge_cancelled

const DIRECTIONAL_SPRITE_SCRIPT := preload("res://scripts/directional_sprite.gd")
const HERO_SHEET := "res://assets/sprites/characters/hero_8dir_walk.png"
const EQUIPMENT_DATA_PATH := "res://data/equipment.json"

@export var move_speed: float = 92.0
@export var max_health: int = 100
@export var max_mana: int = 60
@export var dodge_speed: float = 260.0
@export var dodge_duration: float = 0.20
@export var dodge_cooldown: float = 0.85

## True while a charged sword whirl / aimed shot is held: the hero stands still.
var charge_rooted: bool = false
var health: int = 100
var mana: int = 60
var level: int = 1
var experience: int = 0
var experience_to_next: int = 60
var gold: int = 0
var facing: Vector2 = Vector2.DOWN
var visual: DirectionalSprite
var mana_regen_accumulator: float = 0.0
var dodge_time_left: float = 0.0
## Hold Shift to run.
const SPRINT_MULT := 1.55
var sprinting: bool = false
var dodge_cooldown_left: float = 0.0
var dodge_direction: Vector2 = Vector2.DOWN
var inventory: Dictionary = {}
## Worn gear by slot (owner's list №11, 23–26): the hand weapon, a shield,
## armour, cloak, amulet, earrings, two rings and a relic.
const SLOTS := ["blade", "offhand", "armor", "cloak", "amulet", "earrings", "ring1", "ring2", "relic"]
var equipment: Dictionary = {"blade": "", "offhand": "", "armor": "", "cloak": "", "amulet": "", "earrings": "", "ring1": "", "ring2": "", "relic": ""}
## The bag's hand-made order (owner's list №22): item ids, first to last.
var bag_order: Array = []
var _hp_regen_clock: float = 0.0
var talents: Dictionary = {}
## Rolled equipment definitions by id ("gen_0001"); saved with the hero.
var generated_items: Dictionary = {}
var _generated_counter: int = 0
## Extra skill points from story rewards (on top of one per level).
var bonus_skill_points: int = 0
var second_wind_ready_in: float = 0.0
const SECOND_WIND_COOLDOWN := 90.0
signal second_wind_triggered
signal hurt(amount: int)
## Guard (F): a short parry window, then a block while F is held.
signal parried(source: Node)
signal blocked(amount: int)
const PARRY_WINDOW := 0.3
const GUARD_COOLDOWN := 0.45
const BLOCK_SHARE := 0.4
var parry_left: float = 0.0
var blocking: bool = false
var guard_cooldown_left: float = 0.0
## Guardian's Oath: half damage, blows thrown back at the attacker.
var oath_left: float = 0.0
## Who dealt the latest blow (for gear such as the toad crown).
var last_attacker: Node
var starlight_essence_used: int = 0
var equipment_definitions: Dictionary = {}
## Gear sets (equipment.json → sets): {set_id: {"name", "bonuses": {"2": stats, "3": stats}}}.
var gear_sets: Dictionary = {}
## Phoenix feather: seconds until it can save the hero again.
var phoenix_ready_in: float = 0.0
const PHOENIX_COOLDOWN := 180.0
signal phoenix_triggered

func _ready() -> void:
	_load_equipment_definitions()
	add_to_group("player")
	health = max_health
	mana = max_mana
	visual = DIRECTIONAL_SPRITE_SCRIPT.new() as DirectionalSprite
	visual.name = "DirectionalVisual"
	_apply_look()
	Vfx.enable_flash(visual)
	add_child(visual)
	GroundShadows.attach(self, 15.0)

func heal(amount: int) -> void:
	if health <= 0 or amount <= 0:
		return
	health = mini(max_health, health + amount)
	stats_changed.emit()

func start_guard() -> bool:
	# No shield — no block and no parry (owner's list №25).
	if not has_shield() or guard_cooldown_left > 0.0 or health <= 0 or dodge_time_left > 0.0:
		return false
	parry_left = PARRY_WINDOW + (0.1 if wears_base("crab_aegis") else 0.0)
	blocking = true
	guard_cooldown_left = GUARD_COOLDOWN
	queue_redraw()
	return true

func end_guard() -> void:
	blocking = false
	queue_redraw()

func _draw() -> void:
	if oath_left > 0.0:
		# A golden ward circles the hero during the oath.
		var t := Time.get_ticks_msec() / 400.0
		draw_arc(Vector2(0, -8), 17.0, t, t + TAU * 0.8, 24, Color(1.0, 0.85, 0.4, 0.8), 1.5)
		draw_arc(Vector2(0, -8), 20.0, -t, -t + TAU * 0.5, 18, Color(1.0, 0.95, 0.7, 0.5), 1.0)
	if not blocking:
		return
	# A shimmering guard arc in front of the hero.
	var bright := parry_left > 0.0
	var angle := facing.angle()
	draw_arc(Vector2(0, -8), 15.0, angle - 1.0, angle + 1.0, 14, Color(1.0, 0.95, 0.7, 0.95) if bright else Color(0.7, 0.8, 1.0, 0.7), 3.0 if bright else 2.0)

func start_dodge() -> bool:
	if dodge_time_left > 0.0 or dodge_cooldown_left > 0.0 or health <= 0:
		return false
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	dodge_direction = input_direction.normalized() if input_direction.length_squared() > 0.01 else facing.normalized()
	dodge_time_left = dodge_duration
	dodge_cooldown_left = get_dodge_cooldown()
	if not visual.play_named("roll", dodge_duration):
		visual.modulate = Color(0.55, 0.94, 1.0, 0.72)
	return true

func _physics_process(_delta: float) -> void:
	_update_buffs(_delta)
	dodge_cooldown_left = maxf(0.0, dodge_cooldown_left - _delta)
	guard_cooldown_left = maxf(0.0, guard_cooldown_left - _delta)
	if oath_left > 0.0:
		oath_left = maxf(0.0, oath_left - _delta)
		queue_redraw()
	if parry_left > 0.0:
		parry_left = maxf(0.0, parry_left - _delta)
		queue_redraw()
	second_wind_ready_in = maxf(0.0, second_wind_ready_in - _delta)
	phoenix_ready_in = maxf(0.0, phoenix_ready_in - _delta)
	if dodge_time_left > 0.0:
		dodge_time_left = maxf(0.0, dodge_time_left - _delta)
		velocity = dodge_direction * dodge_speed
		move_and_slide()
		visual.set_direction_vector(dodge_direction)
		visual.set_moving(true)
		if dodge_time_left <= 0.0:
			visual.modulate = Color.WHITE
		return
	# Gear that heals over time (hp_regen: health every 5 seconds).
	var regen := _equipped_stat("hp_regen")
	if regen > 0 and health > 0 and health < max_health:
		_hp_regen_clock += _delta
		if _hp_regen_clock >= 5.0:
			_hp_regen_clock -= 5.0
			health = mini(max_health, health + regen)
			stats_changed.emit()
	else:
		_hp_regen_clock = 0.0
	# Recover mana slowly so casting remains testable during exploration.
	if mana < max_mana:
		mana_regen_accumulator += _delta * get_mana_regen()
		if mana_regen_accumulator >= 1.0:
			var recovered: int = mini(int(mana_regen_accumulator), max_mana - mana)
			mana += recovered
			mana_regen_accumulator -= float(recovered)
			stats_changed.emit()
	else:
		mana_regen_accumulator = 0.0
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# A charged attack roots the hero (owner's list №20); sprinting breaks it.
	if charge_rooted:
		if Input.is_action_pressed("sprint") and direction.length_squared() > 0.01:
			charge_cancelled.emit()
		else:
			velocity = Vector2.ZERO
			visual.set_moving(false)
			return
	var moving := direction.length_squared() > 0.01
	if moving:
		facing = direction.normalized()
	sprinting = moving and not blocking and Input.is_action_pressed("sprint")
	velocity = direction * get_move_speed() * (SPRINT_MULT if sprinting else 1.0)
	move_and_slide()
	visual.set_direction_vector(facing)
	visual.set_moving(moving)

const CAST_SHEET := "res://assets/sprites/characters/hero_8dir_cast.png"
const HERO_F_SHEET := "res://assets/sprites/characters/hero_f_8dir_walk.png"
const CAST_F_SHEET := "res://assets/sprites/characters/hero_f_8dir_cast.png"

## Name and look chosen at the start of a new game ("m" or "f").
var hero_name: String = "Арен"
var hero_gender: String = "m"

func _chibi_id() -> String:
	return "hero_f" if hero_gender == "f" else "hero_m"

## Pack chibi sprites when built (tools/art/chibi.py), else the drawn sheets.
func _apply_look() -> void:
	var keep := visual.direction_index
	if not visual.configure_chibi(_chibi_id(), 10.0):
		visual.chibi_id = ""
		visual.configure(_walk_sheet(), 4, 8, 1.0, 8.0)
		visual.offset = Vector2(0.0, -14.0)
	visual.direction_index = keep
	visual.set_direction_vector(facing)

func _walk_sheet() -> String:
	return HERO_F_SHEET if hero_gender == "f" else HERO_SHEET

func _cast_sheet() -> String:
	return CAST_F_SHEET if hero_gender == "f" else CAST_SHEET

## Applies identity to the sprite and to all formatted text.
func set_identity(new_name: String, gender: String) -> void:
	StoryText.set_hero(new_name, gender)
	hero_name = StoryText.hero_name
	hero_gender = StoryText.hero_gender
	if visual != null:
		_apply_look()

## Turns the hero towards the target and plays the casting pose.
func play_cast(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		facing = direction.normalized()
		visual.set_direction_vector(facing)
	if not visual.play_named("cast", 0.32):
		visual.play_action(_cast_sheet(), 0.32)

func take_damage(amount: int, source: Node = null) -> void:
	if dodge_time_left > 0.0 or health <= 0:
		return
	last_attacker = source
	if parry_left > 0.0:
		# A perfect parry: no damage, the attacker staggers.
		parry_left = 0.0
		guard_cooldown_left = 0.0
		parried.emit(source)
		return
	if blocking:
		var kept := roundi(amount * (1.0 - get_block()))
		blocked.emit(amount - kept)
		amount = kept
	if oath_left > 0.0:
		if source != null and is_instance_valid(source) and source.has_method("take_damage") and source != self:
			source.take_damage(amount)
			var feedback: Variant = source.get("combat_feedback")
			if feedback != null and is_instance_valid(source):
				feedback.show_reaction("ОТРАЖЕНО!")
		amount = roundi(amount * 0.5)
		call_deferred("heal", maxi(1, roundi(max_health * 0.03)))
	var previous_health: int = health
	# Spells and curses meet the magic defence; blows meet the armour.
	var magic := source != null and is_instance_valid(source) and "magic_attacks" in source and bool(source.get("magic_attacks"))
	var defence := (get_resist() + get_armor() / 3) if magic else get_armor()
	health = maxi(0, health - maxi(1, roundi(float(amount - defence) * (1.0 - get_damage_reduction()))))
	if health < previous_health:
		hurt.emit(previous_health - health)
		if visual != null and not visual.is_playing_action():
			visual.play_named("hit", 0.22)
	if health <= 0 and has_skill("second_wind") and second_wind_ready_in <= 0.0:
		# Wanderer's ultimate: survive the blow and recover.
		health = 1 + int(max_health * 0.3)
		second_wind_ready_in = SECOND_WIND_COOLDOWN
		Vfx.level_up(get_parent(), global_position)
		second_wind_triggered.emit()
	elif health <= 0 and phoenix_ready_in <= 0.0 and wears_base("phoenix_feather"):
		# Phoenix feather: rise from the ashes.
		health = maxi(1, int(max_health * 0.4))
		phoenix_ready_in = PHOENIX_COOLDOWN
		Vfx.level_up(get_parent(), global_position)
		phoenix_triggered.emit()
	Vfx.flash(visual, Color(1.0, 0.45, 0.45), 0.2)
	stats_changed.emit()
	if previous_health > 0 and health <= 0:
		died.emit()

func spend_mana(amount: int) -> bool:
	if mana < amount:
		return false
	mana -= amount
	stats_changed.emit()
	return true

## Experience for the next level (owner's list №27/32: a slower, steadier
## climb than the old ×1.42 — see tools/balance_sim.py).
static func xp_for_level(level_now: int) -> int:
	return int(round(60.0 + 45.0 * pow(float(maxi(1, level_now) - 1), 1.55)))

## For companions' share of the experience.
signal experience_gained(amount: int)

func add_experience(amount: int) -> void:
	experience += amount
	if amount > 0:
		experience_gained.emit(amount)
	while experience >= experience_to_next:
		experience -= experience_to_next
		level += 1
		experience_to_next = xp_for_level(level)
		max_health += 10
		max_mana += 5
		health = max_health
		mana = max_mana
		level_up.emit(level)
	stats_changed.emit()

func add_gold(amount: int) -> void:
	gold += amount
	stats_changed.emit()

func _load_equipment_definitions() -> void:
	var file := FileAccess.open(EQUIPMENT_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть каталог экипировки: " + EQUIPMENT_DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("items", {}) is Dictionary:
		equipment_definitions = parsed["items"].duplicate(true)
		gear_sets = parsed.get("sets", {}).duplicate(true)
	else:
		push_error("Некорректный каталог экипировки: " + EQUIPMENT_DATA_PATH)

## Owner's list №17: quest keys stay in the bag for good — never sold.
func is_quest_item(item_id: String) -> bool:
	return bool(get_item_definition(item_id).get("quest_item", false))

func get_item_definition(item_id: String) -> Dictionary:
	var definition: Variant = equipment_definitions.get(item_id, generated_items.get(item_id, {}))
	return definition if definition is Dictionary else {}

## Registers a rolled item (LootGenerator) and returns its new id.
func register_generated_item(definition: Dictionary) -> String:
	_generated_counter += 1
	var item_id := "gen_%04d" % _generated_counter
	while generated_items.has(item_id):
		_generated_counter += 1
		item_id = "gen_%04d" % _generated_counter
	generated_items[item_id] = definition.duplicate(true)
	return item_id

# --- Characteristics -----------------------------------------------------
# Each grows by 1 per level after the first and comes from equipment.

func get_stat(stat: String) -> int:
	return maxi(0, level - 1) + _equipped_stat(stat)

## +2% spell damage per point of power, plus magic damage % from gear;
## a spell id adds its element's % (fire_pct, frost_pct, storm_pct).
func get_spell_power_multiplier(spell_id: String = "") -> float:
	var gear := 1.0 + 0.01 * float(_equipped_stat("spell_pct") + element_pct(spell_id))
	return (1.0 + 0.02 * float(get_stat("power"))) * gear * (1.0 + buff_value("power"))

const ELEMENT_STATS := {"fireball": "fire_pct", "meteor": "fire_pct", "frostbolt": "frost_pct", "chain_lightning": "storm_pct", "fire_wave": "fire_pct", "ice_wall": "frost_pct", "ball_lightning": "storm_pct"}

## % bonus of the spell's element from gear.
func element_pct(spell_id: String) -> int:
	var stat := str(ELEMENT_STATS.get(spell_id, ""))
	return _equipped_stat(stat) if not stat.is_empty() else 0

## Base 4 mana per second, +0.3 per point of will, + mp_regen from gear.
func get_mana_regen() -> float:
	return 4.0 + 0.3 * float(get_stat("will")) + float(_equipped_stat("mp_regen"))

## Magic defence: flat, against spells and curses of enemies.
func get_resist() -> int:
	return _equipped_stat("resist")

## ×2 by default; crit_damage on gear adds to it (+20 → ×2.2).
func get_crit_multiplier() -> float:
	return 2.0 + 0.01 * float(_equipped_stat("crit_damage"))

## Physical damage % from gear (sword, bow, skills).
func get_physical_multiplier() -> float:
	return 1.0 + 0.01 * float(_equipped_stat("melee_pct"))

func has_shield() -> bool:
	return not str(equipment.get("offhand", "")).is_empty()

## Part of a blow a raised shield stops (0..0.8); 0 without a shield.
func get_block() -> float:
	if not has_shield():
		return 0.0
	return clampf(0.01 * float(_equipped_stat("block")), 0.0, 0.8)

## 1 or 2: how many hands the weapon takes (staves, bows, spears, mauls — 2).
func hands(item_id: String) -> int:
	var definition := get_item_definition(item_id)
	if definition.has("hands"):
		return int(definition["hands"])
	return 2 if str(definition.get("slot", "")) == "weapon" or bool(definition.get("bow", false)) else 1

func two_handed() -> bool:
	var blade := str(equipment.get("blade", ""))
	return not blade.is_empty() and hands(blade) >= 2

func has_staff() -> bool:
	return weapon_kind() == "staff"

## Agility: −2% dodge cooldown per point (to 50%) and +1% speed (to +25%).
func get_dodge_cooldown() -> float:
	return dodge_cooldown * maxf(0.5, 1.0 - 0.02 * float(get_stat("agility")))

func get_move_speed() -> float:
	return move_speed * (1.0 + minf(0.25, 0.01 * float(get_stat("agility")))) * (1.0 + buff_value("speed")) * (1.08 if has_passive("fleet") else 1.0) * (0.5 if blocking else 1.0)

func get_item_name(item_id: String) -> String:
	return str(get_item_definition(item_id).get("name", item_id))

func get_item_description(item_id: String) -> String:
	var definition := get_item_definition(item_id)
	var text := str(definition.get("description", ""))
	var level := int(definition.get("upgrade", 0))
	if level > 0:
		text += " Заточка +%d: характеристики +%d%%." % [level, 15 * level]
	var set_line := set_description(item_id)
	if not set_line.is_empty():
		text += "\n" + set_line
	return text

func _equipment_stat(item_id: String, stat: String) -> int:
	return int(get_item_definition(item_id).get(stat, 0))

func _equipped_stat(stat: String) -> int:
	var total: int = 0
	for item_id in equipment.values():
		total += _equipment_stat(str(item_id), stat)
	return total + int(set_bonus_stats().get(stat, 0))

# --- Weapons, sets and forging (Этап 14) -------------------------------------

## True when the worn gear includes this catalog item (also forged "+N" copies).
func wears_base(base_id: String) -> bool:
	for item_id in equipment.values():
		var id := str(item_id)
		if id == base_id or (not id.is_empty() and str(get_item_definition(id).get("base_id", "")) == base_id):
			return true
	return false

## sword | dagger | spear | hammer | staff | bow — the weapon in hand.
func weapon_kind() -> String:
	var blade := str(equipment.get("blade", ""))
	return "sword" if blade.is_empty() else weapon_kind_of(blade)

func weapon_kind_of(item_id: String) -> String:
	var definition := get_item_definition(item_id)
	if bool(definition.get("bow", false)):
		return "bow"
	if definition.has("kind"):
		return str(definition["kind"])
	return "staff" if str(definition.get("slot", "")) == "weapon" or definition.has("spell_bonus") and not definition.has("melee") else "sword"

## Worn pieces per set: {set_id: count}.
func worn_sets() -> Dictionary:
	var counts := {}
	for item_id in equipment.values():
		var set_id := str(get_item_definition(str(item_id)).get("set", ""))
		if not set_id.is_empty():
			counts[set_id] = int(counts.get(set_id, 0)) + 1
	return counts

## Stats granted by the worn set bonuses (spell_bonus kept as a dictionary).
func set_bonus_stats() -> Dictionary:
	var total := {}
	var worn := worn_sets()
	for set_id in worn:
		var bonuses: Dictionary = gear_sets.get(set_id, {}).get("bonuses", {})
		for need in bonuses:
			if int(worn[set_id]) < int(need):
				continue
			var stats: Dictionary = bonuses[need]
			for stat in stats:
				if stats[stat] is Dictionary:
					var spells: Dictionary = total.get(stat, {})
					for spell in stats[stat]:
						spells[spell] = int(spells.get(spell, 0)) + int(stats[stat][spell])
					total[stat] = spells
				else:
					total[stat] = int(total.get(stat, 0)) + int(stats[stat])
	return total

## "Небесная сталь (2/3): +4 урона мечом, +4 брони; 3 — …" for tooltips.
func set_description(item_id: String) -> String:
	var set_id := str(get_item_definition(item_id).get("set", ""))
	if set_id.is_empty() or not gear_sets.has(set_id):
		return ""
	var data: Dictionary = gear_sets[set_id]
	var pieces := 0
	for id in equipment_definitions:
		if str(equipment_definitions[id].get("set", "")) == set_id:
			pieces += 1
	var worn := int(worn_sets().get(set_id, 0))
	var parts: Array[String] = []
	var bonuses: Dictionary = data.get("bonuses", {})
	for need in bonuses:
		parts.append("%s%s — %s" % ["✓ " if worn >= int(need) else "", need, stat_text(bonuses[need])])
	return "Комплект «%s» (%d/%d): %s" % [str(data.get("name", set_id)), worn, pieces, "; ".join(parts)]

const STAT_NAMES := {"melee": "урон оружием", "armor": "броня", "crit": "% крита", "power": "сила магии", "agility": "ловкость",
	"will": "воля", "lifesteal": "вампиризм", "ranged": "урон луком", "max_mana": "мана", "max_health": "здоровье", "haste": "% скорости умений",
	"melee_pct": "% физ. урона", "spell_pct": "% маг. урона", "fire_pct": "% урона огнём", "frost_pct": "% урона льдом", "storm_pct": "% урона молнией",
	"crit_damage": "% крит. урона", "resist": "маг. защита", "hp_regen": "здоровья / 5 с", "mp_regen": "маны / с", "block": "% блока"}

static func stat_text(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for stat in stats:
		if stats[stat] is Dictionary:
			parts.append("+%d к заклинаниям" % int(stats[stat].get("*", 0)))
		else:
			parts.append("+%d %s" % [int(stats[stat]), STAT_NAMES.get(stat, stat)])
	return ", ".join(parts)

const UPGRADE_STATS := ["melee", "armor", "crit", "power", "agility", "will", "ranged", "max_mana", "max_health", "lifesteal", "resist", "melee_pct", "spell_pct", "crit_damage"]
const RARITY_COST := {"common": 1.0, "uncommon": 1.5, "rare": 2.2, "epic": 3.2, "legendary": 4.5}

## Forging level of an item (0 for a plain one).
func upgrade_level(item_id: String) -> int:
	return int(get_item_definition(item_id).get("upgrade", 0))

## What the next forging costs: {"gold", "materials": {id: n}}.
func upgrade_cost(item_id: String) -> Dictionary:
	var definition := get_item_definition(item_id)
	var next := upgrade_level(item_id) + 1
	var mult := float(RARITY_COST.get(str(definition.get("rarity", "common")), 1.0))
	var materials := {"iron_ore": 2 * next}
	if next >= 3:
		materials["obsidian_shard"] = next - 2
	if next >= 4:
		materials["meteor_iron"] = 1
		materials["wind_essence"] = next - 3
	return {"gold": roundi(40.0 * next * mult), "materials": materials}

func can_pay(cost: Dictionary) -> bool:
	if gold < int(cost.get("gold", 0)):
		return false
	var materials: Dictionary = cost.get("materials", {})
	for material in materials:
		if int(inventory.get(material, 0)) < int(materials[material]):
			return false
	return true

## Forges an item one level up (pays the cost). The forged piece becomes its
## own item ("Стальной меч +2", saved with generated items); if it was worn,
## it is worn again. Returns the new id, or "" when it could not be done.
func upgrade_item(item_id: String) -> String:
	var definition := get_item_definition(item_id)
	if str(definition.get("slot", "")).is_empty():
		return ""
	var worn_slot := ""
	for slot in equipment:
		if str(equipment[slot]) == item_id:
			worn_slot = str(slot)
	if worn_slot.is_empty() and int(inventory.get(item_id, 0)) <= 0:
		return ""
	var cost := upgrade_cost(item_id)
	if not can_pay(cost):
		return ""
	gold -= int(cost["gold"])
	var materials: Dictionary = cost["materials"]
	for material in materials:
		remove_item(str(material), int(materials[material]))
	var base_id := str(definition.get("base_id", item_id))
	var base := get_item_definition(base_id) if base_id != item_id else definition
	var next := upgrade_level(item_id) + 1
	var forged := definition.duplicate(true)
	var scale := 1.0 + 0.15 * float(next)
	for stat in UPGRADE_STATS:
		if base.has(stat) and not base[stat] is bool:
			forged[stat] = maxi(int(base[stat]) + next, roundi(float(base[stat]) * scale))
	if base.get("spell_bonus", null) is Dictionary:
		var spells := {}
		for spell in base["spell_bonus"]:
			spells[spell] = maxi(int(base["spell_bonus"][spell]) + next, roundi(float(base["spell_bonus"][spell]) * scale))
		forged["spell_bonus"] = spells
	forged["upgrade"] = next
	forged["base_id"] = base_id
	forged["icon"] = str(base.get("icon", base_id))
	forged["name"] = "%s +%d" % [str(base.get("name", base_id)), next]
	forged["value"] = int(base.get("value", 20)) * (1 + next)
	if next >= 4:
		forged["name"] = "%s (пробуждён) +%d" % [str(base.get("name", base_id)), next]
	var new_id := register_generated_item(forged)
	if not worn_slot.is_empty():
		unequip_slot(worn_slot)
	remove_item(item_id, 1)
	add_item(new_id, 1)
	if not worn_slot.is_empty():
		equip_item(new_id)
	stats_changed.emit()
	return new_id

## Sword damage: base 10, +2 per level, the blade's "melee", +1 per 2 power.
func get_melee_damage() -> int:
	var damage := 10.0 + 2.0 * float(level - 1) + float(_equipped_stat("melee")) + float(get_stat("power")) * 0.5
	damage += float(talents.get("blade_mastery", 0)) * 3.0
	if has_passive("steady_hand"):
		damage *= 1.1
	damage *= get_physical_multiplier()
	# A staff is a mage's tool: it strikes, but softly.
	if has_staff():
		damage *= 0.7
	return int(round(damage * (1.0 + buff_value("power"))))

## A bow in hand: both mouse buttons shoot.
func has_bow() -> bool:
	var weapon := str(equipment.get("blade", ""))
	return not weapon.is_empty() and bool(get_item_definition(weapon).get("bow", false))

## Arrow damage: base 6, +1.8 per level, the bow's "ranged", +0.6 per agility.
func get_ranged_damage() -> int:
	var damage := 6.0 + 1.8 * float(level - 1) + float(_equipped_stat("ranged")) + float(get_stat("agility")) * 0.6
	return int(round(damage * get_physical_multiplier() * (1.0 + buff_value("power"))))

func get_armor() -> int:
	return _equipped_stat("armor") + int(buff_value("armor")) + 2 * int(talents.get("iron_skin", 0)) + (3 if has_passive("toughness") else 0)

# --- Active skills and passives (data/skills.json) ---------------------------

const SKILL_SLOT_COUNT := 4
## Hotbar (keys 1–4): active skill or spell ids, "" for an empty slot.
var skill_slots: Array = ["lunge", "shockwave", "war_cry", "blade_wave"]
## Fishing log: species → {"count", "best"} (size record in cm).
var fish_log: Dictionary = {}

static func skill_catalog() -> Dictionary:
	return GameCatalogs.shared().skills

## Owner's list №29–30: in a story game skills and passives are learned from
## trainers (data/trainers.json); at first the hero only swings the weapon.
## Free play and saves from before keep everything open by level.
var skills_need_learning: bool = false
var learned_skills: Dictionary = {}

func knows(skill_id: String) -> bool:
	return not skills_need_learning or learned_skills.has(skill_id)

## Learns an active skill or passive; a new active goes to a free bar slot.
func learn_skill(skill_id: String) -> bool:
	if learned_skills.has(skill_id):
		return false
	learned_skills[skill_id] = true
	if skill_catalog().get("active", {}).has(skill_id) and not bool(skill_catalog()["active"][skill_id].get("spell", false)) and not skill_slots.has(skill_id):
		var free := skill_slots.find("")
		if free >= 0:
			skill_slots[free] = skill_id
	stats_changed.emit()
	return true

## Passives work once learned and the hero has their level.
func has_passive(passive_id: String) -> bool:
	var definition: Dictionary = skill_catalog().get("passive", {}).get(passive_id, {})
	return not definition.is_empty() and level >= int(definition.get("level", 1)) and knows(passive_id)

## Chance (0..1) that a sword hit deals double damage.
func get_crit_chance() -> float:
	return (0.05 if has_passive("keen_eye") else 0.0) + 0.05 * float(talents.get("keen_edge", 0)) + 0.01 * float(_equipped_stat("crit")) + buff_value("crit")

## Part of incoming damage that is ignored (Unbreakable).
func get_damage_reduction() -> float:
	var reduction := 0.15 if has_skill("unbreakable") else 0.0
	# Golem heart: stone skin when the hero is close to falling.
	if wears_base("golem_heart") and health < max_health * 0.3:
		reduction += 0.3
	return reduction

## Health restored by each sword hit.
func get_melee_lifesteal() -> int:
	return (1 if has_passive("lifeblood") else 0) + int(talents.get("bloodthirst", 0)) + _equipped_stat("lifesteal")

## Gold multiplier from Treasure Sense.
func get_gold_multiplier() -> float:
	return 1.15 if has_passive("treasure_sense") else 1.0

## Cooldown multiplier of the hotbar skills (Battle Rhythm).
func get_skill_cooldown_multiplier() -> float:
	return maxf(0.5, (1.0 - 0.08 * float(talents.get("battle_rhythm", 0))) * (1.0 - 0.01 * float(_equipped_stat("haste"))))

## Puts a skill into a hotbar slot; a skill already on the bar swaps places.
func assign_skill(slot_index: int, skill_id: String) -> bool:
	if slot_index < 0 or slot_index >= SKILL_SLOT_COUNT:
		return false
	while skill_slots.size() < SKILL_SLOT_COUNT:
		skill_slots.append("")
	if not skill_id.is_empty() and not skill_catalog().get("active", {}).has(skill_id):
		return false
	var previous := str(skill_slots[slot_index])
	var existing := skill_slots.find(skill_id)
	if existing >= 0 and not skill_id.is_empty():
		skill_slots[existing] = previous
	skill_slots[slot_index] = skill_id
	stats_changed.emit()
	return true

# --- Food and elixir buffs ---------------------------------------------------

signal recipe_learned(recipe_item: String)
## Recipes taught by scrolls ("recipe_*" items).
var learned_recipes: Dictionary = {}
## type ("power", "armor", "speed", "regen") -> {value, time, label}
var buffs: Dictionary = {}
var _regen_accumulator: float = 0.0

func buff_value(type: String) -> float:
	return float(buffs.get(type, {}).get("value", 0.0))

func add_buff(type: String, value: float, duration: float, label: String) -> void:
	buffs[type] = {"value": value, "time": duration, "label": label}
	stats_changed.emit()

func _update_buffs(delta: float) -> void:
	if buffs.is_empty():
		return
	for type in buffs.keys():
		buffs[type]["time"] = float(buffs[type]["time"]) - delta
		if float(buffs[type]["time"]) <= 0.0:
			buffs.erase(type)
			stats_changed.emit()
	if buffs.has("regen") and health > 0 and health < max_health:
		_regen_accumulator += delta * buff_value("regen")
		if _regen_accumulator >= 1.0:
			var healed := mini(int(_regen_accumulator), max_health - health)
			health += healed
			_regen_accumulator -= float(healed)
			stats_changed.emit()

## Food and elixirs described by "use" in equipment.json.
func _use_generic(item_id: String) -> bool:
	var effect: Variant = get_item_definition(item_id).get("use", {})
	if not effect is Dictionary or effect.is_empty():
		return false
	var heal := int(effect.get("heal", 0))
	var restore := int(effect.get("mana", 0))
	var buff: Variant = effect.get("buff", {})
	if not buff is Dictionary or buff.is_empty():
		if (heal > 0 and health >= max_health) and (restore <= 0 or mana >= max_mana):
			return false
	health = mini(max_health, health + heal)
	mana = mini(max_mana, mana + restore)
	if buff is Dictionary and not buff.is_empty():
		add_buff(str(buff.get("type", "")), float(buff.get("value", 0.0)), float(buff.get("duration", 60.0)), str(buff.get("label", "")))
	return true

func get_spell_bonus(spell_id: String = "") -> int:
	var bonus: int = 0
	for item_id in equipment.values():
		var spell_bonuses: Variant = get_item_definition(str(item_id)).get("spell_bonus", {})
		if spell_bonuses is Dictionary:
			bonus += int(spell_bonuses.get("*", 0))
			bonus += int(spell_bonuses.get(spell_id, 0))
	var set_spells: Variant = set_bonus_stats().get("spell_bonus", {})
	if set_spells is Dictionary:
		bonus += int(set_spells.get("*", 0)) + int(set_spells.get(spell_id, 0))
	bonus += int(talents.get("arcane_power", 0)) * 3
	if spell_id == "fireball":
		bonus += int(talents.get("fire_power", 0)) * 3
	elif spell_id == "frostbolt":
		bonus += int(talents.get("frost_lore", 0)) * 3
	elif spell_id == "chain_lightning":
		bonus += int(talents.get("storm_focus", 0)) * 3
	return bonus

func get_burn_damage_bonus() -> int:
	return _equipped_stat("burn_damage_bonus") + int(talents.get("lingering_flame", 0))

func has_skill(skill_id: String) -> bool:
	return int(talents.get(skill_id, 0)) > 0

func get_slow_duration_bonus() -> float:
	var total: float = 0.0
	for item_id in equipment.values():
		total += float(get_item_definition(str(item_id)).get("slow_duration_bonus", 0.0))
	return total + 0.5 * float(talents.get("deep_chill", 0))

func get_chain_targets_bonus() -> int:
	return _equipped_stat("chain_targets_bonus") + int(talents.get("arc_reach", 0)) + (3 if has_skill("storm_ultimate") else 0)

func _item_spell_bonus(item_id: String, spell_id: String) -> int:
	var bonuses: Variant = get_item_definition(item_id).get("spell_bonus", {})
	if not bonuses is Dictionary:
		return 0
	return int(bonuses.get("*", 0)) + int(bonuses.get(spell_id, 0))

func _append_equipment_comparison_stat(stats: Array[Dictionary], label: String, before: float, after: float, unit: String = "") -> void:
	if is_equal_approx(before, after):
		return
	stats.append({
		"label": label,
		"before": before,
		"after": after,
		"delta": after - before,
		"unit": unit
	})

## Stats shown when two pieces are compared (stat, label, unit).
const COMPARE_STATS := [
	["melee", "Урон оружием", ""], ["ranged", "Урон луком", ""], ["melee_pct", "Физ. урон", "%"],
	["spell_pct", "Маг. урон", "%"], ["fire_pct", "Урон огнём", "%"], ["frost_pct", "Урон льдом", "%"], ["storm_pct", "Урон молнией", "%"],
	["crit", "Шанс крита", "%"], ["crit_damage", "Крит. урон", "%"], ["resist", "Маг. защита", ""], ["block", "Блок щитом", "%"],
	["max_health", "Здоровье", ""], ["hp_regen", "Здоровье / 5 с", ""], ["mp_regen", "Мана / с", ""], ["lifesteal", "Вампиризм", ""],
]

func get_equipment_comparison(item_id: String) -> Dictionary:
	var candidate: Dictionary = get_item_definition(item_id)
	var slot: String = target_slot(item_id)
	if slot.is_empty() or not equipment.has(slot):
		return {}
	var current_item_id: String = str(equipment.get(slot, ""))
	# What comes off: the piece in that slot, and a shield or a two-handed
	# weapon the new piece pushes off.
	var removed: Array[String] = []
	if not current_item_id.is_empty():
		removed.append(current_item_id)
	for other in displaced_by(item_id, slot):
		removed.append(str(equipment[other]))
	var off := func(stat: String) -> float:
		var total := 0.0
		for id in removed:
			total += float(get_item_definition(id).get(stat, 0))
		return total
	var stats: Array[Dictionary] = []
	_append_equipment_comparison_stat(stats, "Броня", float(get_armor()), float(get_armor()) - off.call("armor") + float(candidate.get("armor", 0)))
	_append_equipment_comparison_stat(stats, "Максимум маны", float(max_mana), float(max_mana) - off.call("max_mana") + float(candidate.get("max_mana", 0)))
	for spell_data in [
		{"id": "fireball", "label": "Огненный шар"},
		{"id": "frostbolt", "label": "Ледяная стрела"},
		{"id": "chain_lightning", "label": "Цепная молния"}
	]:
		var spell_id: String = str(spell_data["id"])
		var before_damage: int = get_spell_bonus(spell_id)
		var after_damage: int = before_damage + _item_spell_bonus(item_id, spell_id)
		for id in removed:
			after_damage -= _item_spell_bonus(id, spell_id)
		_append_equipment_comparison_stat(stats, str(spell_data["label"]), float(before_damage), float(after_damage), " урона")
	_append_equipment_comparison_stat(stats, "Урон горения", float(get_burn_damage_bonus()), float(get_burn_damage_bonus()) - off.call("burn_damage_bonus") + float(candidate.get("burn_damage_bonus", 0)), " за тик")
	_append_equipment_comparison_stat(stats, "Длительность замедления", get_slow_duration_bonus(), get_slow_duration_bonus() - off.call("slow_duration_bonus") + float(candidate.get("slow_duration_bonus", 0.0)), " с")
	for stat_data in [["power", "Сила магии"], ["will", "Воля"], ["agility", "Ловкость"]]:
		var stat: String = stat_data[0]
		var before_stat := float(get_stat(stat))
		_append_equipment_comparison_stat(stats, stat_data[1], before_stat, before_stat - off.call(stat) + float(candidate.get(stat, 0)))
	for stat_data in COMPARE_STATS:
		var stat: String = stat_data[0]
		var before := float(_equipped_stat(stat))
		_append_equipment_comparison_stat(stats, stat_data[1], before, before - off.call(stat) + float(candidate.get(stat, 0)), str(stat_data[2]))
	_append_equipment_comparison_stat(stats, "Прыжки молнии", float(get_chain_targets_bonus()), float(get_chain_targets_bonus()) - off.call("chain_targets_bonus") + float(candidate.get("chain_targets_bonus", 0)))
	var lost: Array[String] = []
	for id in removed:
		if id != current_item_id:
			lost.append(get_item_name(id))
	return {
		"slot": slot,
		"current_item_id": current_item_id,
		"candidate_item_id": item_id,
		"current_name": get_item_name(current_item_id) if not current_item_id.is_empty() else "Пусто",
		"candidate_name": get_item_name(item_id),
		"description": get_item_description(item_id),
		"stats": stats,
		"also_removes": lost
	}

func get_cooldown_multiplier() -> float:
	return maxf(0.70, pow(0.92, float(talents.get("swift_cast", 0))))

func apply_talent(talent_id: String) -> bool:
	var current_rank: int = int(talents.get(talent_id, 0))
	var definition: Dictionary = GameCatalogs.shared().talents.get(talent_id, {})
	if definition.is_empty() or current_rank >= int(definition.get("max_rank", 3)):
		return false
	talents[talent_id] = current_rank + 1
	match talent_id:
		"vitality":
			max_health += 15
			health = mini(max_health, health + 15)
		"mana_well":
			max_mana += 12
			mana = mini(max_mana, mana + 12)
	stats_changed.emit()
	return true

## The kind of slot an item goes to: blade, offhand, armor, cloak, amulet,
## earrings, ring or relic. Old staves and bows ("weapon") go to the hand.
func _slot_for_item(item_id: String) -> String:
	var slot := str(get_item_definition(item_id).get("slot", ""))
	return "blade" if slot == "weapon" else slot

## The equipment key an item would take: a ring goes to a free ring slot.
func target_slot(item_id: String, wanted: String = "") -> String:
	var kind := _slot_for_item(item_id)
	if kind == "ring":
		if wanted in ["ring1", "ring2"]:
			return wanted
		for ring in ["ring1", "ring2"]:
			if str(equipment.get(ring, "")).is_empty():
				return ring
		return "ring1"
	return kind if equipment.has(kind) else ""

## Which slot kind an equipment key accepts.
static func slot_kind(slot: String) -> String:
	return "ring" if slot in ["ring1", "ring2"] else slot

## Items a new piece would push off: the shield for a two-handed weapon,
## a two-handed weapon for a shield (owner's list №23–25).
func displaced_by(item_id: String, slot: String) -> Array[String]:
	var result: Array[String] = []
	if slot == "blade" and hands(item_id) >= 2 and has_shield():
		result.append("offhand")
	elif slot == "offhand" and two_handed():
		result.append("blade")
	return result

## Clears everything that lasts only a moment (a ride, a charge, a block, a
## roll, a control lock): called when a save is loaded.
func reset_transient() -> void:
	set_physics_process(true)
	velocity = Vector2.ZERO
	charge_rooted = false
	dodge_time_left = 0.0
	var arena := get_parent()
	if arena != null and arena.get("combat") != null:
		arena.combat._swing = {}
	if blocking:
		end_guard()
	if visual != null:
		visual.stop_action()

func equip_item(item_id: String, wanted_slot: String = "") -> bool:
	var slot: String = target_slot(item_id, wanted_slot)
	if slot.is_empty() or not equipment.has(slot) or int(inventory.get(item_id, 0)) <= 0:
		return false
	if str(equipment.get(slot, "")) == item_id:
		return false
	for other in displaced_by(item_id, slot):
		unequip_slot(other)
	var previous: String = str(equipment.get(slot, ""))
	var mana_delta: int = _equipment_stat(item_id, "max_mana") - _equipment_stat(previous, "max_mana")
	inventory[item_id] = int(inventory[item_id]) - 1
	if int(inventory[item_id]) <= 0:
		inventory.erase(item_id)
	if not previous.is_empty():
		inventory[previous] = int(inventory.get(previous, 0)) + 1
	equipment[slot] = item_id
	max_mana = maxi(1, max_mana + mana_delta)
	# The pool grows, what is in it does not: re-dressing heals nothing.
	mana = clampi(mana, 0, max_mana)
	var health_delta: int = _equipment_stat(item_id, "max_health") - _equipment_stat(previous, "max_health")
	max_health = maxi(1, max_health + health_delta)
	health = clampi(health, 1, max_health)
	if not has_shield():
		end_guard()
	stats_changed.emit()
	return true

func unequip_slot(slot: String) -> bool:
	if not equipment.has(slot):
		return false
	var item_id: String = str(equipment[slot])
	if item_id.is_empty():
		return false
	equipment[slot] = ""
	var mana_delta: int = _equipment_stat(item_id, "max_mana")
	max_mana = maxi(1, max_mana - mana_delta)
	mana = mini(mana, max_mana)
	var health_delta: int = _equipment_stat(item_id, "max_health")
	max_health = maxi(1, max_health - health_delta)
	health = clampi(health, 1, max_health)
	inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	if slot == "offhand":
		end_guard()
	stats_changed.emit()
	return true

## Drag in the bag: puts `item_id` where `before_id` is (or last when empty).
## `shown` is the bag as the player sees it now.
func move_in_bag(item_id: String, before_id: String, shown: Array) -> void:
	var order: Array = []
	for id in shown:
		if int(inventory.get(str(id), 0)) > 0 and not order.has(str(id)):
			order.append(str(id))
	for id in bag_order:
		if int(inventory.get(str(id), 0)) > 0 and not order.has(str(id)):
			order.append(str(id))
	order.erase(item_id)
	var at := order.find(before_id) if not before_id.is_empty() else -1
	if at < 0:
		order.append(item_id)
	else:
		order.insert(at, item_id)
	bag_order = order
	stats_changed.emit()

func add_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	# Recipe scrolls teach the recipe instead of filling the bag.
	if item_id.begins_with("recipe_"):
		if not learned_recipes.has(item_id):
			learned_recipes[item_id] = true
			recipe_learned.emit(item_id)
		stats_changed.emit()
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	stats_changed.emit()

func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or int(inventory.get(item_id, 0)) < amount:
		return false
	inventory[item_id] = int(inventory[item_id]) - amount
	if int(inventory[item_id]) <= 0:
		inventory.erase(item_id)
	stats_changed.emit()
	return true

func use_item(item_id: String) -> bool:
	if int(inventory.get(item_id, 0)) <= 0:
		return false
	match item_id:
		"health_potion":
			if health >= max_health:
				return false
			health = mini(max_health, health + 35)
		"starlight_essence":
			max_mana += 5
			mana += 5
			starlight_essence_used += 1
		"mana_potion":
			if mana >= max_mana:
				return false
			mana = mini(max_mana, mana + 25)
		_:
			if not _use_generic(item_id):
				return false
	inventory[item_id] = int(inventory[item_id]) - 1
	if int(inventory[item_id]) <= 0:
		inventory.erase(item_id)
	stats_changed.emit()
	return true
