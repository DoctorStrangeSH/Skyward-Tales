extends SceneTree

## The smoke run of CI: the game starts from its main scene (the title
## screen), lives for 120 frames and quits cleanly. Audio is released a few
## frames before quitting — the mixer frees a stopped stream asynchronously,
## and quitting in the same frame reports it as a leak.
##   godot --headless --path . --script res://tools/smoke_run.gd
## CI fails this step on any "SCRIPT ERROR", leaked object or resource.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load(str(ProjectSettings.get_setting("application/run/main_scene")))
	var main := scene.instantiate()
	root.add_child(main)
	for i in 120:
		await process_frame
	main.queue_free()
	var audio := GameAudio.instance()
	if audio != null:
		audio._release()
		audio.queue_free()
	for i in 12:
		await process_frame
	print("SMOKE RUN OK")
	quit(0)
