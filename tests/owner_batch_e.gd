extends SceneTree

## Owner's list, package E: one window with tabs, the activities page, save
## slots, settings in the title menu, extended sound, quieter nature.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("OWNER BATCH E FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hud := game.hud

	# №28: one window, tabs on top; every window in the same frame.
	game._handle_key(KEY_J)
	await process_frame
	if not hud.journal_visible or not hud.menu_tabs.visible or not (hud.menu_tabs.buttons["journal"] as Button).button_pressed:
		return _fail("J opens the journal under the tab strip")
	(hud.menu_tabs.buttons["bestiary"] as Button).pressed.emit()
	await process_frame
	if hud.journal_visible or not hud.bestiary_visible:
		return _fail("a tab switches the window")
	game._handle_key(KEY_L)
	await process_frame
	if not hud.activities_visible or hud.bestiary_visible or hud.activities_view.grid.get_child_count() < 15:
		return _fail("L opens the activities page")
	game._handle_key(KEY_L)
	if hud.activities_visible or hud.menu_tabs.visible and game.input_handler.current_tab() != "":
		return _fail("the tab's key closes the window")
	await process_frame
	if hud.menu_tabs.visible:
		return _fail("no tabs without a window")
	game._handle_key(KEY_TAB)
	if not hud.activities_visible:
		return _fail("Tab opens the last tab")
	game._handle_key(KEY_M)
	await process_frame
	if not hud.world_map_visible or hud.activities_visible:
		return _fail("the map is a tab too")
	var j := InputEventKey.new()
	j.keycode = KEY_J
	j.pressed = true
	hud._unhandled_input(j)
	await process_frame
	if hud.world_map_visible or not hud.journal_visible or root.get_tree().paused:
		return _fail("J on the (pausing) map goes to the journal")
	for window in [hud.inventory_view, hud.journal_view, hud.world_map_view, hud.skills_view, hud.bestiary_view, hud.activities_view, hud.crafting_view]:
		if (window as Control).position != MenuTabs.FRAME.position:
			return _fail("every window sits in the common frame: " + str(window))
	game.input_handler.close_tabs()
	if hud.action_bar.menu_buttons.size() != 1:
		return _fail("one menu button on the bar")

	# №33: activities say what is open and how to open the rest.
	var rows := Activities.entries(game)
	var ids := rows.map(func(r: Dictionary) -> String: return str(r["id"]))
	for wanted in ["legends", "guild", "expeditions", "rifts", "ship", "fishing", "treasure", "lore", "achievements"]:
		if not ids.has(wanted):
			return _fail("activities list " + wanted)
	var rift: Dictionary = rows[ids.find("rifts")]
	if bool(rift["open"]) or not str(rift["how"]).contains("Тенью"):
		return _fail("a locked activity tells how to open it")

	# №35: three save slots; slot 1 is the old file.
	if SaveSystem.slot_path(1) != SaveSystem.SAVE_PATH or SaveSystem.slot_path(3) == SaveSystem.SAVE_PATH:
		return _fail("slot paths")
	SaveSystem.delete_slot(3)
	game.save_path = SaveSystem.slot_path(3)
	game.player.level = 7
	game.save_game()
	var summary := SaveSystem.slot_summary(3)
	if summary.is_empty() or int(summary["level"]) != 7 or str(summary["region"]) != game.current_region:
		return _fail("a slot shows hero, level and land: " + str(summary))
	if SaveSystem.latest_slot() != 3:
		return _fail("the newest slot is the one to continue")
	SaveSystem.delete_slot(3)
	if not SaveSystem.slot_summary(3).is_empty():
		return _fail("a slot can be deleted")

	# №5, 36: settings — also in the title menu; extended sound.
	var title: TitleMenu = load("res://scenes/title_menu.tscn").instantiate()
	root.add_child(title)
	await process_frame
	title._show_settings()
	var panel: SettingsPanel = null
	for node in title.settings_frame.find_children("*", "SettingsPanel", true, false):
		panel = node
	if panel == null or not title.settings_frame.visible:
		return _fail("the title menu has settings")
	for key in ["master_volume", "music_volume", "sfx_volume", "ui_volume", "ambience_volume", "nature_volume"]:
		if not panel.sliders.has(key):
			return _fail("sound slider " + key)
	title._back_to_menu()
	title._show_slots("new")
	if title.slots_box.get_child_count() < 5:
		return _fail("new game picks a slot")
	title.queue_free()
	GameAudio.apply_volumes()
	await process_frame
	if AudioServer.get_bus_index("Nature") == -1 or AudioServer.get_bus_index("UI") == -1:
		return _fail("nature and interface have their own buses")
	if GameSettings.DEFAULTS["nature_volume"] > 0.4:
		return _fail("birds and crickets are quieter by default")

	print("OWNER BATCH E OK")
	quit(0)
