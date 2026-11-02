extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("BESTIARY PANEL FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hud: GameHud = game.hud
	if not _check(hud.bestiary_panel is BestiaryPanel and hud.bestiary_list == hud.bestiary_view.entry_list, "panel or list alias missing"):
		return
	var entries: Dictionary = {"slime": {"name": "Слизень", "habitat": "Лес", "attack": "Удар", "weakness": "Огонь", "resistance": "Лёд"}}
	hud.toggle_bestiary(entries, {})
	if not _check(hud.bestiary_visible and hud.bestiary_list.get_child_count() == 1, "hidden enemy should show one entry"):
		return
	var unknown: Label = hud.bestiary_list.get_child(0) as Label
	if not _check(unknown != null and unknown.text.contains("Не обнаружен"), "undiscovered name leaked"):
		return
	hud.toggle_bestiary(entries, {})
	hud.toggle_bestiary(entries, {"slime": true})
	if not _check(hud.bestiary_list.get_child_count() == 2, "discovered enemy must show details"):
		return
	var info: Label = hud.bestiary_list.get_child(1) as Label
	if not _check(info != null and info.text.contains("Слабость: Огонь"), "details missing"):
		return
	print("BESTIARY PANEL OK: hidden/discovered content and HUD aliases")
	quit(0)
