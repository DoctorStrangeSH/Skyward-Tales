extends RefCounted
class_name GameSaveState

## Converts the running game to a save snapshot and back.
## The snapshot format is unchanged, so old saves keep loading.

const DEFAULT_PLAYER_POSITION := Vector2(130, 210)
const FALLBACK_ENEMY_POSITIONS := {
	"guardian": Vector2(1020, 580),
	"shaman": Vector2(730, 360),
	"wolf": Vector2(475, 430),
	"slime": Vector2(475, 350),
	"bat": Vector2(700, 470),
	"echo": Vector2(1000, 660)
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
		if node is SlimeEnemy:
			alive_enemies.append({
				"position": _position_array(node.global_position), "hp": node.health,
				"home": _position_array(node.home_position), "kind": SkywardGame.enemy_kind(node),
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
			"talents": player.talents.duplicate(true), "starlight_essence_used": player.starlight_essence_used,
			"hero_name": player.hero_name, "hero_gender": player.hero_gender
		},
		"quest": {"states": game.quests.states.duplicate(true), "active": game.quests.active_quest_id},
		"world": {
			"region": game.current_region, "relationships": game.relationships.make_snapshot(),
			"enemies": alive_enemies, "herbs": herbs, "loot": loot_items,
			"defeated": game.defeated_enemies, "guardian_defeated": game.guardian_defeated,
			"story_flags": game.director.make_snapshot(),
			"discovered": game.discovered_enemies.duplicate(true), "landmarks": game.discovered_landmarks.duplicate(true),
			"opened_chests": game.opened_chests.duplicate(true), "gathered_resource_nodes": game.gathered_resource_nodes.duplicate(true)
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
	game.discovered_enemies = world_data.get("discovered", {}).duplicate(true)
	game.discovered_landmarks = world_data.get("landmarks", {}).duplicate(true)
	game.opened_chests = world_data.get("opened_chests", {}).duplicate(true)
	game.gathered_resource_nodes = world_data.get("gathered_resource_nodes", {}).duplicate(true)
	game.relationships.restore_snapshot(world_data.get("relationships", {}))
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
	player.inventory = character["inventory"].duplicate(true)
	player.equipment = {"weapon": "", "armor": "", "amulet": "", "relic": ""}
	for slot in player.equipment.keys():
		var saved_item: String = str(character["equipment"].get(slot, ""))
		if not saved_item.is_empty() and player._slot_for_item(saved_item) == str(slot):
			player.equipment[slot] = saved_item
	player.talents = character.get("talents", {}).duplicate(true)
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
		var enemy := game.spawn_enemy(kind, read_position(enemy_data.get("position"), FALLBACK_ENEMY_POSITIONS[kind]))
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
