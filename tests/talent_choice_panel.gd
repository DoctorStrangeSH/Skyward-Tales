extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("TALENT PANEL FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hud: GameHud = game.hud
	if not _require(hud.talent_panel is TalentChoicePanel and hud.talent_list == hud.talent_view.choice_list, "compatibility aliases missing"):
		return
	var choices: Array[Dictionary] = [
		{"id": "vitality", "name": "Живучесть", "rank": 1, "description": "Больше здоровья."},
		{"id": "swift_cast", "name": "Быстрые чары", "rank": 0, "description": "Меньше откат."}
	]
	var selections: Array[String] = []
	hud.talent_selected.connect(func(id: String) -> void: selections.append(id))
	hud.show_talent_choices(choices)
	if not _require(hud.talent_visible and hud.talent_panel.visible and hud.talent_list.get_child_count() == 2, "choice list not rendered"):
		return
	var first_entry: VBoxContainer = hud.talent_list.get_child(0) as VBoxContainer
	var first_button: Button = first_entry.get_child(0) as Button
	if not _require(first_button.text.contains("РАНГ 1 → 2") and first_button.tooltip_text == "Больше здоровья.", "rank or tooltip broken"):
		return
	first_button.pressed.emit()
	if not _require(selections == ["vitality"], "talent selection did not reach HUD"):
		return
	hud.hide_talent_choices()
	if not _require(not hud.talent_visible and not hud.talent_panel.visible, "choices did not close"):
		return
	print("TALENT PANEL OK: choices, signals, HUD aliases and visibility")
	quit(0)
