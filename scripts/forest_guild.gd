extends Node
class_name ForestGuild

## Stage 21, step 8: the Foresters' Lodge — a cottage in the woods east of
## the village (Greenreach) that can be entered (region "guild_lodge",
## tools/lodge_layout.py): Orvin the forester, a carpenter's bench, a hearth
## and a bed.
##
## Forestry: trees for firewood are real trees now — felled, they leave a
## stump, then a sapling, then grow back (scripts/gather_node.gd). A sapling
## planted on a stump halves the wait. Felling gives 1 point, planting 2;
## points raise the forester's rank:
##   Лесоруб — +1 log per tree; Лесничий — resin now and then;
##   Хранитель леса — trees grow back twice as fast.
## The bench (station "carpentry") makes planks, resin torches and a charm.

const HOME := "greenreach"
const LODGE := "guild_lodge"
const COTTAGE := Vector2(1620, 510)
const ROOM := Rect2(192, 144, 256, 160)
const NPC := "forester"
const SAPLING := "sapling"
const RESIN := "resin"
## [name, points, perk]
const RANKS := [
	["Подмастерье", 0, "учится держать топор"],
	["Лесоруб", 10, "+1 бревно с каждого дерева"],
	["Лесничий", 30, "иногда находит смолу"],
	["Хранитель леса", 60, "деревья вырастают вдвое быстрее"],
]
const DAILY_SAPLINGS := 3

var game: SkywardGame
var points: int = 0
var felled: int = 0
var planted_total: int = 0
## Node keys with a sapling on the stump.
var planted: Dictionary = {}
var sapling_day: int = -1
var rested_day: int = -1
var warmed_day: int = -1
var gift_taken: bool = false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func rank() -> int:
	var result := 0
	for i in RANKS.size():
		if points >= int(RANKS[i][1]):
			result = i
	return result

func rank_name() -> String:
	return str(RANKS[rank()][0])

func _add_points(amount: int) -> void:
	var before := rank()
	points += amount
	if rank() > before:
		var info: Array = RANKS[rank()]
		game.hud.show_title_card("Ранг лесничих: %s" % str(info[0]), 2.6)
		game.hud.show_message("Новое умение: %s." % str(info[2]), 4.5)
		GameAudio.play("quest", -2.0, 0.0)
	game.achievements.set_max("forester_rank", rank())

# --- Forestry (hooks from scripts/crafting_menu.gd) -------------------------

## A node was gathered: the bonus amount on top.
func on_gathered(node: GatherNode) -> int:
	if node.kind != "wood":
		return 0
	felled += 1
	planted.erase(node.key)
	_add_points(1)
	if rank() >= 2 and rng.randf() < 0.25:
		game.player.add_item(RESIN, 1)
		game.hud.show_message("На срезе — янтарная смола!", 2.5)
	if rng.randf() < 0.35:
		game.player.add_item(SAPLING, 1)
	return 1 if rank() >= 1 else 0

func regrow_factor(node: GatherNode) -> float:
	return 0.5 if node.kind == "wood" and rank() >= 3 else 1.0

## Cultivation belongs to the settlement; other lands keep ordinary respawn.
func can_plant(node: GatherNode) -> bool:
	if node == null or node.available or game.current_region != game.settlement.village_region() or not node.growth_enabled:
		return false
	if node.kind != "wood" or planted.has(node.key) or int(game.player.inventory.get(SAPLING, 0)) <= 0:
		return false
	return float(game.crafting.cooldowns.get(node.key, 0.0)) - game.crafting.play_time > 1.0

## E on a settlement stump with a sapling: halve the remaining wait.
func try_plant(node: GatherNode) -> bool:
	if not can_plant(node):
		return false
	var crafting := game.crafting
	var left := float(crafting.cooldowns.get(node.key, 0.0)) - crafting.play_time
	game.player.remove_item(SAPLING, 1)
	crafting.cooldowns[node.key] = crafting.play_time + left * 0.5
	planted[node.key] = true
	planted_total += 1
	node.set_stage("young")
	Vfx.burst(game, node.global_position, [Color(0.8, 1.0, 0.6), Color(0.4, 0.8, 0.3), Color(0.2, 0.5, 0.2, 0)], 12, 50.0, 0.5)
	GameAudio.play("pickup", -6.0, 0.25)
	game.hud.show_message("Саженец посажен: дерево вырастет вдвое быстрее.", 3.0)
	_add_points(2)
	return true

## The look of a resting node: a stump, later (or when planted) a sapling.
func update_stage(node: GatherNode) -> void:
	if node.kind != "wood":
		return
	if not node.growth_enabled:
		node.set_stage("cut")
		return
	var crafting := game.crafting
	var left := float(crafting.cooldowns.get(node.key, 0.0)) - crafting.play_time
	var respawn := float(crafting.kind("wood").get("respawn", 240))
	node.set_stage("young" if planted.has(node.key) or left < respawn * 0.4 else "cut")

# --- The cottage and the room -------------------------------------------------

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

func _animated(at: Vector2, sheet: String, glow: Color, wall: float = 0.0, label: String = "") -> TowerObject:
	var object := TowerObject.new()
	object.sheet = sheet
	object.glow = glow
	object.wall_width = wall
	object.label = label
	game.add_child(object)
	object.global_position = at
	return object

## Called when a region is built.
func populate() -> void:
	if game.current_region == HOME:
		_object(COTTAGE, "lodge_cottage", "", 70.0)
		var way := _object(COTTAGE + Vector2(0, 8), "", "E — войти в дом лесничих")
		way.map_label = "Дом лесничих"
		way.used.connect(func(_o: TowerObject) -> void: enter())
		_object(COTTAGE + Vector2(-66, -6), "lodge_firewood", "", 22.0)
		for i in 3:
			_object(COTTAGE + Vector2(52 + i * 32, 22), "lodge_fence", "", 30.0)
		_object(COTTAGE + Vector2(-52, 20), "lodge_flowers")
		_object(COTTAGE + Vector2(64, 4), "lodge_fern")
		_object(COTTAGE + Vector2(-84, 22), "lodge_bluebells")
		for node in game.get_children():
			if node is GatherNode and not node.available:
				update_stage(node)
		return
	if game.current_region != LODGE:
		return
	var r := ROOM
	# Walls: the rear with a window, the sides, the cut-away front.
	for i in 4:
		_object(Vector2(r.position.x + 32 + 64 * i, r.position.y), "lodge_wall_window" if i == 1 else "lodge_wall").z_index = -60
	for i in 3:
		_object(Vector2(r.position.x - 8, r.end.y + 6 - 64 * i), "lodge_wall_west").z_index = -61
		_object(Vector2(r.end.x + 8, r.end.y + 6 - 64 * i), "lodge_wall_east").z_index = -61
	for i in 4:
		_object(Vector2(r.position.x + 32 + 64 * i, r.end.y + 6), "lodge_wall_front").z_index = 40
	var door := Vector2(r.get_center().x, r.end.y - 2)
	_object(door, "lodge_threshold", "", 0.0, Color(0, 0, 0, 0), true)
	var way_out := _object(door + Vector2(0, -6), "", "E — выйти")
	way_out.map_label = "Выход"
	way_out.used.connect(func(_o: TowerObject) -> void: leave())
	_object(r.get_center() + Vector2(0, 26), "lodge_rug", "", 0.0, Color(0, 0, 0, 0), true)
	# Hearth, bench, bed, table, shelf, chest.
	var hearth := _animated(Vector2(r.position.x + 40, r.position.y + 22), "lodge_hearth", Color(1.0, 0.62, 0.3, 0.45), 38.0, "E — погреться у очага")
	hearth.used.connect(func(_o: TowerObject) -> void: warm_up())
	var bench := _object(Vector2(r.end.x - 44, r.position.y + 30), "lodge_bench", "E — столярный верстак", 40.0)
	bench.used.connect(func(_o: TowerObject) -> void: game.crafting.open("carpentry"))
	var bed := _object(Vector2(r.position.x + 22, r.end.y - 22), "lodge_bed", "E — вздремнуть", 22.0)
	bed.used.connect(func(_o: TowerObject) -> void: nap())
	_object(Vector2(r.end.x - 60, r.end.y - 36), "lodge_table", "", 28.0)
	_object(Vector2(r.end.x - 86, r.end.y - 30), "lodge_stool")
	_animated(Vector2(r.end.x - 60, r.end.y - 52), "lodge_candle", Color(1.0, 0.8, 0.45, 0.2)).z_index = 5
	_object(Vector2(r.position.x + 108, r.position.y + 14), "lodge_shelf", "", 28.0)
	_animated(Vector2(r.position.x + 150, r.position.y - 16), "lodge_lantern", Color(1.0, 0.75, 0.4, 0.22)).z_index = -58
	_animated(Vector2(r.end.x - 20, r.position.y - 16), "lodge_lantern", Color(1.0, 0.75, 0.4, 0.22)).z_index = -58
	var chest := _object(Vector2(r.end.x - 20, r.end.y - 70), "lodge_chest", "" if gift_taken else "E — сундук гильдии", 20.0)
	chest.used.connect(func(o: TowerObject) -> void: take_gift(o))

func enter() -> void:
	game._travel(LODGE, Vector2(ROOM.get_center().x, ROOM.end.y - 26))

func leave() -> void:
	game._travel(HOME, COTTAGE + Vector2(0, 30))

func take_gift(chest: TowerObject) -> void:
	if gift_taken:
		return
	gift_taken = true
	chest.label = ""
	chest.remove_from_group("interactables")
	game.player.add_item(SAPLING, 5)
	game.player.add_item("wood", 4)
	GameAudio.play("chest", -4.0, 0.0)
	game.hud.show_message("В сундуке гильдии: 5 саженцев и 4 бревна. «Новичкам — на почин», — кивает Орвин.", 4.5)

func nap() -> void:
	var day := game.day_night.day
	if rested_day == day:
		game.hud.show_message("Сегодня вы уже отдыхали здесь. Постель подождёт до завтра.", 3.0)
		return
	rested_day = day
	game.player.health = game.player.max_health
	game.player.mana = game.player.max_mana
	game.player.stats_changed.emit()
	GameAudio.play("quest", -8.0, -0.2)
	game.hud.show_message("Вы вздремнули под треск очага. Здоровье и мана восстановлены.", 3.5)

func warm_up() -> void:
	var day := game.day_night.day
	if warmed_day == day:
		game.hud.show_message("Очаг потрескивает. Тепло — но второй раз за день не согреет сильнее.", 3.0)
		return
	warmed_day = day
	game.player.add_buff("regen", 1.5, 300.0, "Тепло очага")
	GameAudio.play("pickup", -8.0, -0.2)
	game.hud.show_message("«Тепло очага»: +1,5 здоровья в секунду на 5 минут.", 3.5)

# --- Orvin ----------------------------------------------------------------------

func marker(npc_id: String) -> String:
	return "service" if npc_id == NPC else ""

func talk(npc_id: String) -> bool:
	if npc_id != NPC:
		return false
	var text := "Орвин откладывает рубанок.\n— Лес кормит того, кто его бережёт. Срубил — посади. "
	text += "Твой ранг: %s (%d очк.)." % [rank_name(), points]
	if rank() + 1 < RANKS.size():
		var next: Array = RANKS[rank() + 1]
		text += " До ранга «%s» — ещё %d: %s." % [str(next[0]), int(next[1]) - points, str(next[2])]
	text += "\nСрублено деревьев: %d, посажено: %d." % [felled, planted_total]
	var choices: Array[Dictionary] = []
	if sapling_day != game.day_night.day:
		choices.append({"id": "forest_saplings", "label": "Взять саженцы на сегодня (%d)" % DAILY_SAPLINGS})
	choices.append({"id": "forest_how", "label": "Как растить лес?"})
	choices.append({"id": "forest_close", "label": "До встречи"})
	game._show_dialogue_choices("Орвин, старший лесничий", text, choices)
	return true

func handle_choice(choice_id: String) -> bool:
	if not choice_id.begins_with("forest_"):
		return false
	if choice_id == "forest_saplings":
		if sapling_day != game.day_night.day:
			sapling_day = game.day_night.day
			game.player.add_item(SAPLING, DAILY_SAPLINGS)
			game.hud.show_message("Получено: саженцы ×%d." % DAILY_SAPLINGS, 2.5)
		talk(NPC)
	elif choice_id == "forest_how":
		var choices: Array[Dictionary] = [{"id": "forest_back", "label": "Понятно"}]
		game._show_dialogue_choices("Орвин, старший лесничий", "На острове нашего поселения дерево на дрова рубится — остаётся пень. Подойди к пню с саженцем и нажми E: вырастет вдвое быстрее. За срубленное — очко, за посаженное — два. Саженцы даю я, по три в день, да и с деревьев порой падают. Из брёвен на верстаке — доски, из смолы — факелы и оберег.", choices)
	elif choice_id == "forest_back":
		talk(NPC)
	else:
		game.dialogues._close()
	return true

func make_snapshot() -> Dictionary:
	return {"points": points, "felled": felled, "planted_total": planted_total, "planted": planted.keys(), "sapling_day": sapling_day,
		"rested_day": rested_day, "warmed_day": warmed_day, "gift": gift_taken}

func restore_snapshot(value: Variant) -> void:
	var data: Dictionary = value if value is Dictionary else {}
	points = int(data.get("points", 0))
	felled = int(data.get("felled", 0))
	planted_total = int(data.get("planted_total", 0))
	planted.clear()
	for key in data.get("planted", []):
		planted[str(key)] = true
	sapling_day = int(data.get("sapling_day", -1))
	rested_day = int(data.get("rested_day", -1))
	warmed_day = int(data.get("warmed_day", -1))
	gift_taken = bool(data.get("gift", false))
