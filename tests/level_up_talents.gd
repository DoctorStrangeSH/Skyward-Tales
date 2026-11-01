extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, message: String) -> bool:
	if not ok:
		push_error("LEVEL UP TEST FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save_path = "user://level_up_talents_test.json"
	game.player.experience = game.player.experience_to_next - 1
	game.player.add_experience(1)
	if not _require(game.player.level == 2, "hero did not level up"):
		return
	if not _require(game.hud.talent_visible and paused, "level-up choice did not pause the world"):
		return
	if not _require(game.hud.talent_list.get_child_count() == 3, "expected three talent choices"):
		return
	var chosen_id: String = ""
	var first_entry: VBoxContainer = game.hud.talent_list.get_child(0) as VBoxContainer
	var first_button: Button = first_entry.get_child(0) as Button
	var displayed_name: String = first_button.text.split("   РАНГ")[0]
	for id in game.talent_definitions:
		if str(game.talent_definitions[id].get("name", "")) == displayed_name:
			chosen_id = str(id)
			break
	if not _require(not chosen_id.is_empty(), "could not identify first displayed talent"):
		return
	game._on_talent_selected(chosen_id)
	if not _require(not game.hud.talent_visible and not paused, "choosing a talent did not resume gameplay"):
		return
	if not _require(int(game.player.talents.get(chosen_id, 0)) == 1, "chosen talent rank was not recorded"):
		return
	if chosen_id == "vitality" and not _require(game.player.max_health == 115, "vitality did not increase max health"):
		return
	if chosen_id == "mana_well" and not _require(game.player.max_mana == 72, "mana well did not increase max mana"):
		return
	if chosen_id == "swift_cast" and not _require(game.player.get_cooldown_multiplier() < 1.0, "swift cast did not reduce cooldown"):
		return
	if chosen_id == "arcane_power" and not _require(game.player.get_spell_bonus() == 3, "arcane power did not increase spell damage"):
		return
	if chosen_id == "frost_lore" and not _require(game.player.get_spell_bonus("frostbolt") == 3, "frost lore did not increase frost damage"):
		return
	if chosen_id == "storm_focus" and not _require(game.player.get_spell_bonus("chain_lightning") == 3, "storm focus did not increase lightning damage"):
		return
	if not _require(game.save_game(), "could not save talent progress"):
		return
	game.player.talents.clear()
	if not _require(game.load_game(), "could not reload talent progress"):
		return
	if not _require(int(game.player.talents.get(chosen_id, 0)) == 1, "talent rank did not persist in save"):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	print("LEVEL UP TEST OK: three choices, talent effects, pause/resume and save/load")
	paused = false
	quit(0)
