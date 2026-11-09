extends SceneTree

class Target extends Node2D:
	var hits: int = 0

	func take_damage(_amount: int, _source: Node) -> void:
		hits += 1

class Encounter extends Node2D:
	signal finished(passed: bool)

	var fox: Windtail
	var target: Target
	var scenario: String
	var ticks: int = 0
	var saw_lunge: bool = false

	func _physics_process(delta: float) -> void:
		fox._physics_process(delta)
		ticks += 1
		if ticks == 1:
			if fox.attack_state != SlimeEnemy.AttackState.WINDUP or fox.dash_visual.visible \
					or fox.visual.direction_index != 2 or fox.combat_feedback.telegraph_direction != Vector2.RIGHT \
					or target.hits != 0:
				_finish(false, "windup must face and warn without showing the dash or dealing damage")
				return
			if scenario == "dodge":
				target.position += Vector2(0, 56)
		if not saw_lunge and fox.attack_state == SlimeEnemy.AttackState.LUNGE:
			saw_lunge = true
			if not fox.dash_visual.visible or not fox.dash_visual.is_playing() \
					or not is_zero_approx(fox.dash_visual.rotation) \
					or fox.attack_direction != Vector2.RIGHT:
				_finish(false, "lunge must keep its direction and start the matching effect")
				return
		if ticks == 92:
			var expected_hits := 1 if scenario == "hit" else 0
			_finish(saw_lunge and fox.attack_state == SlimeEnemy.AttackState.NONE \
				and fox.attack_cooldown > 0.0 and target.hits == expected_hits \
				and not fox.dash_visual.visible, "wrong damage, cooldown or effect lifetime: " + scenario)

	func _finish(passed: bool, reason: String) -> void:
		set_physics_process(false)
		if not passed:
			push_error("WINDTAIL TEST FAILED: " + reason)
		finished.emit(passed)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as SkywardGame
	root.add_child(game)
	game.autosave_enabled = false
	game._set_region("sky_island", Vector2(640, 760), false)
	var foxes := []
	for actor in get_nodes_in_group("enemies"):
		if actor is Windtail:
			foxes.append(actor)
	if foxes.size() != 1 or SkywardGame.enemy_kind(foxes[0]) != "windtail" \
			or not game.bestiary_entries.has("windtail"):
		push_error("WINDTAIL TEST FAILED: missing island encounter or bestiary entry")
		quit(1)
		return
	var fox: Windtail = foxes[0]
	if fox.visual.texture.get_size() != Vector2(192, 384) or fox.visual.hframes != 4 \
			or fox.visual.vframes != 8 or fox.visual.offset != Vector2(0, -18):
		push_error("WINDTAIL TEST FAILED: wrong run atlas or anchor")
		quit(1)
		return
	game.queue_free()
	await process_frame
	paused = false
	for scenario in ["hit", "dodge", "wall"]:
		var encounter := Encounter.new()
		encounter.scenario = scenario
		encounter.set_physics_process(false)
		root.add_child(encounter)
		encounter.fox = Windtail.new()
		encounter.fox.position = Vector2(100, 100)
		encounter.add_child(encounter.fox)
		encounter.fox.set_physics_process(false)
		encounter.target = Target.new()
		encounter.target.add_to_group("player")
		encounter.target.position = Vector2(164, 100)
		encounter.add_child(encounter.target)
		encounter.target.set_physics_process(true)
		if scenario == "wall":
			var wall := StaticBody2D.new()
			wall.collision_layer = 4
			wall.position = Vector2(157, 100)
			var collider := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(6, 64)
			collider.shape = rectangle
			wall.add_child(collider)
			encounter.add_child(wall)
		await physics_frame
		encounter.set_physics_process(true)
		var passed: bool = await encounter.finished
		encounter.queue_free()
		await process_frame
		if not passed:
			quit(1)
			return
	print("WINDTAIL OK: island spawn, atlas, bestiary, telegraph, VFX, one hit, dodge, wall and cooldown")
	quit(0)
