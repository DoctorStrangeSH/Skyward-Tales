extends Node
class_name NpcWander

## Lets a villager stroll between a few spots ("wander" in the region's npc
## entry), pausing at each, and greet the hero now and then.

var npc: WorldNpc
var points: Array = []
var game: SkywardGame
var _wait := 2.0
var _index := 0
var _greet_clock := 0.0
var rng := RandomNumberGenerator.new()

func setup(owner_game: SkywardGame, villager: WorldNpc, spots: Array) -> void:
	game = owner_game
	npc = villager
	points = spots
	rng.seed = hash(villager.npc_id)
	_wait = rng.randf_range(1.0, 4.0)

func _process(delta: float) -> void:
	if npc == null or not is_instance_valid(npc) or points.is_empty():
		return
	if game.hud.dialogue_visible or game.get_tree().paused:
		# Stand still while someone is talking.
		if npc.is_walking() and game.player.global_position.distance_to(npc.global_position) < 60.0:
			npc.stop_walking()
		return
	if npc.is_walking():
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = rng.randf_range(4.0, 9.0)
	_index = (_index + 1 + rng.randi_range(0, 1)) % points.size()
	var target: Vector2 = SkywardGame._vec(points[_index])
	npc.walk_path([target])
