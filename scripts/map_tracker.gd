extends RefCounted
class_name MapTracker

## Split out of main.gd (Этап 18, tech debt). Every SkywardGame member is
## reached through `game`; main.gd keeps one-line wrappers with the old names.

var game: SkywardGame

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

## The map (M). From a sky stone it opens on the world tab, ready to travel.
func open_map(world_tab: bool = false) -> void:
	game.quest_nav.refresh()
	game.hud.open_world_map(game.current_region, game.player.global_position, game.discovered_landmarks.get(game.current_region, {}), game.quests.get_active_summary())
	var live := game.minimap_markers()
	live.append_array(game.treasure.minimap_marker())
	live.append_array(game.epilogue.minimap_marker())
	live.append_array(game.deep_rifts.minimap_marker())
	live.append_array(game.quest_nav.minimap_markers())
	game.hud.world_map.set_live(live, game.player.facing)
	var destinations := game.travel_destinations()
	game.hud.world_map_view.set_destinations(game.current_region, destinations)
	var goal := game.quest_nav.main_region()
	game.hud.world_map_view.set_world(game.current_region, game.visited_regions, destinations, game.quest_nav.region_badges(), QuestNav.route(game.current_region, goal) if not goal.is_empty() else [])
	if world_tab:
		game.hud.world_map_view.show_world(true)

func _update_minimap() -> void:
	game._discover_landmarks()
	game.quest_nav.refresh()
	game._draw_minimap()

func _discover_landmarks() -> void:
	var region_markers: Dictionary = game.discovered_landmarks.get(game.current_region, {})
	for actor in game.get_children():
		var kind := game._landmark_kind(actor)
		if kind.is_empty():
			continue
		if game.player.global_position.distance_squared_to(actor.global_position) > SkywardGame.MINIMAP_DISCOVER * SkywardGame.MINIMAP_DISCOVER:
			continue
		var marker_id: String = "%s_%d_%d" % [kind, int(actor.global_position.x), int(actor.global_position.y)]
		if not region_markers.has(marker_id):
			region_markers[marker_id] = {"position": [actor.global_position.x, actor.global_position.y], "kind": kind}
	game.discovered_landmarks[game.current_region] = region_markers

func _draw_minimap() -> void:
	game.hud.minimap.update_map(game.current_region, game.player.global_position, game.discovered_landmarks.get(game.current_region, {}))
	var live := game.minimap_markers()
	live.append_array(game.treasure.minimap_marker())
	live.append_array(game.epilogue.minimap_marker())
	live.append_array(game.deep_rifts.minimap_marker())
	live.append_array(game.quest_nav.minimap_markers())
	game.hud.minimap.day_time = game.day_night.time if game.day_night.cycles_here() else -1.0
	game.hud.minimap.season_label = game.seasons.current_name().to_lower() if game.seasons != null and game.seasons.here() else ""
	game.hud.minimap.set_live(live, game.player.facing)
	if game.hud.world_map_visible:
		game.hud.world_map.set_live(live, game.player.facing)

## Kind of a saved landmark for a world object ("" if it is not one).
func _landmark_kind(actor: Node) -> String:
	if actor is WorldNpc:
		return "npc"
	if actor is RegionGate:
		return "gate"
	if actor is TreasureChest:
		return "chest"
	if actor is Waystone:
		return "waystone"
	if actor is CraftStation:
		return "station"
	if actor is GatherNode and actor.kind == "fish":
		return "fish"
	return ""

## Icons that reflect the present: quest givers, unopened chests, exits,
## quest items and enemies near the hero.
func minimap_markers() -> Array:
	var known: Dictionary = game.discovered_landmarks.get(game.current_region, {})
	var result: Array = []
	for actor in game.get_children():
		if not actor is Node2D or actor.is_queued_for_deletion():
			continue
		var at: Vector2 = actor.global_position
		var id := "%s_%d_%d" % [game._landmark_kind(actor), int(at.x), int(at.y)]
		if actor is RegionGate:
			result.append({"kind": "gate", "position": at, "label": RegionCatalog.display_name(actor.target_region)})
		elif actor is TowerObject and not actor.map_label.is_empty():
			result.append({"kind": "gate", "position": at, "label": actor.map_label})
		elif actor is WorldNpc and known.has(id):
			var marker := str(actor.marker)
			result.append({"kind": marker if marker in ["quest", "ready", "service"] else "npc", "position": at})
		elif actor is TreasureChest and known.has(id) and not actor.is_opened:
			result.append({"kind": "chest", "position": at})
		elif actor is WorldCollectible and not str(actor.quest_id).is_empty() and game.quests.is_active(str(actor.quest_id)):
			if game.player.global_position.distance_squared_to(at) < 400.0 * 400.0:
				result.append({"kind": "item", "position": at})
		elif actor is SlimeEnemy and actor.health > 0 and game.player.global_position.distance_squared_to(at) < 260.0 * 260.0:
			var kind := "enemy"
			if SkywardGame.enemy_kind(actor) in SkywardGame.STORY_BOSSES or actor.has_meta("cistern_keeper") or actor.has_meta("adit_guardian"):
				kind = "boss"
			elif actor.has_meta("legend"):
				kind = "boss"
			elif not actor.elite_id.is_empty() or actor is LootImp:
				kind = "elite"
			result.append({"kind": kind, "position": at})
	return result

func _discover_nearby_enemies() -> void:
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if not enemy is SlimeEnemy or enemy.is_queued_for_deletion() or enemy.has_meta("fair_target"):
			continue
		if game.player.global_position.distance_squared_to(enemy.global_position) > 180.0 * 180.0:
			continue
		var kind: String = SkywardGame.enemy_kind(enemy)
		if not game.discovered_enemies.has(kind):
			game.discovered_enemies[kind] = true
			game.hud.show_message("Новая запись в бестиарии: %s" % str(game.bestiary_entries.get(kind, {}).get("name", kind)), 2.5)
			game.hud.show_tip("bestiary", "Совет: K — бестиарий со слабостями врагов.")
