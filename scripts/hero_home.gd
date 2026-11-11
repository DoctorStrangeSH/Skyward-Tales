extends Node
class_name HeroHome

## Stage 21, step 10: the heroine's house can be entered (region
## "hero_home", tools/home_layout.py; the door of the settlement building
## "home" leads in). Inside: the bed (sleep until morning — as before), a
## hearth at level 2, a wardrobe (change the hero's look), a table — and the
## trophy wall: deeds across the world leave keepsakes here, each with a
## line of memory when looked at.

const VILLAGE := "greenreach"
const REGION := "hero_home"
const ROOM := Rect2(192, 144, 256, 144)
## id: [art, offset in the room, title, memory]. Shown when `earned(id)`.
const TROPHIES := {
	"tower": ["tower_banner", Vector2(138, 6), "Знамя башни", "Знамя с 5-го этажа Башни испытаний. Чемпион был упрям."],
	"cistern": ["cistern_pots", Vector2(150, 30), "Черепки из цистерны", "Черепки со дна Старой цистерны. Ещё пахнут тиной."],
	"adit": ["tower_amethyst", Vector2(232, 70), "Аметист жеоды", "Друза из жеоды в старой штольне. Страж её берёг."],
	"forest": ["lodge_fern", Vector2(20, 76), "Папоротник лесничих", "Подарок Орвина Хранителю леса."],
	"scout": ["tower_crystal", Vector2(232, 30), "Приз разведчицы", "Алая отдала свой кристалл-компас: «Ноги у тебя что надо»."],
	"fair": ["fair_target", Vector2(200, 8), "Мишень с ярмарки", "Соломенная мишень: пять попаданий подряд."],
}

var game: SkywardGame

func home_level() -> int:
	return game.settlement.building_level(VillageBuildings.HOME)

func earned(id: String) -> bool:
	match id:
		"tower": return game.trials.best >= 5
		"cistern": return game.cistern.times_cleared > 0
		"adit": return game.adit.guardian_down
		"forest": return game.forestry.rank() >= 3
		"scout": return game.scout.runs_won >= 3
		"fair": return game.fair.best >= 5
	return false

func trophies() -> Array:
	var result: Array = []
	for id in TROPHIES:
		if earned(str(id)):
			result.append(str(id))
	return result

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

func enter() -> void:
	game._travel(REGION, Vector2(ROOM.get_center().x, ROOM.end.y - 26))

func leave() -> void:
	var data: Dictionary = game.settlement.building_info(VillageBuildings.HOME)
	game._travel(VILLAGE, SkywardGame._vec(data.get("position", [190, 360])) + Vector2(0, 30))

## Called when a region is built.
func populate() -> void:
	if game.current_region != REGION:
		return
	var r := ROOM
	for i in 4:
		_object(Vector2(r.position.x + 32 + 64 * i, r.position.y), "lodge_wall_window" if i == 2 else "lodge_wall").z_index = -60
	for i in 3:
		_object(Vector2(r.position.x - 8, r.end.y + 6 - 64 * i), "lodge_wall_west").z_index = -61
		_object(Vector2(r.end.x + 8, r.end.y + 6 - 64 * i), "lodge_wall_east").z_index = -61
	for i in 4:
		_object(Vector2(r.position.x + 32 + 64 * i, r.end.y + 6), "lodge_wall_front").z_index = 40
	var door := Vector2(r.get_center().x, r.end.y - 2)
	_object(door, "lodge_threshold", "", 0.0, Color(0, 0, 0, 0), true)
	_object(door + Vector2(0, -6), "", "E — выйти").used.connect(func(_o: TowerObject) -> void: leave())
	_object(r.get_center() + Vector2(0, 22), "lodge_rug", "", 0.0, Color(0, 0, 0, 0), true)
	var bed := _object(Vector2(r.position.x + 24, r.position.y + 58), "lodge_bed", "E — лечь спать до утра", 22.0)
	bed.used.connect(func(_o: TowerObject) -> void: game.buildings.sleep())
	if home_level() >= 2:
		_animated(Vector2(r.position.x + 78, r.position.y + 22), "lodge_hearth", Color(1.0, 0.62, 0.3, 0.45), 38.0)
	var wardrobe := _object(Vector2(r.end.x - 34, r.position.y + 14), "lodge_shelf", "E — гардероб: сменить облик", 28.0)
	wardrobe.used.connect(func(_o: TowerObject) -> void: change_look())
	_object(Vector2(r.end.x - 70, r.end.y - 34), "lodge_table", "", 28.0)
	_object(Vector2(r.end.x - 96, r.end.y - 28), "lodge_stool")
	_animated(Vector2(r.end.x - 70, r.end.y - 50), "lodge_candle", Color(1.0, 0.8, 0.45, 0.2)).z_index = 5
	_animated(Vector2(r.position.x + 150, r.position.y - 16), "lodge_lantern", Color(1.0, 0.75, 0.4, 0.22)).z_index = -58
	_object(Vector2(r.position.x + 24, r.end.y - 20), "lodge_chest", "", 20.0)
	# Keepsakes.
	for id in trophies():
		var info: Array = TROPHIES[id]
		var trophy := _object(r.position + (info[1] as Vector2), str(info[0]), "E — %s" % str(info[2]))
		var memory := str(info[3])
		trophy.used.connect(func(_o: TowerObject) -> void: game.hud.show_message(memory, 4.0))
	var count := trophies().size()
	if count == 0:
		game.hud.show_message("Дома тихо. Подвиги оставят здесь память: Башня, цистерна, штольня, лес, тропа, ярмарка.", 5.0)

## The wardrobe: the other look of the hero (the name stays).
func change_look() -> void:
	var player := game.player
	player.set_identity(player.hero_name, "m" if player.hero_gender == "f" else "f")
	Vfx.sparkle(game, player.global_position + Vector2(0, -16))
	GameAudio.play("pickup", -6.0, 0.2)
	game.hud.show_message("Новый облик. Гардероб всегда готов вернуть прежний.", 3.0)
