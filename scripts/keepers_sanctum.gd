extends Node
class_name KeepersSanctum

## Этап 24: the Keepers' Abode (region "keepers_sanctum", tools/sanctum_layout.py)
## — a story dungeon under the Sky Island and the hidden home of the last
## Keepers. A stair opens on the island after the Archive (main_archive).
##   Rune hall — six rune stones (LocationPuzzles "sanctum_runes") open the
##     first seal; the hall of singing crystals ("sanctum_crystals", a riddle
##     of the elements) opens the second; the guard hall — the Abode's stone
##     guards: when they fall, the third seal opens.
##   The Abode: Olva, keeper of the chronicle (the Keepers' story, a reward
##     for finding them; later — a Keeper's item for an ancient relic) and
##     Brother Saim, keeper of the fire (once a day a blessing: health and
##     mana restored, +10% experience until the next day).

const REGION := "keepers_sanctum"
const SEALS := {
	"sanctum_runes": [Vector2(400, 902), "Печать рун. Разбудите все шесть рун этого зала."],
	"sanctum_crystals": [Vector2(400, 622), "Печать кристаллов. Пропойте кристаллы в верном порядке — загадка на плите."],
	"sanctum_guard": [Vector2(400, 342), "Печать стражей. Она откроется, когда стражи Обители падут."],
}
const GUARD_HALL := Rect2(240, 376, 320, 208)
const RELIC := "ancient_relic"
const KEEPER_ITEMS := ["keeper_robe", "keeper_hourglass", "keeper_sigil"]

var game: SkywardGame
var found: bool = false
var blessed_day: int = -1

func here() -> bool:
	return game.current_region == REGION

const ABODE := Rect2(160, 64, 480, 240)

func _object(at: Vector2, art: String, wall: float = 0.0, glow: Color = Color(0, 0, 0, 0), flat: bool = false) -> TowerObject:
	var object := TowerObject.new()
	object.art = art
	object.wall_width = wall
	object.glow = glow
	object.flat = flat
	object.add_to_group("region_actor")
	game.add_child(object)
	object.global_position = at
	return object

## The Keepers' home: shelves of the chronicle, a fire bowl, beds, banners.
func _furnish() -> void:
	var r := ABODE
	_object(r.get_center() + Vector2(0, 20), "lodge_rug", 0.0, Color(0, 0, 0, 0), true)
	for x in [220.0, 270.0, 530.0, 580.0]:
		_object(Vector2(x, r.position.y + 14), "lodge_shelf", 28.0)
	_object(Vector2(400, r.position.y + 10), "tower_banner")
	_object(Vector2(330, 196), "lodge_table", 28.0)
	_object(Vector2(470, 196), "tower_brazier", 20.0, Color(1.0, 0.6, 0.25, 0.5))
	_object(Vector2(r.position.x + 26, r.end.y - 40), "lodge_bed", 22.0)
	_object(Vector2(r.end.x - 26, r.end.y - 40), "lodge_bed", 22.0)
	_object(Vector2(r.position.x + 30, r.position.y + 70), "memory_crystal", 16.0, Color(0.7, 0.6, 1.0, 0.4))
	_object(Vector2(r.end.x - 30, r.position.y + 70), "memory_crystal", 16.0, Color(0.7, 0.6, 1.0, 0.4))
	_object(Vector2(r.end.x - 70, r.end.y - 30), "lodge_chest", 20.0)

func populate() -> void:
	if not here():
		return
	_furnish()
	for id in SEALS:
		var door := DungeonDoor.new()
		door.door_id = str(id)
		door.levers.append(str(id))
		door.is_open = bool(game.opened_doors.get(id, false))
		door.add_to_group("region_actor")
		game.add_child(door)
		door.global_position = SEALS[id][0]
		var hint := str(SEALS[id][1])
		door.used.connect(func(_d: DungeonDoor) -> void: game.hud.show_message(hint, 3.5))

func _process(_delta: float) -> void:
	if game == null or game.get_tree().paused or not here() or bool(game.opened_doors.get("sanctum_guard", false)):
		return
	if not bool(game.opened_doors.get("sanctum_crystals", false)):
		return
	if not GUARD_HALL.has_point(game.player.global_position):
		return
	for enemy in game._living_enemies():
		if GUARD_HALL.grow(40.0).has_point(enemy.global_position):
			return
	open_guard()

func open_guard() -> void:
	game.opened_doors["sanctum_guard"] = true
	for node in game.get_children():
		if node is DungeonDoor and node.door_id == "sanctum_guard":
			node.set_open(true)
	game.shake(3.0, 0.3)
	game.hud.show_title_card("Стражи пали — печать открыта", 2.4)
	game.hud.show_message("Наверху тёплый свет и голоса. Кто-то живёт в Обители…", 4.0)
	game.request_autosave()

# --- The Keepers ------------------------------------------------------------------

func marker(npc_id: String) -> String:
	if npc_id == "keeper_olva" and not found:
		return "quest"
	if npc_id == "keeper_saim" and blessed_day != game.day_night.day:
		return "service"
	return ""

func talk(npc_id: String) -> bool:
	match npc_id:
		"keeper_olva":
			_olva()
			return true
		"keeper_saim":
			_saim()
			return true
	return false

func _olva() -> void:
	if not found:
		found = true
		game.director.set_flag("keepers_found")
		game.player.add_experience(600)
		game.player.add_gold(200)
		game.player.add_item("keeper_sigil", 1)
		game.achievements.add("keepers_found")
		game.hud.show_title_card("Обитель Хранителей", 2.6)
		game._show_dialogue("Ольва, хранительница летописи", StoryText.format("Седая женщина в мантии цвета пепла отложила перо и долго смотрела на тебя. «Значит, печати пали. Сорок лет никто не проходил наши залы, {hero}. Когда Узор треснул, Хранители разошлись: одни ушли в небо, другие — в землю. Мы, последние, остались здесь — беречь летопись. Я записала каждый день. Теперь запишу и тебя». Она протянула печать Хранителя. «Носи. Наши двери отныне открыты для тебя. А если найдёшь в руинах древние вещи — неси мне: я знаю, что из них сделать».\n\nНайдено: 600 опыта, 200 золота, Печать Хранителя."))
		game.update_npc_markers()
		game.request_autosave()
		return
	var choices: Array[Dictionary] = []
	var relics := int(game.player.inventory.get(RELIC, 0))
	for item_id in KEEPER_ITEMS:
		choices.append({"id": "sanctum_trade:" + item_id, "label": "%s%s — древний артефакт (%d)" % ["" if relics > 0 else "✗ ", game.player.get_item_name(item_id), relics]})
	choices.append({"id": "sanctum_lore", "label": "Расскажи о Хранителях"})
	choices.append({"id": "sanctum_bye", "label": "До встречи"})
	game._show_dialogue_choices("Ольва, хранительница летописи", "«Принёс%s древнее? Из одного артефакта я сделаю вещь Хранителей — какую выберешь»." % ("ла" if StoryText.hero_gender == "f" else ""), choices)

const LORE := [
	"«Узор — это не стена и не клетка. Это сеть, что держит острова в небе. Мы её чинили, пока могли».",
	"«Вейл был одним из нас. Лучшим. Он решил, что Узор надо не чинить, а переписать. Мы спорили до хрипоты — а потом он ушёл».",
	"«Корни под землёй и мы в небе — две половины одного ордена. Говорят, Круг Земных Корней до сих пор помнит старые клятвы».",
	"«Летопись говорит: острова падали и раньше. И раньше находился кто-то, кто их поднимал. Может, теперь это ты».",
]
var _lore_index: int = 0

func _saim() -> void:
	if blessed_day == game.day_night.day:
		game._show_dialogue("Брат Сайм, страж огня", "Огонь уже коснулся тебя сегодня. Приходи завтра — он не угаснет.")
		return
	game._show_dialogue_choices("Брат Сайм, страж огня", "Старик подбросил в чашу горсть искр. «Огонь Хранителей не жжёт своих. Подойди — он вернёт силы и на день сделает зорче»."
		, [{"id": "sanctum_bless", "label": "Принять благословение огня"}, {"id": "sanctum_bye", "label": "В другой раз"}])

func bless() -> bool:
	if blessed_day == game.day_night.day:
		return false
	blessed_day = game.day_night.day
	var hero := game.player
	hero.health = hero.max_health
	hero.mana = hero.max_mana
	hero.stats_changed.emit()
	game.world_state.set_state("keeper_blessing", 1.0)
	Vfx.sparkle(game, hero.global_position)
	game.hud.show_message("Благословение огня: силы восстановлены, +10% опыта до завтра.", 3.5)
	GameAudio.play("level_up", -6.0, 0.2)
	game.update_npc_markers()
	return true

func trade(item_id: String) -> bool:
	if not item_id in KEEPER_ITEMS or int(game.player.inventory.get(RELIC, 0)) <= 0:
		return false
	game.player.remove_item(RELIC, 1)
	game.player.add_item(item_id, 1)
	game.hud.show_message("Ольва колдует над артефактом… Получено: %s." % game.player.get_item_name(item_id), 3.5)
	GameAudio.play("quest", -4.0, 0.0)
	return true

func handle_choice(choice_id: String) -> bool:
	if not choice_id.begins_with("sanctum_"):
		return false
	if choice_id == "sanctum_bye":
		game.dialogues._close()
	elif choice_id == "sanctum_bless":
		game.dialogues._close()
		bless()
	elif choice_id == "sanctum_lore":
		game._show_dialogue("Ольва, хранительница летописи", str(LORE[_lore_index % LORE.size()]))
		_lore_index += 1
	elif choice_id.begins_with("sanctum_trade:"):
		if trade(choice_id.trim_prefix("sanctum_trade:")):
			game.dialogues._close()
		else:
			game.hud.show_message("Нужен древний артефакт — их находят в руинах и глубоких подземельях.", 3.0)
	return true

func make_snapshot() -> Dictionary:
	return {"found": found, "blessed_day": blessed_day}

func restore_snapshot(value: Variant) -> void:
	var saved: Dictionary = value if value is Dictionary else {}
	found = bool(saved.get("found", false))
	blessed_day = int(saved.get("blessed_day", -1))
