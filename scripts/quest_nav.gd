extends RefCounted
class_name QuestNav

## Where to go: every quest target in the world, gathered from region data
## and live quest state.
## A target: {"region", "position": Vector2 or null (anywhere in the land),
##   "kind": "main" | "side" | "offer" | "turnin", "title"}.
## Also routes between lands over the gates (for the "next gate" marker and
## the path on the world map).

const COLLECT_QUESTS := {"bran_supply_run": "supply_crates", "lost_cartographer_notes": "map_fragments"}

var game: SkywardGame
var targets: Array = []

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

func refresh() -> void:
	targets = _collect()

func _add(result: Array, region_id: String, position: Variant, kind: String, title: String) -> void:
	result.append({"region": region_id, "position": position, "kind": kind, "title": title})

func _collect() -> Array:
	var result: Array = []
	var quests := game.quests
	# Quest givers and turn-ins, in every land.
	for region_id in RegionCatalog.ids():
		for npc in RegionCatalog.get_region(region_id).get("npcs", []):
			var npc_id := str(npc.get("id", ""))
			if npc_id == "cartographer" and game.companion != null:
				continue
			if str(npc.get("requires_flag", "")) == "ending" and game.epilogue.ending().is_empty():
				continue
			var marker := game.dialogues.marker_for(npc_id)
			var at: Vector2 = SkywardGame._vec(npc.get("position"))
			if region_id == game.current_region:
				at = _live_npc(npc_id, at)
			if marker == "ready":
				_add(result, region_id, at, "turnin", str(npc.get("name", "")))
			elif marker == "quest":
				_add(result, region_id, at, "offer", str(npc.get("name", "")))
	# A lost mine is a job for anyone passing by.
	if game.mine.overrun() and not quests.is_active(BorinStory.DREAM) and game.visited_regions.has(PassMine.REGION):
		_add(result, PassMine.REGION, PassMine.ENTRANCE + Vector2(0, 50), "side", "Шахта захвачена")
	for quest_id in quests.definitions:
		if not quests.is_active(quest_id) or quests.is_ready_to_complete(quest_id):
			continue
		var definition: Dictionary = quests.definitions[quest_id]
		var kind := "main" if bool(definition.get("main", false)) else "side"
		var title := str(definition.get("title", quest_id))
		var found := _objectives(quest_id, definition)
		for entry in found:
			_add(result, str(entry[0]), entry[1], kind, title)
	return result

## [region, position-or-null] pairs for one open quest.
func _objectives(quest_id: String, definition: Dictionary) -> Array:
	var found: Array = []
	for region_id in RegionCatalog.ids():
		var layout := RegionCatalog.get_region(region_id)
		var here: bool = region_id == game.current_region
		for item in layout.get("story_objects", []):
			if not game.layout_allows(item):
				continue
			if str(item.get("quest", "")) == quest_id and (not here or _live_collectible(str(item.get("id", "")))):
				found.append([region_id, SkywardGame._vec(item.get("position"))])
		var herb_quest := RegionCatalog.herb_quest(region_id)
		for herb in layout.get("herbs", []):
			var own := str(herb.get("quest", ""))
			if (own if not own.is_empty() else herb_quest) != quest_id:
				continue
			var at := SkywardGame._vec(herb.get("position"))
			if not here or _live_collectible_at(at):
				found.append([region_id, at])
		for enemy in layout.get("enemies", []):
			if str(enemy.get("quest", "")) == quest_id:
				found.append([region_id, SkywardGame._vec(enemy.get("position"))])
		if COLLECT_QUESTS.has(quest_id):
			for at in layout.get(COLLECT_QUESTS[quest_id], []):
				var point := SkywardGame._vec(at)
				if not here or _live_collectible_at(point):
					found.append([region_id, point])
	# Bosses and hunts.
	var kill := str(definition.get("kill_kind", ""))
	for boss_kind in game.director.bosses:
		if str(game.director.bosses[boss_kind].get("completes", "")) == quest_id:
			kill = str(boss_kind)
	if quest_id == "main_guardian":
		kill = "guardian"
	if not kill.is_empty() and found.is_empty():
		for region_id in RegionCatalog.ids():
			var layout := RegionCatalog.get_region(region_id)
			var boss: Dictionary = layout.get("boss", {})
			var spots: Array = []
			if str(boss.get("kind", "")) == kill:
				spots.append(SkywardGame._vec(boss.get("position")))
			for enemy in layout.get("enemies", []):
				if str(enemy.get("kind", "")) == kill:
					spots.append(SkywardGame._vec(enemy.get("position")))
			if spots.is_empty():
				continue
			# A unique foe gets a pin; a common one marks the whole land.
			if spots.size() <= 1 or kill in SkywardGame.STORY_BOSSES:
				for spot in spots:
					found.append([region_id, spot])
			else:
				found.append([region_id, null])
	# Arrival quests: the land itself is the goal.
	for trigger in game.director.on_enter:
		if str(trigger.get("completes", "")) == quest_id:
			found.append([str(trigger.get("region", "")), null])
	if quest_id == BorinStory.DREAM and game.mine.overrun():
		found.append([PassMine.REGION, PassMine.ENTRANCE + Vector2(0, 50)])
	if quest_id == Epilogue.RIFT_QUEST:
		for region_id in game.epilogue.open_rift_regions():
			var pos: Array = game.epilogue.rifts[region_id]
			found.append([str(region_id), Vector2(float(pos[0]), float(pos[1]))])
	return found

## Villagers walk around: use where they are now.
func _live_npc(npc_id: String, fallback: Vector2) -> Vector2:
	for node in game.get_children():
		if node is WorldNpc and node.npc_id == npc_id and not node.is_queued_for_deletion():
			return node.global_position
	return fallback

func _live_collectible(item_id: String) -> bool:
	for node in game.get_children():
		if node is WorldCollectible and node.item_id == item_id and not node.is_queued_for_deletion():
			return true
	return false

func _live_collectible_at(at: Vector2) -> bool:
	for node in game.get_children():
		if node is WorldCollectible and not node.is_queued_for_deletion() and node.global_position.distance_squared_to(at) < 4.0:
			return true
	return false

# --- Routing ------------------------------------------------------------------

## Lands from `from` to `to` over the gates (both ends included), or [].
static func route(from: String, to: String) -> Array:
	if from == to:
		return [from]
	var previous := {from: ""}
	var queue: Array = [from]
	while not queue.is_empty():
		var region_id: String = queue.pop_front()
		for gate in RegionCatalog.get_region(region_id).get("gates", []):
			var next := str(gate.get("target", ""))
			if next.is_empty() or previous.has(next) or not RegionCatalog.has(next):
				continue
			previous[next] = region_id
			if next == to:
				var path: Array = [to]
				var step := region_id
				while not step.is_empty():
					path.push_front(step)
					step = str(previous[step])
				return path
			queue.append(next)
	return []

## The main goal's land: the nearest land holding a main target.
func main_region() -> String:
	var best := ""
	var best_length := 999
	for target in targets:
		if target["kind"] != "main":
			continue
		var length := route(game.current_region, str(target["region"])).size()
		if length > 0 and length < best_length:
			best_length = length
			best = str(target["region"])
	return best

## Markers for the current land: targets here, and the gate towards the main
## goal when it lies elsewhere.
func minimap_markers() -> Array:
	var result: Array = []
	for target in targets:
		if str(target["region"]) != game.current_region or target["position"] == null:
			continue
		if target["kind"] in ["main", "side"]:
			result.append({"kind": "goal_" + str(target["kind"]), "position": target["position"]})
		else:
			result.append({"kind": "quest" if target["kind"] == "offer" else "ready", "position": target["position"]})
	var goal := main_region()
	if not goal.is_empty() and goal != game.current_region:
		var path := route(game.current_region, goal)
		if path.size() >= 2:
			var gate := RegionCatalog.gate(game.current_region, str(path[1]))
			if not gate.is_empty():
				result.append({"kind": "goal_gate", "position": SkywardGame._vec(gate.get("position")), "label": RegionCatalog.display_name(str(path[1]))})
	return result

## Per land: {"main": bool, "side": bool, "offer": bool, "turnin": bool}.
func region_badges() -> Dictionary:
	var result := {}
	for target in targets:
		var region_id := str(target["region"])
		if not result.has(region_id):
			result[region_id] = {}
		result[region_id][str(target["kind"])] = true
	return result
