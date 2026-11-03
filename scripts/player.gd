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
var equipment: Dictionary = {"weapon": "", "armor": "", "amulet": "", "relic": ""}
var talents: Dictionary = {}
var starlight_essence_used: int = 0
var equipment_definitions: Dictionary = {}

func _ready() -> void:
	_load_equipment_definitions()
	add_to_group("player")
	health = max_health
	mana = max_mana
	visual = DIRECTIONAL_SPRITE_SCRIPT.new() as DirectionalSprite
	visual.name = "DirectionalVisual"
	visual.configure(HERO_SHEET, 4, 8, 1.0, 8.0)
	visual.offset = Vector2(0.0, -14.0)
	visual.set_direction_vector(facing)
	Vfx.enable_flash(visual)
	add_child(visual)

func start_dodge() -> bool:
	if dodge_time_left > 0.0 or dodge_cooldown_left > 0.0 or health <= 0:
		return false
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	dodge_direction = input_direction.normalized() if input_direction.length_squared() > 0.01 else facing.normalized()
	dodge_time_left = dodge_duration
	dodge_cooldown_left = dodge_cooldown
	visual.modulate = Color(0.55, 0.94, 1.0, 0.72)
	return true

func _physics_process(_delta: float) -> void:
	dodge_cooldown_left = maxf(0.0, dodge_cooldown_left - _delta)
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
		mana_regen_accumulator += _delta * 4.0
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
	velocity = direction * move_speed
	move_and_slide()
	visual.set_direction_vector(facing)
	visual.set_moving(moving)

const CAST_SHEET := "res://assets/sprites/characters/hero_8dir_cast.png"

## Turns the hero towards the target and plays the casting pose.
func play_cast(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		facing = direction.normalized()
		visual.set_direction_vector(facing)
	visual.play_action(CAST_SHEET, 0.32)

func take_damage(amount: int) -> void:
	if dodge_time_left > 0.0 or health <= 0:
		return
	var previous_health: int = health
	health = maxi(0, health - maxi(1, amount - get_armor()))
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
	var definition: Variant = equipment_definitions.get(item_id, {})
	return definition if definition is Dictionary else {}

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

func get_armor() -> int:
	return _equipped_stat("armor")

func get_spell_bonus(spell_id: String = "") -> int:
	var bonus: int = 0
	for item_id in equipment.values():
		var spell_bonuses: Variant = get_item_definition(str(item_id)).get("spell_bonus", {})
		if spell_bonuses is Dictionary:
			bonus += int(spell_bonuses.get("*", 0))
			bonus += int(spell_bonuses.get(spell_id, 0))
	bonus += int(talents.get("arcane_power", 0)) * 3
	if spell_id == "frostbolt":
		bonus += int(talents.get("frost_lore", 0)) * 3
	elif spell_id == "chain_lightning":
		bonus += int(talents.get("storm_focus", 0)) * 3
	return bonus

func get_burn_damage_bonus() -> int:
	return _equipped_stat("burn_damage_bonus")

func get_slow_duration_bonus() -> float:
	var total: float = 0.0
	for item_id in equipment.values():
		total += float(get_item_definition(str(item_id)).get("slow_duration_bonus", 0.0))
	return total

func get_chain_targets_bonus() -> int:
	return _equipped_stat("chain_targets_bonus")

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
	if current_rank >= 3:
		return false
	match talent_id:
		"arcane_power", "frost_lore", "storm_focus", "vitality", "mana_well", "swift_cast":
			talents[talent_id] = current_rank + 1
		_:
			return false
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
			return false
	inventory[item_id] = int(inventory[item_id]) - 1
	if int(inventory[item_id]) <= 0:
		inventory.erase(item_id)
	stats_changed.emit()
	return true
