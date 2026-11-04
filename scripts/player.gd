extends CharacterBody2D
class_name PlayerCharacter

signal stats_changed
signal level_up(new_level: int)
signal died

const DIRECTIONAL_SPRITE_SCRIPT := preload("res://scripts/directional_sprite.gd")
const HERO_SHEET := "res://assets/sprites/characters/hero_8dir_walk.png"
const EQUIPMENT_DATA_PATH := "res://data/equipment.json"

@export var move_speed: float = 92.0
@export var max_health: int = 100
@export var max_mana: int = 60
@export var dodge_speed: float = 260.0
@export var dodge_duration: float = 0.20
@export var dodge_cooldown: float = 0.85

var health: int = 100
var mana: int = 60
var level: int = 1
var experience: int = 0
var experience_to_next: int = 40
var gold: int = 0
var facing: Vector2 = Vector2.DOWN
var visual: DirectionalSprite
var mana_regen_accumulator: float = 0.0
var dodge_time_left: float = 0.0
var dodge_cooldown_left: float = 0.0
var dodge_direction: Vector2 = Vector2.DOWN
var inventory: Dictionary = {}
var equipment: Dictionary = {"blade": "", "weapon": "", "armor": "", "amulet": "", "relic": ""}
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
var starlight_essence_used: int = 0
var equipment_definitions: Dictionary = {}

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
	second_wind_ready_in = maxf(0.0, second_wind_ready_in - _delta)
	if dodge_time_left > 0.0:
		dodge_time_left = maxf(0.0, dodge_time_left - _delta)
		velocity = dodge_direction * dodge_speed
		move_and_slide()
		visual.set_direction_vector(dodge_direction)
		visual.set_moving(true)
		if dodge_time_left <= 0.0:
			visual.modulate = Color.WHITE
		return
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
	var moving := direction.length_squared() > 0.01
	if moving:
		facing = direction.normalized()
	velocity = direction * get_move_speed()
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

func take_damage(amount: int) -> void:
	if dodge_time_left > 0.0 or health <= 0:
		return
	var previous_health: int = health
	health = maxi(0, health - maxi(1, roundi(float(amount - get_armor()) * (1.0 - get_damage_reduction()))))
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

func add_experience(amount: int) -> void:
	experience += amount
	while experience >= experience_to_next:
		experience -= experience_to_next
		level += 1
		experience_to_next = int(round(float(experience_to_next) * 1.35))
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
	else:
		push_error("Некорректный каталог экипировки: " + EQUIPMENT_DATA_PATH)

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

## +2% spell damage per point of power.
func get_spell_power_multiplier() -> float:
	return (1.0 + 0.02 * float(get_stat("power"))) * (1.0 + buff_value("power"))

## Base 4 mana per second, +0.3 per point of will.
func get_mana_regen() -> float:
	return 4.0 + 0.3 * float(get_stat("will"))

## Agility: −2% dodge cooldown per point (to 50%) and +1% speed (to +25%).
func get_dodge_cooldown() -> float:
	return dodge_cooldown * maxf(0.5, 1.0 - 0.02 * float(get_stat("agility")))

func get_move_speed() -> float:
	return move_speed * (1.0 + minf(0.25, 0.01 * float(get_stat("agility")))) * (1.0 + buff_value("speed")) * (1.08 if has_passive("fleet") else 1.0)

func get_item_name(item_id: String) -> String:
	return str(get_item_definition(item_id).get("name", item_id))

func get_item_description(item_id: String) -> String:
	return str(get_item_definition(item_id).get("description", ""))

func _equipment_stat(item_id: String, stat: String) -> int:
	return int(get_item_definition(item_id).get(stat, 0))

func _equipped_stat(stat: String) -> int:
	var total: int = 0
	for item_id in equipment.values():
		total += _equipment_stat(str(item_id), stat)
	return total

## Sword damage: base 10, +2 per level, the blade's "melee", +1 per 2 power.
func get_melee_damage() -> int:
	var damage := 10.0 + 2.0 * float(level - 1) + float(_equipped_stat("melee")) + float(get_stat("power")) * 0.5
	damage += float(talents.get("blade_mastery", 0)) * 3.0
	if has_passive("steady_hand"):
		damage *= 1.1
	return int(round(damage * (1.0 + buff_value("power"))))

func get_armor() -> int:
	return _equipped_stat("armor") + int(buff_value("armor")) + 2 * int(talents.get("iron_skin", 0)) + (3 if has_passive("toughness") else 0)

# --- Active skills and passives (data/skills.json) ---------------------------

const SKILL_SLOT_COUNT := 4
## Hotbar (keys 1–4): active skill or spell ids, "" for an empty slot.
var skill_slots: Array = ["lunge", "shockwave", "war_cry", "blade_wave"]

static func skill_catalog() -> Dictionary:
	return GameCatalogs.shared().skills

## Passives switch on by themselves when the hero reaches their level.
func has_passive(passive_id: String) -> bool:
	var definition: Dictionary = skill_catalog().get("passive", {}).get(passive_id, {})
	return not definition.is_empty() and level >= int(definition.get("level", 1))

## Chance (0..1) that a sword hit deals double damage.
func get_crit_chance() -> float:
	return (0.05 if has_passive("keen_eye") else 0.0) + 0.05 * float(talents.get("keen_edge", 0))

## Part of incoming damage that is ignored (Unbreakable).
func get_damage_reduction() -> float:
	return 0.15 if has_skill("unbreakable") else 0.0

## Health restored by each sword hit.
func get_melee_lifesteal() -> int:
	return (1 if has_passive("lifeblood") else 0) + int(talents.get("bloodthirst", 0))

## Gold multiplier from Treasure Sense.
func get_gold_multiplier() -> float:
	return 1.15 if has_passive("treasure_sense") else 1.0

## Cooldown multiplier of the hotbar skills (Battle Rhythm).
func get_skill_cooldown_multiplier() -> float:
	return maxf(0.6, 1.0 - 0.08 * float(talents.get("battle_rhythm", 0)))

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

func get_equipment_comparison(item_id: String) -> Dictionary:
	var candidate: Dictionary = get_item_definition(item_id)
	var slot: String = str(candidate.get("slot", ""))
	if slot.is_empty() or not equipment.has(slot):
		return {}
	var current_item_id: String = str(equipment.get(slot, ""))
	var stats: Array[Dictionary] = []
	var current_definition: Dictionary = get_item_definition(current_item_id)

	_append_equipment_comparison_stat(
		stats, "Броня", float(get_armor()),
		float(get_armor() - int(current_definition.get("armor", 0)) + int(candidate.get("armor", 0)))
	)
	_append_equipment_comparison_stat(
		stats, "Максимум маны", float(max_mana),
		float(max_mana - int(current_definition.get("max_mana", 0)) + int(candidate.get("max_mana", 0)))
	)
	for spell_data in [
		{"id": "fireball", "label": "Огненный шар"},
		{"id": "frostbolt", "label": "Ледяная стрела"},
		{"id": "chain_lightning", "label": "Цепная молния"}
	]:
		var spell_id: String = str(spell_data["id"])
		var before_damage: int = get_spell_bonus(spell_id)
		var after_damage: int = before_damage - _item_spell_bonus(current_item_id, spell_id) + _item_spell_bonus(item_id, spell_id)
		_append_equipment_comparison_stat(stats, str(spell_data["label"]), float(before_damage), float(after_damage), " урона")
	_append_equipment_comparison_stat(
		stats, "Урон горения", float(get_burn_damage_bonus()),
		float(get_burn_damage_bonus() - int(current_definition.get("burn_damage_bonus", 0)) + int(candidate.get("burn_damage_bonus", 0))),
		" за тик"
	)
	_append_equipment_comparison_stat(
		stats, "Длительность замедления", get_slow_duration_bonus(),
		get_slow_duration_bonus() - float(current_definition.get("slow_duration_bonus", 0.0)) + float(candidate.get("slow_duration_bonus", 0.0)),
		" с"
	)
	for stat_data in [["power", "Сила магии"], ["will", "Воля"], ["agility", "Ловкость"]]:
		var stat: String = stat_data[0]
		var before_stat := float(get_stat(stat))
		_append_equipment_comparison_stat(stats, stat_data[1], before_stat, before_stat - float(current_definition.get(stat, 0)) + float(candidate.get(stat, 0)))
	_append_equipment_comparison_stat(
		stats, "Прыжки молнии", float(get_chain_targets_bonus()),
		float(get_chain_targets_bonus() - int(current_definition.get("chain_targets_bonus", 0)) + int(candidate.get("chain_targets_bonus", 0)))
	)
	return {
		"slot": slot,
		"current_item_id": current_item_id,
		"candidate_item_id": item_id,
		"current_name": get_item_name(current_item_id) if not current_item_id.is_empty() else "Пусто",
		"candidate_name": get_item_name(item_id),
		"description": get_item_description(item_id),
		"stats": stats
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

func _slot_for_item(item_id: String) -> String:
	return str(get_item_definition(item_id).get("slot", ""))

func equip_item(item_id: String) -> bool:
	var slot: String = _slot_for_item(item_id)
	if slot.is_empty() or not equipment.has(slot) or int(inventory.get(item_id, 0)) <= 0:
		return false
	if str(equipment.get(slot, "")) == item_id:
		return false
	var previous: String = str(equipment.get(slot, ""))
	var mana_delta: int = _equipment_stat(item_id, "max_mana") - _equipment_stat(previous, "max_mana")
	inventory[item_id] = int(inventory[item_id]) - 1
	if int(inventory[item_id]) <= 0:
		inventory.erase(item_id)
	if not previous.is_empty():
		inventory[previous] = int(inventory.get(previous, 0)) + 1
	equipment[slot] = item_id
	max_mana = maxi(1, max_mana + mana_delta)
	mana = clampi(mana + maxi(0, mana_delta), 0, max_mana)
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
	inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	stats_changed.emit()
	return true
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
