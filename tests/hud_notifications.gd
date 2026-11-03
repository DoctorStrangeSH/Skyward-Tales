extends SceneTree

## Toasts never overlap or duplicate, one-time tips respect settings,
## the pause menu has controls/settings pages, no permanent key hint.

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("HUD NOTIFICATIONS TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	GameSettings.reload()
	GameSettings.set_bool("hints", true)
	GameSettings.reset_tips()
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var hud := game.hud
	hud.toasts.clear()

	for i in range(5):
		hud.show_message("Сообщение %d" % i, 2.0)
	if not _verify(hud.toasts.visible_texts().size() == 3, "at most three toasts at once"):
		return
	if not _verify(hud.toasts.visible_texts()[2] == "Сообщение 4" and hud.message_label.text == "Сообщение 4", "newest message is kept and mirrored to message_label"):
		return
	hud.show_message("Сообщение 4", 2.0)
	if not _verify(hud.toasts.visible_texts().size() == 3, "identical message refreshes instead of stacking"):
		return

	hud.toasts.clear()
	hud.show_tip("test_tip", "Совет: проверка")
	hud.show_tip("test_tip", "Совет: проверка")
	if not _verify(hud.toasts.visible_texts().count("Совет: проверка") == 1, "tip shows once"):
		return
	hud.toasts.clear()
	hud.show_tip("test_tip", "Совет: проверка")
	if not _verify(hud.toasts.visible_texts().is_empty(), "seen tip never returns"):
		return
	GameSettings.set_bool("hints", false)
	hud.show_tip("another_tip", "Совет: другой")
	if not _verify(hud.toasts.visible_texts().is_empty(), "tips can be switched off"):
		return
	GameSettings.set_bool("hints", true)

	# Toasts fade away on their own.
	hud.toasts.clear()
	hud.show_message("Исчезну", 0.1)
	for _i in range(20):
		await process_frame
	if not _verify(hud.toasts.visible_texts().is_empty(), "toasts expire"):
		return

	# No permanent key hint when nothing is nearby.
	game.player.global_position = Vector2(700, 700)
	for _i in range(3):
		await process_frame
	if not _verify(hud.prompt_label.text.is_empty(), "no idle controls hint"):
		return

	# Pause menu pages.
	hud._set_paused(true)
	var pause := hud.pause_view
	if not _verify(pause.main_page.visible and not pause.controls_page.visible, "pause opens on the main page"):
		return
	pause.show_page(pause.controls_page)
	if not _verify(pause.controls_page.visible and not pause.main_page.visible, "controls page opens"):
		return
	pause.damage_toggle.button_pressed = false
	if not _verify(not GameSettings.damage_numbers_enabled(), "damage number toggle is saved"):
		return
	GameSettings.reload()
	if not _verify(not GameSettings.damage_numbers_enabled(), "settings persist on disk"):
		return
	GameSettings.set_bool("damage_numbers", true)
	hud._set_paused(false)
	hud._set_paused(true)
	if not _verify(pause.main_page.visible, "reopening pause returns to the main page"):
		return
	hud._set_paused(false)
	print("HUD NOTIFICATIONS OK: toast stack, tips, settings, pause pages")
	quit(0)
