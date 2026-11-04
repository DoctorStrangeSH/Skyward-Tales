extends SceneTree

## Sound and music: every generated stream loads, region styles pick their
## track, bosses switch to battle music and back, volume settings reach buses.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("AUDIO TEST FAILED: " + reason)
	quit(1)

func _run() -> void:
	for sound in ["hit", "enemy_die", "hurt", "cast_fire", "cast_ice", "cast_lightning", "dash", "pickup", "chest", "level_up", "quest", "travel", "boss_roar", "gust", "ui"]:
		if not load(GameAudio.SFX_DIR + sound + ".wav") is AudioStreamWAV:
			return _fail("missing sound " + sound)
	for track in ["meadow", "night", "caves", "sky", "boss"]:
		if not load(GameAudio.MUSIC_DIR + track + ".ogg") is AudioStreamOggVorbis:
			return _fail("missing track " + track)
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.autosave_enabled = false
	var audio := GameAudio.instance()
	if audio.current_track != "meadow":
		return _fail("village plays the meadow theme, got " + audio.current_track)
	game._set_region("crystal_caves", Vector2(640, 600), false)
	await process_frame
	if audio.current_track != "caves":
		return _fail("caves have their own music")
	game._set_region("wind_spires", Vector2(560, 560), false)
	await process_frame
	if audio.current_track != "sky":
		return _fail("islands play the sky theme")
	var boss := game.spawn_enemy("tempest", Vector2(760, 300))
	await process_frame
	if audio.current_track != "boss":
		return _fail("a boss switches to battle music")
	boss.take_damage(9999)
	await process_frame
	await process_frame
	if audio.current_track != "sky":
		return _fail("music returns after the boss falls")
	GameAudio.play("hit")
	GameAudio.play("hit")
	game.hit_stop(0.1)
	if Engine.time_scale != 1.0:
		return _fail("hit-stop is skipped headless")
	GameSettings.set_float("music_volume", 0.0)
	GameAudio.apply_volumes()
	if not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")):
		return _fail("music volume 0 mutes the bus")
	GameSettings.set_float("music_volume", 0.6)
	GameAudio.apply_volumes()
	print("AUDIO OK: 15 sounds, 5 tracks, region music, boss music, volumes")
	quit(0)
