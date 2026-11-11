extends Node
class_name TrialTower

## Stage 21, step 5: the Tower of Trials — a climb that is open from the very
## start (the gate stands north-east of the village in Greenreach).
##
## Every floor is the same stone hall (region "trial_tower",
## tools/tower_layout.py). Pull the lever: the floor's foes come out, bound by
## the floor's rule (swift, iron, fury, swarm, elite). Clear them: the coffer
## opens, the altar offers one of three blessings that last until you leave,
## the stairs lead up. Every 5th floor is a champion; its crystal is a
## checkpoint — next time you may start right above it. A fall does not kill:
## the tower carries the hero out with everything found. Record floors and
## champions pay Seals of Trials, traded at the gate for prizes.
## Foes do not grow with the hero — only with the floor.

const REGION := "trial_tower"
const HOME := "greenreach"
const GATE := Vector2(1078, 462)
const HALL := Rect2(64, 96, 416, 272)
const CENTRE := Vector2(272, 226)
const START := Vector2(272, 322)
const CHAMPION_EVERY := 5
const SEAL := "trial_seal"
const TIERS := [
	[1, ["slime", "wolf", "bat"]],
	[5, ["skeleton", "crab", "wisp", "toad"]],
	[10, ["golem", "sentinel", "shade", "skeleton"]],
	[15, ["ember_hound", "magma_golem", "ash_cultist", "sentinel"]],
	[20, ["pattern_shade", "magma_golem", "shade", "ash_cultist"]],
]
const RULES := {
	"plain": ["Без правил", "Обычный бой."],
	"swift": ["Быстрые", "Враги на треть быстрее."],
	"iron": ["Железные", "У врагов в полтора раза больше здоровья."],
	"fury": ["Яростные", "Враги бьют на 30% сильнее."],
	"swarm": ["Рой", "Врагов больше, но они слабее."],
	"elite": ["Избранные", "Почти все враги — элита."],
}
## id: [name, text, buff type, value per stack]
const BLESSINGS := {
	"might": ["Сила", "урон +12%", "power", 0.12],
	"guard": ["Стойкость", "броня +4", "armor", 4.0],
	"haste": ["Ветер", "скорость +6%", "speed", 0.06],
	"focus": ["Зоркость", "шанс крита +6%", "crit", 0.06],
	"vigor": ["Живица", "+1,5 здоровья в секунду", "regen", 1.5],
}
## [item, amount, seals, label]
## A blessing stacks no more than this many times in one climb.
const BLESSING_CAP := 3
const PRIZES := [
	["health_potion", 4, 1, "4 зелья здоровья"],
	["starlight_essence", 1, 3, "Звёздная эссенция"],
	["@epic", 1, 4, "Эпическая вещь по уровню"],
	["@legendary", 1, 9, "Легендарная вещь по уровню"],
]

var game: SkywardGame
var floor_no: int = 1
var best: int = 0
## The highest champion floor cleared: a run may start at checkpoint + 1.
var checkpoint: int = 0
var active: bool = false
## "idle" (lever waits), "fight", "cleared".
var state: String = "idle"
var rule: String = "plain"
var blessings: Dictionary = {}
var offered: Array = []
var blessed: bool = false
var looted: bool = false
var rng := RandomNumberGenerator.new()
var _foes: Array = []
var _objects: Dictionary = {}

func _ready() -> void:
	rng.randomize()

func champion_floor() -> bool:
	return floor_no % CHAMPION_EVERY == 0

func seals() -> int:
	return int(game.player.inventory.get(SEAL, 0))

func _process(_delta: float) -> void:
	if active and game != null and game.current_region != REGION:
		end_run()

# --- The gate in Greenreach --------------------------------------------------

func _object(at: Vector2, art: String, label: String = "", wall: float = 0.0, glow: Color = Color(0, 0, 0, 0), flat: bool = false) -> TowerObject:
	var object := TowerObject.new()
	object.art = art
	object.label = label
	object.wall_width = wall
	object.glow = glow
	object.flat = flat
	game.add_child(object)
	object.global_position = at
	return object

## Called when a region is built.
func populate() -> void:
	_objects.clear()
	_foes.clear()
	if game.current_region == HOME:
		_object(GATE, "tower_gate_open", "", 44.0, Color(0.7, 0.45, 1.0, 1.0))
		var way := _object(GATE + Vector2(0, 8), "", "E — Башня испытаний")
		way.map_label = "Башня испытаний"
		way.used.connect(func(_o: TowerObject) -> void: open_gate())
		_object(GATE + Vector2(-40, 4), "tower_banner")
		_object(GATE + Vector2(40, 4), "tower_banner")
		return
	if game.current_region != REGION:
		return
	if not active:
		# Loaded inside the tower: the run starts over from the checkpoint.
		_begin(checkpoint + 1)
	_object(CENTRE, "tower_sigil", "", 0.0, Color(0, 0, 0, 0), true)
	for corner in [Vector2(96, 136), Vector2(448, 136), Vector2(96, 340), Vector2(448, 340)]:
		_object(corner, "tower_brazier", "", 14.0, Color(0.75, 0.5, 1.0, 1.0))
	for x in [152.0, 392.0]:
		_object(Vector2(x, 112), "tower_banner")
	_object(Vector2(118, 300), "tower_amethyst")
	_object(Vector2(430, 180), "tower_amethyst")
	_rebuild()

func open_gate() -> void:
	var text := "Каменные врата гудят. Наверху — этаж за этажом, и с каждым враги сильнее. Падение не смертельно: башня вынесет вас наружу со всем найденным."
	text += "\nРекорд: %s. Печатей испытаний: %d." % ["этаж %d" % best if best > 0 else "пока нет", seals()]
	var choices: Array[Dictionary] = [{"id": "trial_enter:1", "label": "Войти — с 1-го этажа"}]
	if checkpoint > 0:
		choices.append({"id": "trial_enter:%d" % (checkpoint + 1), "label": "Войти — с %d-го этажа (кристалл)" % (checkpoint + 1)})
	choices.append({"id": "trial_shop", "label": "Обменять печати на награды"})
	choices.append({"id": "trial_close", "label": "Уйти"})
	game._show_dialogue_choices("Башня испытаний", text, choices)

func _open_shop() -> void:
	var choices: Array[Dictionary] = []
	for i in PRIZES.size():
		var prize: Array = PRIZES[i]
		choices.append({"id": "trial_prize:%d" % i, "label": "%s — %d печ." % [str(prize[3]), int(prize[2])]})
	choices.append({"id": "trial_gate", "label": "Назад"})
	game._show_dialogue_choices("Башня испытаний", "Врата принимают Печати испытаний. У вас: %d." % seals(), choices)

func handle_choice(choice_id: String) -> bool:
	if not choice_id.begins_with("trial_"):
		return false
	if choice_id == "trial_close":
		game.dialogues._close()
	elif choice_id == "trial_gate":
		open_gate()
	elif choice_id == "trial_shop":
		_open_shop()
	elif choice_id.begins_with("trial_enter:"):
		game.dialogues._close()
		enter(int(choice_id.get_slice(":", 1)))
	elif choice_id.begins_with("trial_prize:"):
		_buy(int(choice_id.get_slice(":", 1)))
		_open_shop()
	elif choice_id.begins_with("trial_bless:"):
		game.dialogues._close()
		bless(choice_id.get_slice(":", 1))
	return true

func _buy(index: int) -> void:
	if index < 0 or index >= PRIZES.size():
		return
	var prize: Array = PRIZES[index]
	if seals() < int(prize[2]) or not game.player.remove_item(SEAL, int(prize[2])):
		return
	var item := str(prize[0])
	if item.begins_with("@"):
		game.spawn_generated_loot(game.player.global_position + Vector2(0, 22), item.trim_prefix("@"))
	else:
		game.player.add_item(item, int(prize[1]))
	GameAudio.play("quest", -4.0, 0.0)
	game.hud.show_message("Получено: %s." % str(prize[3]), 3.0)

# --- A run -------------------------------------------------------------------

func _begin(from_floor: int) -> void:
	active = true
	floor_no = clampi(from_floor, 1, checkpoint + 1)
	blessings.clear()
	_set_floor()

func _set_floor() -> void:
	state = "idle"
	blessed = false
	looted = false
	offered.clear()
	_foes.clear()
	rule = "plain"
	if floor_no >= 3 and not champion_floor():
		var keys := RULES.keys()
		rule = str(keys[rng.randi_range(0, keys.size() - 1)])

func enter(from_floor: int = 1) -> void:
	_begin(from_floor)
	game._travel(REGION, START)
	game.hud.show_title_card("Башня испытаний · этаж %d" % floor_no, 2.6)

## Leaving the tower (through the door or by falling) ends the run.
func end_run() -> void:
	active = false
	state = "idle"
	for id in blessings:
		game.player.buffs.erase(str(BLESSINGS[id][2]))
	blessings.clear()
	game.player.stats_changed.emit()
	_foes.clear()

## The hero fell: the tower carries them out alive. True if it did.
func on_fall() -> bool:
	if not active or game.current_region != REGION:
		return false
	game.player.health = 1
	_carry_out.call_deferred()
	return true

func _carry_out() -> void:
	var reached := floor_no
	end_run()
	game.player.health = maxi(1, game.player.max_health / 2)
	game.player.stats_changed.emit()
	game._travel(HOME, GATE + Vector2(0, 36))
	game.hud.show_title_card("Башня вынесла вас наружу", 2.6)
	game.hud.show_message("Вы пали на %d-м этаже. Рекорд: %s." % [reached, "этаж %d" % best if best > 0 else "нет"], 4.5)

func _tier_kinds() -> Array:
	var kinds: Array = TIERS[0][1]
	for tier in TIERS:
		if floor_no >= int(tier[0]):
			kinds = tier[1]
	return kinds

func health_mult() -> float:
	# Past floor 20 the climb steepens, so there is always a ceiling to push.
	var late := maxf(0.0, float(floor_no - 20))
	return 0.7 + 0.16 * float(floor_no - 1) + 0.012 * late * late

func damage_mult() -> float:
	return 0.8 + 0.07 * float(floor_no - 1)

func _rebuild() -> void:
	for key in _objects:
		if is_instance_valid(_objects[key]):
			_objects[key].queue_free()
	_objects.clear()
	if game.current_region != REGION:
		return
	if state == "idle":
		var lever := _object(Vector2(330, 318), "tower_lever", "E — начать испытание (этаж %d)" % floor_no, 14.0)
		lever.used.connect(func(_o: TowerObject) -> void: pull_lever())
		_objects["lever"] = lever
	else:
		_objects["lever"] = _object(Vector2(330, 318), "tower_lever_pulled", "", 14.0)
	if state != "cleared":
		return
	var coffer := _object(Vector2(196, 140), "tower_coffer_open" if looted else "tower_coffer", "" if looted else "E — открыть ларец", 20.0)
	coffer.used.connect(func(_o: TowerObject) -> void: open_coffer())
	_objects["coffer"] = coffer
	var altar := _object(Vector2(348, 140), "tower_altar" if blessed else "tower_altar_charged", "" if blessed else "E — алтарь благословений", 22.0, Color(0, 0, 0, 0) if blessed else Color(0.8, 0.5, 1.0, 1.0))
	altar.used.connect(func(_o: TowerObject) -> void: open_altar())
	_objects["altar"] = altar
	var stairs := _object(Vector2(272, 132), "tower_stairs", "E — подняться на этаж %d" % (floor_no + 1))
	stairs.used.connect(func(_o: TowerObject) -> void: climb())
	_objects["stairs"] = stairs
	if champion_floor():
		_objects["crystal"] = _object(Vector2(124, 200), "tower_crystal", "", 12.0, Color(0.6, 0.8, 1.0, 1.0))

func pull_lever() -> void:
	if state != "idle" or not active:
		return
	state = "fight"
	_rebuild()
	GameAudio.play("boss_roar", -8.0, 0.0)
	game.shake(3.0, 0.3)
	var info: Array = RULES[rule]
	if champion_floor():
		game.hud.show_title_card("Этаж %d · Чемпион башни" % floor_no, 2.4)
	else:
		game.hud.show_title_card("Этаж %d · %s" % [floor_no, str(info[0])], 2.2)
		if rule != "plain":
			game.hud.show_message(str(info[1]), 3.5)
	var kinds := _tier_kinds()
	if champion_floor():
		_spawn(str(kinds[(floor_no / CHAMPION_EVERY) % kinds.size()]), CENTRE + Vector2(0, -40), true)
		for i in 2:
			_spawn(str(kinds[i % kinds.size()]), CENTRE + Vector2(-70 + 140 * i, -10), false)
	else:
		var count := 3 + mini(4, floor_no / 3) + (3 if rule == "swarm" else 0)
		for i in count:
			var at := CENTRE + Vector2.RIGHT.rotated(TAU * i / count - 1.2) * Vector2(110, 62)
			_spawn(str(kinds[rng.randi_range(0, kinds.size() - 1)]), at, false)
	if _foes.is_empty():
		_on_cleared()

func _spawn(kind: String, at: Vector2, champion: bool) -> void:
	var elite := ""
	if not champion and EliteModifiers.can_be_elite(kind) and rng.randf() < (0.8 if rule == "elite" else minf(0.3, 0.02 * floor_no)):
		elite = EliteModifiers.pick(rng)
	var foe := game.spawn_enemy(kind, at, elite)
	if foe == null:
		return
	foe.set_meta("trial_foe", true)
	var health := health_mult() * (1.5 if rule == "iron" else 1.0) * (0.65 if rule == "swarm" else 1.0)
	var damage := damage_mult() * (1.3 if rule == "fury" else 1.0)
	if champion:
		health *= 6.0
		damage *= 1.3
		foe.visual.scale *= 1.6
		foe.knockback_resist = maxf(foe.knockback_resist, 0.8)
		foe.combat_feedback.elite = true
		foe.combat_feedback.elite_name = "♦ Чемпион башни"
		foe.combat_feedback.elite_color = Color(0.8, 0.55, 1.0)
		foe.base_visual_tint = Color(0.85, 0.7, 1.0)
		foe.visual.modulate = foe.base_visual_tint
	foe.max_health = maxi(1, roundi(foe.max_health * health))
	foe.health = foe.max_health
	foe.attack_damage = maxi(1, roundi(foe.attack_damage * damage))
	if rule == "swift":
		foe.move_speed *= 1.33
	foe.combat_feedback.set_health(foe.health, foe.max_health)
	foe.defeated.connect(func(_xp: int) -> void: _on_down(foe))
	_foes.append(foe)
	Vfx.sparkle(game, at)

func _on_down(foe: SlimeEnemy) -> void:
	_foes.erase(foe)
	var alive := _foes.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as SlimeEnemy).is_queued_for_deletion() and (e as SlimeEnemy).health > 0)
	if alive.is_empty() and state == "fight":
		_on_cleared.call_deferred()

func _on_cleared() -> void:
	if state != "fight":
		return
	state = "cleared"
	var record := floor_no > best
	best = maxi(best, floor_no)
	var gained := (1 if record else 0) + (2 if champion_floor() else 0)
	if gained > 0:
		game.player.add_item(SEAL, gained)
	if champion_floor():
		checkpoint = maxi(checkpoint, floor_no)
	game.achievements.set_max("trial_tower", best)
	# Offer three different blessings.
	var ids := BLESSINGS.keys().filter(func(id: Variant) -> bool: return int(blessings.get(id, 0)) < BLESSING_CAP)
	ids.shuffle()
	offered = ids.slice(0, 3)
	_rebuild()
	GameAudio.play("quest", -2.0, 0.0)
	Vfx.burst(game, CENTRE, [Color(1, 0.9, 1.0), Color(0.75, 0.5, 1.0), Color(0.4, 0.2, 0.7, 0)], 26, 100.0, 0.6)
	var text := "Этаж %d пройден!" % floor_no
	if gained > 0:
		text += " Печатей испытаний: +%d." % gained
	if champion_floor():
		text += " Кристалл запомнил этаж — в следующий раз можно начать выше."
	game.hud.show_message(text, 4.5)
	game.request_autosave()

func open_coffer() -> void:
	if state != "cleared" or looted:
		return
	looted = true
	var at := Vector2(196, 164)
	game._spawn_loot(at, "gold").amount = (15 + 10 * floor_no) * (3 if champion_floor() else 1)
	if champion_floor():
		game.spawn_generated_loot(at + Vector2(-16, 8), "legendary" if floor_no >= 20 else ("epic" if floor_no >= 10 else "rare"))
		if floor_no >= 10:
			game._spawn_loot(at + Vector2(16, 8), "starlight_essence").amount = 1
	elif rng.randf() < minf(0.7, 0.25 + 0.03 * floor_no):
		game.spawn_generated_loot(at + Vector2(-16, 8), "rare" if floor_no >= 8 else "uncommon")
	if floor_no % 2 == 0:
		game._spawn_loot(at + Vector2(16, 10), "health_potion").amount = 1
	GameAudio.play("chest", -4.0, 0.0)
	_rebuild()

func open_altar() -> void:
	if state != "cleared" or blessed:
		return
	if offered.is_empty():
		game.hud.show_message("Алтарь молчит: все благословения уже с вами в полной силе.", 3.5)
		return
	var choices: Array[Dictionary] = []
	for id in offered:
		var info: Array = BLESSINGS[id]
		var have := int(blessings.get(id, 0))
		choices.append({"id": "trial_bless:%s" % id, "label": "%s: %s%s" % [str(info[0]), str(info[1]), " (уже ×%d)" % have if have > 0 else ""]})
	choices.append({"id": "trial_close", "label": "Позже"})
	game._show_dialogue_choices("Алтарь благословений", "Выберите одно благословение. Оно действует, пока вы в башне, и складывается с прежними (до трёх раз каждое).", choices)

func bless(id: String) -> void:
	if state != "cleared" or blessed or not offered.has(id):
		return
	blessed = true
	blessings[id] = int(blessings.get(id, 0)) + 1
	_apply_blessings()
	Vfx.level_up(game, game.player.global_position)
	GameAudio.play("quest", -6.0, 0.0)
	game.hud.show_message("Благословение «%s»: %s." % [str(BLESSINGS[id][0]), str(BLESSINGS[id][1])], 3.0)
	_rebuild()

func _apply_blessings() -> void:
	for id in blessings:
		var info: Array = BLESSINGS[id]
		game.player.add_buff(str(info[2]), float(info[3]) * int(blessings[id]), 99999.0, "Башня: " + str(info[0]))

func climb() -> void:
	if state != "cleared":
		return
	floor_no += 1
	_set_floor()
	game.player.global_position = START
	game.player.heal(roundi(game.player.max_health * 0.15))
	_apply_blessings()
	_rebuild()
	GameAudio.play("travel", -6.0, 0.0)
	game.hud.show_title_card("Этаж %d" % floor_no, 1.8)

func make_snapshot() -> Dictionary:
	return {"best": best, "checkpoint": checkpoint}

func restore_snapshot(value: Variant) -> void:
	var data: Dictionary = value if value is Dictionary else {}
	best = int(data.get("best", 0))
	checkpoint = int(data.get("checkpoint", 0))
	active = false
	blessings.clear()
