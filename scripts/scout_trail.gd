extends Node
class_name ScoutTrail

## Stage 21, step 7: Alaya the scout (the red hood from the owner's pack)
## stands north of the village and keeps a trail: a run through five flags
## against the clock. The route changes every day (three routes in turn).
## In time — gold and experience; faster than the gold time — double pay and
## a record. Running, dodging and sprinting are the whole trick.

const HOME := "greenreach"
const NPC := "scout"
const REACH := 20.0
const ROUTES := [
	{"name": "Вокруг деревни", "flags": [[460, 480], [810, 580], [770, 640], [600, 866], [400, 640]]},
	{"name": "К мельнице и обратно", "flags": [[460, 480], [300, 400], [250, 380], [440, 340], [500, 410]]},
	{"name": "К вратам башни", "flags": [[820, 450], [930, 400], [1048, 490], [1010, 660], [780, 620]]},
]

## A flag of the trail.
class Flag extends Node2D:
	var state: String = "wait"  # "next", "wait", "done"
	var _clock: float = 0.0

	func _ready() -> void:
		add_to_group("region_actor")

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		var color := Color(1.0, 0.82, 0.3) if state == "next" else (Color(0.5, 0.9, 0.5) if state == "done" else Color(0.85, 0.3, 0.25))
		if state == "next":
			var pulse := 0.5 + 0.5 * sin(_clock * 5.0)
			draw_arc(Vector2.ZERO, 12.0 + pulse * 4.0, 0.0, TAU, 28, Color(color, 0.7), 1.5)
			draw_circle(Vector2.ZERO, 9.0, Color(color, 0.16))
		draw_line(Vector2(0, 2), Vector2(0, -24), Color(0.36, 0.24, 0.14), 2.0)
		var wave := sin(_clock * 4.0) * 1.5
		draw_colored_polygon(PackedVector2Array([Vector2(1, -24), Vector2(13, -20 + wave), Vector2(1, -15)]), color)
		draw_polyline(PackedVector2Array([Vector2(1, -24), Vector2(13, -20 + wave), Vector2(1, -15)]), color.darkened(0.35), 1.0)

var game: SkywardGame
var running: bool = false
var route_index: int = 0
var next_flag: int = 0
var time: float = 0.0
## Best time per route index (as strings — JSON keys).
var best: Dictionary = {}
var runs_won: int = 0
var _flags: Array = []
var _label: Label

func route_today() -> int:
	return maxi(game.day_night.day, 0) % ROUTES.size()

func points(index: int) -> Array:
	var result: Array = []
	for p in ROUTES[index]["flags"]:
		result.append(Vector2(float(p[0]), float(p[1])))
	return result

func length(index: int) -> float:
	var total := 0.0
	var at := start_point()
	for p in points(index):
		total += at.distance_to(p)
		at = p
	return total

func start_point() -> Vector2:
	for node in game.get_children():
		if node is WorldNpc and node.npc_id == NPC:
			return node.global_position
	return Vector2(640, 510)

func time_limit(index: int) -> float:
	return length(index) / 75.0 + 5.0

func gold_time(index: int) -> float:
	return length(index) / 108.0

func marker(npc_id: String) -> String:
	return "service" if npc_id == NPC and not running else ""

func talk(npc_id: String) -> bool:
	if npc_id != NPC:
		return false
	var index := route_today()
	var record := float(best.get(str(index), 0.0))
	var text := "Алая поправляет красный капюшон.\n— Ноги кормят разведчика. Пять флажков, по порядку, на время. Сегодня тропа «%s»: уложись в %d с. Быстрее %d с — плачу вдвое." % [str(ROUTES[index]["name"]), int(time_limit(index)), int(gold_time(index))]
	if record > 0.0:
		text += "\nТвой рекорд на этой тропе: %.1f с." % record
	var choices: Array[Dictionary] = [{"id": "scout_run", "label": "Побежали!"}, {"id": "scout_close", "label": "В другой раз"}]
	game._show_dialogue_choices("Алая, разведчица", text, choices)
	return true

func handle_choice(choice_id: String) -> bool:
	if not choice_id.begins_with("scout_"):
		return false
	game.dialogues._close()
	if choice_id == "scout_run":
		start()
	return true

func start() -> void:
	if running or game.current_region != HOME:
		return
	_clear()
	running = true
	route_index = route_today()
	next_flag = 0
	time = 0.0
	var spots := points(route_index)
	for i in spots.size():
		var flag := Flag.new()
		flag.state = "next" if i == 0 else "wait"
		game.add_child(flag)
		flag.global_position = spots[i]
		_flags.append(flag)
	if _label == null:
		_label = Label.new()
		_label.position = Vector2(220, 44)
		_label.size = Vector2(200, 14)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_override("font", UiFont.font())
		_label.add_theme_font_size_override("font_size", UiFont.px(10))
		_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
		_label.add_theme_constant_override("outline_size", 4)
		game.hud.add_child(_label)
	_label.visible = true
	GameAudio.play("quest", -6.0, 0.2)
	game.hud.show_title_card("Тропа: %s" % str(ROUTES[route_index]["name"]), 1.6)

func _clear() -> void:
	for flag in _flags:
		if is_instance_valid(flag):
			flag.queue_free()
	_flags.clear()
	if _label != null:
		_label.visible = false

func _process(delta: float) -> void:
	if not running:
		return
	if game.current_region != HOME:
		_finish(false)
		return
	time += delta
	var limit := time_limit(route_index)
	_label.text = "Флажок %d/%d · %.1f / %d с" % [next_flag + 1, _flags.size(), time, int(limit)]
	if time > limit:
		_finish(false)
		return
	var flag: Flag = _flags[next_flag]
	if game.player.global_position.distance_to(flag.global_position) <= REACH:
		reach_flag()

## The hero touched the next flag.
func reach_flag() -> void:
	if not running:
		return
	var flag: Flag = _flags[next_flag]
	flag.state = "done"
	Vfx.sparkle(game, flag.global_position + Vector2(0, -14))
	GameAudio.play("pickup", -4.0, 0.1 * next_flag)
	next_flag += 1
	if next_flag >= _flags.size():
		_finish(true)
	else:
		(_flags[next_flag] as Flag).state = "next"

func _finish(won: bool) -> void:
	running = false
	_clear()
	if not won:
		GameAudio.play("ui_tick", -4.0, -0.3)
		game.hud.show_message("Алая качает головой: «Не успел. Приходи ещё — тропа никуда не денется».", 4.0)
		return
	runs_won += 1
	var key := str(route_index)
	var old := float(best.get(key, 0.0))
	var record := old <= 0.0 or time < old
	if record:
		best[key] = snappedf(time, 0.1)
	var fast := time <= gold_time(route_index)
	var gold := (30 + 3 * game.player.level) * (2 if fast else 1)
	game.player.add_gold(gold)
	game.player.add_experience((20 + 6 * game.player.level) * (2 if fast else 1))
	game.achievements.set_max("scout_runs", runs_won)
	GameAudio.play("quest", -2.0, 0.0)
	var text := "Тропа пройдена за %.1f с! +%d золота." % [time, gold]
	if fast:
		text += " Золотое время — плата вдвое!"
	if record and old > 0.0:
		text += " Новый рекорд!"
	game.hud.show_message(text, 5.0)
	game.request_autosave()

func make_snapshot() -> Dictionary:
	return {"best": best.duplicate(), "runs_won": runs_won}

func restore_snapshot(value: Variant) -> void:
	var data: Dictionary = value if value is Dictionary else {}
	best = (data.get("best", {}) as Dictionary).duplicate()
	runs_won = int(data.get("runs_won", 0))
	running = false
	_flags.clear()
	if _label != null:
		_label.visible = false
