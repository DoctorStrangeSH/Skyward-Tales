extends RefCounted
class_name GameSaveState

## Converts the running game to a save snapshot and back.
## The snapshot format is unchanged, so old saves keep loading.

const DEFAULT_PLAYER_POSITION := Vector2(270, 625)
const FALLBACK_ENEMY_POSITIONS := {
	"guardian": Vector2(1020, 580),
	"shaman": Vector2(730, 360),
	"wolf": Vector2(475, 430),
	"slime": Vector2(475, 350),
	"bat": Vector2(700, 470),
	"echo": Vector2(1000, 660),
	"sentinel": Vector2(640, 500),
	"wisp": Vector2(620, 600),
	"tempest": Vector2(760, 300),
	"shade": Vector2(600, 600),
	"vail": Vector2(900, 320),
	"toad": Vector2(640, 560),
	"bog_king": Vector2(1030, 700),
	"crab": Vector2(640, 760),
	"crab_king": Vector2(700, 940),
	"golem": Vector2(300, 780),
	"giant": Vector2(1380, 300),
	"skeleton": Vector2(780, 400),
	"crypt_lord": Vector2(880, 860)
}

static func _position_array(pos: Vector2) -> Array[float]:
	return [pos.x, pos.y]

static func read_position(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback

static func capture(game: SkywardGame) -> Dictionary:
	var player := game.player
	var alive_enemies: Array = []
	var herbs: Array = []
	var loot_items: Array = []
	for node in game.get_children():
		if node.is_queued_for_deletion():
			continue
		if node is SlimeEnemy and not node.has_meta("legend") and not node.has_meta("rift_echo") and not node.has_meta("event_foe") and not node.has_meta("bounty") and not node is LootImp:
			alive_enemies.append({
				"position": _position_array(node.global_position), "hp": node.health,
				"home": _position_array(node.home_position), "kind": SkywardGame.enemy_kind(node), "elite": node.elite_id,
				"burn_remaining": node.burn_time_left, "burn_tick": node.burn_tick_timer, "burn_damage": node.burn_damage
			})
		elif node is WorldCollectible:
			herbs.append({"position": _position_array(node.global_position), "id": node.item_id, "name": node.display_name})
		elif node is WorldLoot:
			loot_items.append({"position": _position_array(node.global_position), "id": node.item_id, "amount": node.amount})
	return {
		"player": {
			"position": _position_array(player.global_position),
			"health": player.health, "max_health": player.max_health,
			"mana": player.mana, "max_mana": player.max_mana,
			"level": player.level, "experience": player.experience,
			"experience_to_next": player.experience_to_next,
			"gold": player.gold,
			"inventory": player.inventory.duplicate(true),
			"equipment": player.equipment.duplicate(true),
			"talents": player.talents.duplicate(true), "skill_slots": player.skill_slots.duplicate(), "learned_skills": player.learned_skills.duplicate(), "skills_need_learning": player.skills_need_learning, "fish_log": player.fish_log.duplicate(true), "starlight_essence_used": player.starlight_essence_used,
			"bonus_skill_points": player.bonus_skill_points,
			"generated_items": player.generated_items.duplicate(true), "generated_counter": player._generated_counter,
			"hero_name": player.hero_name, "hero_gender": player.hero_gender,
			"learned_recipes": player.learned_recipes.duplicate(),
			"bag_order": player.bag_order.duplicate()
		},
		"quest": {"states": game.quests.states.duplicate(true), "active": game.quests.active_quest_id},
		"world": {
			"region": game.current_region, "relationships": game.relationships.make_snapshot(),
			"enemies": alive_enemies, "herbs": herbs, "loot": loot_items,
			"defeated": game.defeated_enemies, "guardian_defeated": game.guardian_defeated,
			"story_flags": game.director.make_snapshot(),
			"discovered": game.discovered_enemies.duplicate(true), "landmarks": game.discovered_landmarks.duplicate(true),
			"opened_chests": game.opened_chests.duplicate(true), "gathered_resource_nodes": game.gathered_resource_nodes.duplicate(true),
			"settlement": game.settlement.make_snapshot(),
			"crafting": game.crafting.make_snapshot(),
			"visited": game.visited_regions.duplicate(),
			"doors": game.opened_doors.duplicate(),
			"day": game.day_night.make_snapshot(), "treasure": game.treasure.make_snapshot(), "contracts": game.contracts.make_snapshot(),
			"legends": game.legends.make_snapshot(), "achievements": game.achievements.make_snapshot(), "lore": game.lore.make_snapshot(), "epilogue": game.epilogue.make_snapshot(), "world_state": game.world_state.make_snapshot(), "mine": game.mine.make_snapshot(), "combos": game.combos.make_snapshot(), "farm": game.farm.make_snapshot(), "lira": game.lira.make_snapshot(), "fair": game.fair.make_snapshot(), "trials": game.trials.make_snapshot(), "cistern": game.cistern.make_snapshot(), "hens": game.hens.make_snapshot(), "scout": game.scout.make_snapshot(), "bran": game.bran.make_snapshot(), "buildings": game.buildings.make_snapshot(), "guild": game.guild.make_snapshot(), "expeditions": game.expeditions.make_snapshot(), "ship": game.ship.make_snapshot(), "factions": game.factions.make_snapshot(), "fates": game.fates.make_snapshot(), "party": game.party.make_snapshot(), "crew": game.crew.make_snapshot(), "deep_rifts": game.deep_rifts.make_snapshot(), "ng_plus": game.ng_plus
		},
		"magic": game.selected_spell_id
	}

## Applies a validated snapshot. Returns false (and changes nothing) for invalid data.
static func apply(game: SkywardGame, data: Dictionary) -> bool:
	if not SaveSystem.validate_snapshot(data):
		return false
	var character: Dictionary = data["player"]
	var quest_data: Dictionary = data["quest"]
	var world_data: Dictionary = data["world"]
	var player := game.player
	game.guardian_defeated = bool(world_data.get("guardian_defeated", false))
	game.director.restore_snapshot(world_data.get("story_flags", {}))
	if game.director.has_flag("mira_companion"):
		game.ensure_companion()
	elif game.companion != null:
		game.companion.queue_free()
		game.companion = null
	game.discovered_enemies = world_data.get("discovered", {}).duplicate(true)
	game.discovered_landmarks = world_data.get("landmarks", {}).duplicate(true)
	game.opened_chests = world_data.get("opened_chests", {}).duplicate(true)
	game.gathered_resource_nodes = world_data.get("gathered_resource_nodes", {}).duplicate(true)
	game.relationships.restore_snapshot(world_data.get("relationships", {}))
	game.settlement.restore_snapshot(world_data.get("settlement", {}))
	game.crafting.restore_snapshot(world_data.get("crafting", {}))
	game.day_night.restore_snapshot(world_data.get("day", {}))
	game.treasure.restore_snapshot(world_data.get("treasure", {}))
	game.contracts.restore_snapshot(world_data.get("contracts", {}))
	game.legends.restore_snapshot(world_data.get("legends", {}))
	game.achievements.restore_snapshot(world_data.get("achievements", {}))
	game.lore.restore_snapshot(world_data.get("lore", {}))
	game.epilogue.restore_snapshot(world_data.get("epilogue", {}))
	game.world_state.restore_snapshot(world_data.get("world_state", {}))
	game.mine.restore_snapshot(world_data.get("mine", {}))
	game.combos.restore_snapshot(world_data.get("combos", {}))
	game.farm.restore_snapshot(world_data.get("farm", {}))
	game.lira.restore_snapshot(world_data.get("lira", {}))
	game.fair.restore_snapshot(world_data.get("fair", {}))
	game.trials.restore_snapshot(world_data.get("trials", {}))
	game.cistern.restore_snapshot(world_data.get("cistern", {}))
	game.hens.restore_snapshot(world_data.get("hens", {}))
	game.scout.restore_snapshot(world_data.get("scout", {}))
	game.bran.restore_snapshot(world_data.get("bran", {}))
	game.buildings.restore_snapshot(world_data.get("buildings", {}))
	game.guild.restore_snapshot(world_data.get("guild", {}))
	game.expeditions.restore_snapshot(world_data.get("expeditions", {}))
	game.ship.restore_snapshot(world_data.get("ship", {}))
	game.factions.restore_snapshot(world_data.get("factions", {}))
	game.fates.restore_snapshot(world_data.get("fates", {}))
	game.party.restore_snapshot(world_data.get("party", {}))
	game.crew.restore_snapshot(world_data.get("crew", {}))
	game.deep_rifts.restore_snapshot(world_data.get("deep_rifts", {}))
	game.ng_plus = maxi(0, int(world_data.get("ng_plus", 0)))
	game.party.ensure_follower()
	game.party.apply_mira()
	var visited: Variant = world_data.get("visited", {})
	game.visited_regions = visited.duplicate() if visited is Dictionary else {}
	var doors: Variant = world_data.get("doors", {})
	game.opened_doors = doors.duplicate() if doors is Dictionary else {}
	var saved_position := read_position(character.get("position"), DEFAULT_PLAYER_POSITION)
	game._set_region(str(world_data.get("region", "greenreach")), saved_position, false)
	for quest_id in quest_data["states"]:
		if game.quests.states.has(quest_id) and quest_data["states"][quest_id] is Dictionary:
			game.quests.states[quest_id] = quest_data["states"][quest_id].duplicate(true)
	game.quests.active_quest_id = str(quest_data.get("active", ""))
	_apply_player(player, character)
	game.pending_level_choices.clear()
	if game.hud.talent_visible:
		game.hud.hide_talent_choices()
	player.global_position = saved_position
	_restore_world_actors(game, world_data)
	game.defeated_enemies = maxi(0, int(world_data.get("defeated", 0)))
	var spell_id: String = str(data.get("magic", "fireball"))
	if game.spell_definitions.has(spell_id):
		game.selected_spell_id = spell_id
	game.cast_cooldown_remaining = 0.0
	game.cast_cooldown_total = 0.0
	return true

static func _apply_player(player: PlayerCharacter, character: Dictionary) -> void:
	player.level = maxi(1, int(character.get("level", 1)))
	player.experience = maxi(0, int(character.get("experience", 0)))
	player.experience_to_next = maxi(1, int(character.get("experience_to_next", 40)))
	player.gold = maxi(0, int(character.get("gold", 0)))
	player.max_health = maxi(1, int(character.get("max_health", 100)))
	player.max_mana = maxi(1, int(character.get("max_mana", 60)))
	player.health = clampi(int(character.get("health", player.max_health)), 1, player.max_health)
	player.mana = clampi(int(character.get("mana", player.max_mana)), 0, player.max_mana)
	# Rolled item definitions first, so equipment and loot can refer to them.
	var rolled: Variant = character.get("generated_items", {})
	player.generated_items = rolled.duplicate(true) if rolled is Dictionary else {}
	player._generated_counter = maxi(int(character.get("generated_counter", 0)), player.generated_items.size())
	player.inventory = character["inventory"].duplicate(true)
	player.equipment = {}
	for slot in PlayerCharacter.SLOTS:
		player.equipment[slot] = ""
	var saved_gear: Dictionary = character["equipment"]
	for slot in PlayerCharacter.SLOTS:
		var saved_item: String = str(saved_gear.get(slot, ""))
		if not saved_item.is_empty() and player._slot_for_item(saved_item) == PlayerCharacter.slot_kind(str(slot)):
			player.equipment[slot] = saved_item
	# Saves before package C: the staff or bow lived in its own "weapon" slot,
	# and cloaks and the granite aegis in "armor". Such pieces take their new
	# place when it is free, otherwise they go back to the bag.
	for old_slot in ["weapon", "armor"]:
		var old_item := str(saved_gear.get(old_slot, ""))
		if old_item.is_empty() or player.equipment.values().has(old_item):
			continue
		var target := player.target_slot(old_item)
		if not target.is_empty() and str(player.equipment.get(target, "")).is_empty() and not (target == "offhand" and player.two_handed()) and not (target == "blade" and player.hands(old_item) >= 2 and player.has_shield()):
			player.equipment[target] = old_item
		else:
			player.inventory[old_item] = int(player.inventory.get(old_item, 0)) + 1
			player.max_mana = maxi(1, player.max_mana - player._equipment_stat(old_item, "max_mana"))
			player.max_health = maxi(1, player.max_health - player._equipment_stat(old_item, "max_health"))
	player.health = mini(player.health, player.max_health)
	player.mana = mini(player.mana, player.max_mana)
	var order: Variant = character.get("bag_order", [])
	player.bag_order = (order as Array).duplicate() if order is Array else []
	player.talents = character.get("talents", {}).duplicate(true)
	player.fish_log = (character.get("fish_log", {}) as Dictionary).duplicate(true) if character.get("fish_log", {}) is Dictionary else {}
	player.skills_need_learning = bool(character.get("skills_need_learning", false))
	var learned: Variant = character.get("learned_skills", {})
	player.learned_skills = (learned as Dictionary).duplicate() if learned is Dictionary else {}
	var slots: Variant = character.get("skill_slots", [])
	if slots is Array and not (slots as Array).is_empty():
		player.skill_slots = (slots as Array).duplicate()
	var recipes: Variant = character.get("learned_recipes", {})
	player.learned_recipes = recipes.duplicate() if recipes is Dictionary else {}
	player.buffs = {}
	player.bonus_skill_points = maxi(0, int(character.get("bonus_skill_points", 0)))
	player.starlight_essence_used = maxi(0, int(character.get("starlight_essence_used", 0)))
	# Saves from before character creation default to Арен.
	player.set_identity(str(character.get("hero_name", "")), str(character.get("hero_gender", "m")))

static func _restore_world_actors(game: SkywardGame, world_data: Dictionary) -> void:
	# Queued old nodes must leave the scene tree immediately.
	for node in game.get_children():
		if node is SlimeEnemy or node is WorldCollectible or node is WorldLoot or node is MagicBolt or node is EnemyMagicOrb:
			game.remove_child(node)
			node.queue_free()
	for herb_data in world_data["herbs"]:
		if herb_data is Dictionary:
			game._spawn_herb(read_position(herb_data.get("position"), Vector2.ZERO), str(herb_data.get("id", "moonleaf")), str(herb_data.get("name", "Лунный лист")))
		else:
			game._spawn_herb(read_position(herb_data, Vector2.ZERO))
	for enemy_data in world_data["enemies"]:
		if not enemy_data is Dictionary:
			continue
		var kind: String = str(enemy_data.get("kind", "slime"))
		if not FALLBACK_ENEMY_POSITIONS.has(kind):
			kind = "slime"
		var enemy := game.spawn_enemy(kind, read_position(enemy_data.get("position"), FALLBACK_ENEMY_POSITIONS[kind]), str(enemy_data.get("elite", "")))
		if enemy == null:
			continue
		enemy.health = clampi(int(enemy_data.get("hp", enemy.max_health)), 1, enemy.max_health)
		if enemy is GroveGuardian and enemy.health <= enemy.max_health / 2:
			(enemy as GroveGuardian).enraged = true
			enemy.move_speed = 44.0
			enemy.attack_cooldown_duration = 1.2
		enemy.home_position = read_position(enemy_data.get("home"), enemy.global_position)
		enemy.burn_time_left = maxf(0.0, float(enemy_data.get("burn_remaining", 0.0)))
		enemy.burn_damage = maxi(0, int(enemy_data.get("burn_damage", 0)))
		enemy.burn_tick_timer = clampf(float(enemy_data.get("burn_tick", 0.5)), 0.001, enemy.burn_tick_interval)
	for loot_data in world_data["loot"]:
		if not loot_data is Dictionary:
			continue
		var drop := game._spawn_loot(read_position(loot_data.get("position"), Vector2.ZERO), str(loot_data.get("id", "health_potion")))
		drop.amount = maxi(1, int(loot_data.get("amount", 1)))
