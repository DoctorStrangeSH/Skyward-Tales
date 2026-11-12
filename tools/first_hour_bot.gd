extends SceneTree

## Этап 22, «первые 30–60 минут как эталон качества»: a bot plays the start
## of a new game with real walking (navigation path + move keys, real
## collisions), real fights (sword swings at the nearest foe) and real
## conversations (reading time counts), and writes down what a new player
## meets: when each quest starts and ends, where the bot got stuck, deaths,
## long walks, moments with nothing to do, and every message on screen.
##
##   godot --headless --path . --script res://tools/first_hour_bot.gd -- [minutes] [report.md]
##
## The bot follows the same signs a player sees: map pins and the gate
## marker (QuestNav), "!" over villagers, "?" for turn-ins. Choices: the
## first one that is not "later / leave".

const STEP := 1.0 / 60.0
const READ_CHARS_PER_SEC := 22.0
const REACH := 20.0
const STUCK_TIME := 6.0
const FIGHT_RANGE := 70.0

var game: SkywardGame
var hero: PlayerCharacter
var clock: float = 0.0
var limit: float = 3600.0
var report_path := "user://first_hour.md"
var log_lines: Array[String] = []
var events: Array[Dictionary] = []
var _wait: float = 0.0
var _path: PackedVector2Array = PackedVector2Array()
var _path_goal := Vector2.INF
var _path_region := ""
var _goal_text := ""
var _last_goal_text := ""
var _goal_since: float = 0.0
var _stuck_clock: float = 0.0
var _last_pos := Vector2.ZERO
var _stuck_points: Array = []
var _unreachable: Dictionary = {}
var _last_message := ""
var _idle_time: float = 0.0
var _walk_time: float = 0.0
var _fight_time: float = 0.0
var _read_time: float = 0.0
var _deaths: int = 0
var _region_time: Dictionary = {}
var _talked: Dictionary = {}
var _quest_started: Dictionary = {}
var _last_interact: float = -10.0
var _ignored_targets: Dictionary = {}
var _read_text := ""
var _snapshot: Dictionary = {}
var _gear_clock: float = 0.0
var _skill_clock: float = 0.0
var _avoid: Dictionary = {}
var _empty_land: float = 0.0
var _wander := Vector2.INF
var _step_in := Vector2.INF
var _detour := Vector2.ZERO
var _detour_left: float = 0.0
var _progress_goal := Vector2.INF
var _best_near: float = INF
var _step_clock: float = 0.0
var _deaths_at: Dictionary = {}
var _last_goal_key := ""
var _snag_clock: float = 0.0
var _side_left: float = 0.0
var _side_sign: float = 1.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		limit = float(args[0]) * 60.0
	if args.size() > 1:
		report_path = str(args[1])
	call_deferred("_run")

func _note(kind: String, text: String) -> void:
	var stamp := "%02d:%02d" % [int(clock) / 60, int(clock) % 60]
	events.append({"time": clock, "kind": kind, "text": text})
	log_lines.append("%s  %-8s %s" % [stamp, kind, text])
	print("%s  %-8s %s" % [stamp, kind, text])

func _run() -> void:
	set_meta("skyward_new_hero", {"name": "Арина", "gender": "f"})
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# The game's own autosaves (HOME is a fresh temp folder for the bot).
	game.autosave_enabled = true
	hero = game.player
	game.quests.quest_started.connect(func(id: String) -> void:
		_quest_started[id] = clock
		_note("quest+", "%s «%s»" % [id, str(game.quests.definitions.get(id, {}).get("title", id))]))
	game.quests.quest_completed.connect(func(id: String) -> void:
		var took := clock - float(_quest_started.get(id, clock))
		_note("quest✓", "%s за %d с" % [id, int(took)])
		_save_later.call_deferred())
	hero.level_up.connect(func(level: int) -> void: _note("level", "уровень %d" % level))
	_last_pos = hero.global_position
	_note("start", "%s, %s" % [game.current_region, str(hero.global_position)])
	while clock < limit:
		await physics_frame
		clock += STEP
		_region_time[game.current_region] = float(_region_time.get(game.current_region, 0.0)) + STEP
		_watch_messages()
		if OS.has_environment("BOT_DEBUG") and int(clock * 60) % 120 == 0 and clock > 100:
			print("state wait=%.1f story=%s dlg=%s paused=%s phys=%s pos=%s step=%s" % [_wait, game.story.active, game.hud.dialogue_visible, game.get_tree().paused, hero.is_physics_processing(), hero.global_position, _step_in])
		_tick()
	_release_keys()
	_write_report()
	quit()

# --- One tick of the bot ------------------------------------------------------

func _tick() -> void:
	if game.game_over or hero.health <= 0:
		_on_death()
		return
	if _wait > 0.0:
		_wait -= STEP
		_release_keys()
		return
	if game.story.active:
		_read(game.hud.dialogue_label.text)
		game.story.advance()
		return
	if game.hud.dialogue_visible:
		_answer_dialogue()
		return
	if game.hud.crafting_visible or game.hud.inventory_open:
		_note("window", "открылось окно %s — закрываю" % ("ремесла" if game.hud.crafting_visible else "сумки"))
		game.hud.close_top_window()
		hero.set_physics_process(true)
		return
	if game.get_tree().paused:
		_release_keys()
		_idle_time += STEP
		return
	_gear_clock -= STEP
	if _gear_clock <= 0.0:
		_gear_clock = 10.0
		_dress_up()
		_grow()
	if hero.health < hero.max_health * 0.35 and int(hero.inventory.get("health_potion", 0)) > 0:
		game._use_consumable("health_potion")
	var foe := _nearest_foe(FIGHT_RANGE)
	if foe != null:
		_fight(foe)
		return
	var goal := _choose_goal()
	if goal.is_empty():
		_release_keys()
		_idle_time += STEP
		var hint := ""
		for entry in game.director.tracker_entries():
			hint += " " + str(entry.get("progress", entry.get("title", "")))
		_set_goal_text("нечего делать." + hint)
		return
	_set_goal_text(str(goal["text"]))
	_last_goal_key = str(goal["key"])
	_walk_to(goal)

func _save_later() -> void:
	if not game.story.active and not game.game_over:
		_snapshot = game.make_save_snapshot()

## A player puts on whatever is plainly better (the bag shows ▲/▼).
func _gear_score(item_id: String) -> float:
	if item_id.is_empty():
		return 0.0
	var d := hero.get_item_definition(item_id)
	return float(d.get("melee", 0)) * 2.0 + float(d.get("armor", 0)) * 2.0 + float(d.get("max_health", 0)) * 0.25 + float(d.get("crit", 0)) + float(d.get("melee_pct", 0)) * 0.6 + float(d.get("agility", 0)) + float(d.get("power", 0)) * 0.5 + float(d.get("lifesteal", 0)) * 2.0

## A player spends talent points, learns passives at trainers and keeps a
## few potions (shortcuts: no walk to the trainer or the shop is simulated,
## the gold is paid all the same).
const TALENT_ORDER := ["blade_mastery", "vitality", "keen_edge", "herbalist", "iron_skin", "bloodthirst", "executioner", "blade_mastery", "vitality", "light_step", "keen_edge", "iron_skin", "cleave", "blade_dance", "executioner", "whirl_master", "bloodthirst", "unbreakable", "battle_rhythm", "second_wind", "vitality", "keen_edge", "iron_skin", "blade_mastery", "herbalist", "light_step", "whirl_master", "battle_rhythm", "battle_rhythm", "static_blade", "static_blade"]
const PASSIVES := ["toughness", "lifeblood", "keen_eye", "steady_hand", "fleet"]
## Active skills the bot learns and casts in fights with strong foes.
const ACTIVES := ["lunge", "shockwave", "war_cry", "blade_wave"]

func _grow() -> void:
	for talent in TALENT_ORDER:
		if SkillTree.available_points(hero) <= 0:
			break
		if SkillTree.can_learn(hero, str(talent)):
			SkillTree.learn(hero, str(talent))
			_note("talent", "%s → %d" % [talent, SkillTree.rank(hero, str(talent))])
	for skill_id in PASSIVES:
		if not hero.knows(skill_id) and game.trainers.lock_reason(skill_id).is_empty() and hero.gold >= Trainers.price_of(skill_id) + 60:
			hero.gold -= Trainers.price_of(skill_id)
			hero.learn_skill(skill_id)
			_note("skill", "%s за %d" % [skill_id, Trainers.price_of(skill_id)])
	for skill_id in ACTIVES:
		if not hero.knows(skill_id) and game.trainers.lock_reason(skill_id).is_empty() and hero.gold >= Trainers.price_of(skill_id) + 60:
			hero.gold -= Trainers.price_of(skill_id)
			hero.learn_skill(skill_id)
			_note("skill", "%s за %d" % [skill_id, Trainers.price_of(skill_id)])
	var potions := int(hero.inventory.get("health_potion", 0))
	if potions < 4 and hero.gold >= 120:
		hero.gold -= 25 * (4 - potions)
		hero.add_item("health_potion", 4 - potions)

func _dress_up() -> void:
	for item_id in hero.inventory.keys():
		var id := str(item_id)
		var d := hero.get_item_definition(id)
		var slot := str(d.get("slot", ""))
		if slot.is_empty() or slot == "weapon" or bool(d.get("bow", false)) or str(d.get("kind", "sword")) in ["staff", "bow"]:
			continue
		var target := hero.target_slot(id)
		if target.is_empty():
			continue
		if _gear_score(id) > _gear_score(str(hero.equipment.get(target, ""))) + 0.5:
			if hero.equip_item(id, target):
				_note("gear", "надето: %s" % hero.get_item_name(id))

func _read(text: String) -> void:
	var seconds := maxf(0.8, float(text.length()) / READ_CHARS_PER_SEC)
	_wait = seconds
	_read_time += seconds

func _answer_dialogue() -> void:
	var text := game.hud.dialogue_label.text
	var buttons: Array = game.hud.dialogue_choices_container.get_children().filter(func(b: Node) -> bool: return b is Button and not b.is_queued_for_deletion())
	if _read_text != text:
		_read_text = text
		_read(text)
		return
	_read_text = ""
	if buttons.is_empty():
		game.hud.close_dialogue()
		hero.set_physics_process(true)
		return
	var pick: Button = null
	for button in buttons:
		var label := (button as Button).text.to_lower()
		if label.contains("позже") or label.contains("уйти") or label.contains("до встречи") or label.contains("выйти") or label.contains("закрыть") or label.contains("остаться") or label.contains("нет"):
			continue
		pick = button
		break
	if pick == null:
		pick = buttons.back()
	_note("choice", "%s → %s" % [game.hud.dialogue_speaker_label.text, pick.text])
	pick.pressed.emit()
	await process_frame
	if game.hud.dialogue_visible and game.hud.dialogue_label.text == text:
		# The same screen again: leave it.
		game.hud.close_dialogue()
		hero.set_physics_process(true)

func _on_death() -> void:
	_deaths += 1
	_note("death", "%s у %s" % [game.current_region, str(Vector2i(hero.global_position))])
	var key := _goal_text
	_deaths_at[key] = int(_deaths_at.get(key, 0)) + 1
	# The defeat screen's "load the latest save", as a player would press it.
	if not game.load_game(true):
		game.get_tree().paused = false
		game.game_over = false
		game.hud.hide_defeat()
	hero = game.player
	hero.health = hero.max_health
	hero.set_physics_process(true)
	_path = PackedVector2Array()
	_wait = 5.0
	if int(_deaths_at[key]) >= 3:
		_deaths_at[key] = 0
		_note("problem", "три смерти на «%s» — бот уходит набираться сил на 5 минут" % key)
		_ignored_targets[_last_goal_key] = clock + 300.0
		if key.begins_with("бой: "):
			_avoid[key.trim_prefix("бой: ")] = clock + 300.0

# --- Goals ----------------------------------------------------------------------

const PRIORITY := {"turnin": 0, "main": 1, "side": 2, "offer": 3}

func _choose_goal() -> Dictionary:
	game.quest_nav.refresh()
	var best: Dictionary = {}
	var best_score := INF
	for target in game.quest_nav.targets:
		var key := "%s|%s|%s" % [target["region"], str(target["position"]), target["title"]]
		if float(_ignored_targets.get(key, -1.0)) > clock:
			continue
		var kind := str(target["kind"])
		if not PRIORITY.has(kind):
			continue
		var hops := QuestNav.route(game.current_region, str(target["region"])).size()
		if hops == 0:
			continue
		if kind != "main" and kind != "turnin" and not bool(target.get("main", false)) and _too_dangerous(str(target["region"])):
			continue
		var distance := 0.0
		if str(target["region"]) == game.current_region and target["position"] != null:
			distance = hero.global_position.distance_to(target["position"])
		var score := float(PRIORITY[kind]) * 100000.0 + float(hops) * 5000.0 + distance + (0.0 if bool(target.get("main", false)) else 2000.0)
		if score < best_score:
			best_score = score
			best = {"region": str(target["region"]), "position": target["position"], "text": "%s: %s" % [kind, str(target["title"])], "key": key}
	if not best.is_empty() and best_score < 200000.0:
		return best
	# Side offers ("!" over heads) are not pinned on the map: look for them
	# the way a player would — in the land the hero is in first.
	var offer := _nearest_offer()
	if not offer.is_empty():
		return offer
	return best

func _nearest_offer() -> Dictionary:
	var best: Dictionary = {}
	var best_score := INF
	for region_id in RegionCatalog.ids():
		for npc in RegionCatalog.get_region(str(region_id)).get("npcs", []):
			var npc_id := str(npc.get("id", ""))
			if game.dialogues.marker_for(npc_id) not in ["quest", "ready"]:
				continue
			var hops := QuestNav.route(game.current_region, str(region_id)).size()
			if _too_dangerous(str(region_id)):
				continue
			if hops == 0 or (not game.visited_regions.has(str(region_id)) and str(region_id) != game.current_region and hops > 2):
				continue
			var at := SkywardGame._vec(npc.get("position"))
			if str(region_id) == game.current_region:
				for node in game.get_children():
					if node is WorldNpc and node.npc_id == npc_id:
						at = node.global_position
			var key := "npc|" + npc_id
			if float(_ignored_targets.get(key, -1.0)) > clock:
				continue
			var score := float(hops) * 5000.0 + (hero.global_position.distance_to(at) if str(region_id) == game.current_region else 0.0)
			if score < best_score:
				best_score = score
				best = {"region": str(region_id), "position": at, "text": "«!» %s" % str(npc.get("name", npc_id)), "key": key}
	return best

## A player reads "Рекомендуемый уровень" and does not go far beyond it for
## a side errand; every land on the way counts.
func _too_dangerous(region_id: String) -> bool:
	for step in QuestNav.route(game.current_region, region_id):
		if RegionCatalog.level(str(step)) > hero.level + 1:
			return true
	return false

func _set_goal_text(text: String) -> void:
	if text == _goal_text:
		return
	if not _goal_text.is_empty() and clock - _goal_since > 0.5:
		pass
	_goal_text = text
	_goal_since = clock
	_note("goal", text)

# --- Walking --------------------------------------------------------------------

func _walk_to(goal: Dictionary) -> void:
	var region := str(goal["region"])
	var point: Variant = goal["position"]
	var gate_hop := false
	if region != game.current_region:
		var path := QuestNav.route(game.current_region, region)
		var gate := RegionCatalog.gate(game.current_region, str(path[1])) if path.size() >= 2 else {}
		if gate.is_empty():
			_ignored_targets[str(goal["key"])] = true
			_note("problem", "нет ворот к %s (%s)" % [region, goal["text"]])
			return
		point = SkywardGame._vec(gate.get("position"))
		gate_hop = true
	if point == null:
		# The whole land is the goal: hunt whatever lives here.
		var foe := _nearest_foe(2000.0)
		if foe == null:
			# Wander about the land like a player looking for them.
			_empty_land += STEP
			if _empty_land > 90.0:
				_empty_land = 0.0
				_ignored_targets[str(goal["key"])] = true
				_note("problem", "цель «%s» без места: полторы минуты в этой земле никого" % goal["text"])
				return
			if _wander == Vector2.INF or hero.global_position.distance_to(_wander) < 24.0:
				var map := game.world.get_world_2d().navigation_map
				var size: Vector2 = game.world.map_size()
				_wander = NavigationServer2D.map_get_closest_point(map, Vector2(randf() * size.x, randf() * size.y))
			point = _wander
		else:
			_empty_land = 0.0
			point = foe.global_position
	var target: Vector2 = point
	var near := hero.global_position.distance_to(target)
	if _step_in != Vector2.INF:
		if near > 6.0 and _step_clock < 1.5:
			_step_clock += STEP
			_press(target - hero.global_position)
			return
		_step_in = Vector2.INF
		_step_clock = 0.0
	if near <= REACH or (near <= 27.0 and game._find_nearest_interactable() != null):
		_release_keys()
		_arrive(goal, gate_hop)
		return
	_walk_time += STEP
	if _detour_left > 0.0:
		_detour_left -= STEP
		_press(_detour - hero.global_position)
		if _detour_left <= 0.0:
			_path = PackedVector2Array()
		return
	_steer(target)
	# Stuck: the goal has come no nearer for a while.
	if _progress_goal.distance_to(target) > 1.0:
		_progress_goal = target
		_best_near = near
		_stuck_clock = 0.0
	if near < _best_near - 4.0:
		_best_near = near
		_stuck_clock = 0.0
	else:
		_stuck_clock += STEP
		if _stuck_clock > STUCK_TIME:
			_stuck_clock = 0.0
			_stuck_points.append([game.current_region, Vector2i(hero.global_position), str(goal["text"])])
			_note("stuck", "%s у %s, цель %s" % [game.current_region, str(Vector2i(hero.global_position)), goal["text"]])
			var count := _stuck_points.filter(func(p: Array) -> bool: return str(p[2]) == str(goal["text"])).size()
			if count >= 3:
				_ignored_targets[str(goal["key"])] = true
				_note("problem", "не дойти до «%s» (%s %s)" % [goal["text"], region, str(point)])
			_path = PackedVector2Array()
			_best_near = near
			# Walk off somewhere to the side, then try again.
			var map := game.world.get_world_2d().navigation_map
			_detour = NavigationServer2D.map_get_closest_point(map, hero.global_position + Vector2.from_angle(randf() * TAU) * 56.0)
			_detour_left = 1.4

func _arrive(goal: Dictionary, gate_hop: bool) -> void:
	if clock - _last_interact < 0.6:
		return
	_last_interact = clock
	var before_region := game.current_region
	var target := game._find_nearest_interactable()
	if OS.has_environment("BOT_DEBUG"):
		print("arrive ", goal["text"], " hero=", hero.global_position, " goal=", goal["position"], " near=", target.name if target else "none", " ", target.global_position if target else "")
	if target != null and not gate_hop and goal["position"] != null and target.global_position.distance_to(goal["position"]) > 16.0 and hero.global_position.distance_to(goal["position"]) > 8.0:
		# Something else is closer to the hero than the goal: step nearer.
		_step_in = goal["position"]
		return
	if target == null:
		# Nothing to press here: maybe a land goal or a moving NPC.
		if not gate_hop and goal["position"] != null:
			var key := str(goal["key"])
			_talked[key] = int(_talked.get(key, 0)) + 1
			if int(_talked[key]) > 4:
				_ignored_targets[key] = clock + 300.0
				_note("problem", "у «%s» нечего нажать (%s %s)" % [goal["text"], game.current_region, str(goal["position"])])
		return
	game._try_interact()
	if gate_hop:
		await process_frame
		if game.current_region != before_region:
			_note("region", "%s → %s" % [before_region, game.current_region])
			_save_later.call_deferred()
			_path = PackedVector2Array()
		elif not game.hud.dialogue_visible:
			var key := str(goal["key"])
			_talked[key] = int(_talked.get(key, 0)) + 1
			if int(_talked[key]) > 3:
				_ignored_targets[key] = clock + 300.0
				_note("problem", "ворота не пускают к «%s»: %s" % [goal["text"], _last_message])
	else:
		var key := str(goal["key"])
		_talked[key] = int(_talked.get(key, 0)) + 1
		if int(_talked[key]) > 6:
			_ignored_targets[key] = clock + 300.0
			_note("problem", "цель «%s» не исчезает после нажатия E" % goal["text"])

func _steer(target: Vector2) -> void:
	if _path_goal.distance_to(target) > 8.0 or _path_region != game.current_region or _path.is_empty():
		var map := game.world.get_world_2d().navigation_map
		_path = NavigationServer2D.map_get_path(map, hero.global_position, target, true)
		_path_goal = target
		_path_region = game.current_region
	while _path.size() > 1 and hero.global_position.distance_to(_path[0]) < 6.0:
		_path.remove_at(0)
	var next := _path[0] if not _path.is_empty() else target
	if _path.size() <= 1:
		next = target
	var direction := (next - hero.global_position).normalized()
	# A player slides along a corner by feel: when the hero snags, step aside.
	if _side_left > 0.0:
		_side_left -= STEP
		direction = (direction * 0.3 + direction.orthogonal() * _side_sign).normalized()
	elif hero.get_real_velocity().length() < 15.0:
		_snag_clock += STEP
		if _snag_clock > 0.25:
			_snag_clock = 0.0
			_side_left = 0.35
			_side_sign = -_side_sign
	else:
		_snag_clock = 0.0
	_press(direction)

func _press(direction: Vector2) -> void:
	direction = direction.normalized()
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")
	if direction.x < -0.05:
		Input.action_press("move_left", -direction.x)
	elif direction.x > 0.05:
		Input.action_press("move_right", direction.x)
	if direction.y < -0.05:
		Input.action_press("move_up", -direction.y)
	elif direction.y > 0.05:
		Input.action_press("move_down", direction.y)

func _release_keys() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)

# --- Fighting ---------------------------------------------------------------------

func _nearest_foe(range: float) -> SlimeEnemy:
	var best: SlimeEnemy = null
	var best_distance := range
	for node in game.get_children():
		if node is SlimeEnemy and not node.is_queued_for_deletion() and node.health > 0 and float(_avoid.get(SkywardGame.enemy_kind(node), -1.0)) < clock:
			var distance := hero.global_position.distance_to(node.global_position)
			if distance < best_distance:
				best_distance = distance
				best = node
	return best

func _fight(foe: SlimeEnemy) -> void:
	_fight_time += STEP
	_set_goal_text("бой: %s" % SkywardGame.enemy_kind(foe))
	var offset := foe.global_position - hero.global_position
	if offset.length() > 24.0:
		_steer(foe.global_position)
		return
	_release_keys()
	hero.facing = offset.normalized()
	# Skills 1–4 on strong foes (and on packs), like a player would.
	_skill_clock -= STEP
	var strong := foe.combat_feedback.elite or SkywardGame.STORY_BOSSES.has(SkywardGame.enemy_kind(foe)) or foe.max_health > hero.get_melee_damage() * 8
	if _skill_clock <= 0.0 and (strong or game._living_enemies().size() >= 3):
		_skill_clock = 0.6
		for slot in 4:
			if game.skills.use_slot(slot):
				break
	game.sword_slash()

# --- Watching the screen ------------------------------------------------------------

func _watch_messages() -> void:
	var text := game.hud.message_label.text
	if text != _last_message and not text.is_empty():
		_last_message = text
		_note("msg", text.replace("\n", " "))

# --- Report ---------------------------------------------------------------------------

func _write_report() -> void:
	var lines: Array[String] = []
	lines.append("# Первый час: прогон бота")
	lines.append("")
	lines.append("Игровое время: %d мин. Уровень: %d. Золото: %d. Смертей: %d." % [int(clock / 60.0), hero.level, hero.gold, _deaths])
	lines.append("Ходьба %d мин, бой %d мин, чтение %d мин, простой %d мин." % [int(_walk_time / 60), int(_fight_time / 60), int(_read_time / 60), int(_idle_time / 60)])
	lines.append("")
	lines.append("## Земли (минут)")
	for region_id in _region_time:
		lines.append("- %s: %.1f" % [region_id, float(_region_time[region_id]) / 60.0])
	lines.append("")
	lines.append("## Задания")
	for id in _quest_started:
		var done := game.quests.is_completed(str(id))
		lines.append("- %s %s (взято на %d:%02d)" % ["✓" if done else "…", str(id), int(_quest_started[id]) / 60, int(_quest_started[id]) % 60])
	lines.append("")
	lines.append("## Проблемы")
	for event in events:
		if str(event["kind"]) in ["problem", "stuck", "death"]:
			lines.append("- %d:%02d %s: %s" % [int(event["time"]) / 60, int(event["time"]) % 60, event["kind"], event["text"]])
	lines.append("")
	lines.append("## Журнал")
	lines.append("```")
	lines.append_array(log_lines)
	lines.append("```")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
	print("REPORT → ", report_path)
