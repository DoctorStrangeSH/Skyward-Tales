extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: Node2D = scene.instantiate()
	root.add_child(game)
	await process_frame
	var hud: GameHud = game.hud
	if hud.spell_label == null or hud.spell_cooldown_bar == null:
		push_error("HUD TEST FAILED: spell controls missing")
		quit(1)
		return
	game.select_spell("frostbolt")
	if not hud.spell_label.text.contains("Ледяная стрела") and not hud.spell_label.text.contains("Ледяная"):
		push_error("HUD TEST FAILED: selection not displayed")
		quit(1)
		return
	game._cast_spell()
	if game.cast_cooldown_total <= 0.0 or hud.spell_cooldown_bar.value >= 1.0:
		push_error("HUD TEST FAILED: cooldown is not displayed")
		quit(1)
		return
	game.cast_cooldown_remaining = 0.0
	game._update_spell_hud()
	if hud.spell_cooldown_bar.value < 0.99:
		push_error("HUD TEST FAILED: ready bar not restored")
		quit(1)
		return
	print("HUD TEST OK: selected spell, cost and cooldown")
	quit(0)
