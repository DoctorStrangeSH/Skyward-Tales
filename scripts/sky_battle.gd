extends Node
class_name SkyBattle

## Этап 24: air battles. On a flight of the «Ветрокрыл» sky pirates may
## lie in wait (from the third flight on, a chance each time). The battle is
## fought in rounds at the dialogue window:
##   • «Залп из пушек» — hits the pirate ship, it answers with its own volley;
##   • «Манёвр Миры» — the next volley misses (with the storm engine — a free
##     shot on the turn);
##   • «На абордаж!» — once their ship is below 40%: the ship lands and the
##     boarders jump down after you — beat them for the captain's chest.
## The tarred hull takes a third less; the radar sees them first — you can
## go around. If our hull breaks, Mira lands as she can and the pirates take
## part of the gold. A sunk or boarded ship pays in gold and materials.

const CHANCE := 0.3
const FROM_FLIGHT := 2
const SHIPS := [
	{"name": "«Ржавая чайка»", "captain": "Капитан Сыч", "hp": 80, "volley": [7, 12]},
	{"name": "«Чёрный коршун»", "captain": "Капитан Грач", "hp": 110, "volley": [9, 15]},
	{"name": "«Буревестник»", "captain": "Капитанша Вьюга", "hp": 150, "volley": [12, 19]},
]
const BOARDERS := ["ash_cultist", "ash_cultist", "windtail", "windtail@"]

var game: SkywardGame
## Off in tests that fly for other reasons.
var enabled: bool = true
var rng := RandomNumberGenerator.new()
var active: bool = false
var destination: String = ""
var enemy: Dictionary = {}
var enemy_hp: int = 0
var hull: int = 100
var hull_max: int = 100
var evade: bool = false
var won: int = 0
var _boarders: Array = []
var _boarding: bool = false

func _ready() -> void:
	rng.randomize()

func _ship() -> SkyShip:
	return game.ship

## Called before a flight: true when pirates wait (the flight continues
## when the battle ends).
func maybe_ambush(region_id: String, force: bool = false) -> bool:
	if active or _boarding or not enabled:
		return false
	if not force and not ambush_on(_ship().flights):
		return false
	start(region_id)
	return true

## Which flights meet pirates: about three in ten, from the third on —
## fixed by the flight's number, so a reload does not reroll it.
static func ambush_on(flight: int) -> bool:
	return flight >= FROM_FLIGHT and posmod(flight * 7 + 3, 10) < roundi(CHANCE * 10.0)

func level_scale() -> float:
	return 1.0 + 0.08 * float(maxi(0, game.player.level - 6))

func start(region_id: String) -> void:
	active = true
	destination = region_id
	var tier := clampi((game.player.level - 4) / 5, 0, SHIPS.size() - 1)
	enemy = SHIPS[tier]
	enemy_hp = roundi(float(enemy["hp"]) * level_scale())
	hull_max = 100 + (40 if _ship().has_upgrade(SkyShip.HULL) else 0)
	hull = hull_max
	evade = false
	_show_view(true)
	GameAudio.play("boss_roar", -10.0, 0.2)
	if _ship().has_upgrade(SkyShip.RADAR):
		game._show_dialogue_choices("«Ветрокрыл» · радар", "Радар тревожно пищит: впереди, в облаках, — пиратский корабль %s. Они нас ещё не видят." % str(enemy["name"]), [
			{"id": "sky_fight", "label": "Атаковать первыми (их корпус −20%)"},
			{"id": "sky_around", "label": "Обойти облаками"}])
	else:
		game.hud.show_title_card("Пираты!", 2.0)
		_round("Из облаков вынырнул корабль под чёрным парусом — %s. %s орёт в рупор: «Груз за борт — и летите дальше!»" % [str(enemy["name"]), str(enemy["captain"])])

var view: SkyBattleView

func _show_view(on: bool) -> void:
	if on and (view == null or not is_instance_valid(view)):
		view = SkyBattleView.new()
		game.add_child(view)
	elif not on and view != null and is_instance_valid(view):
		view.queue_free()
		view = null

func _view_volley(side: String) -> void:
	if view != null and is_instance_valid(view):
		view.volley(side)

func _bar(value: int, total: int) -> String:
	var filled := clampi(roundi(10.0 * float(value) / float(maxi(1, total))), 0, 10)
	return "█".repeat(filled) + "░".repeat(10 - filled)

func _round(text: String) -> void:
	var choices: Array[Dictionary] = [
		{"id": "sky_volley", "label": "Залп из пушек"},
		{"id": "sky_evade", "label": "Манёвр Миры — уйти от залпа" + (" (и выстрелить)" if _ship().has_upgrade(SkyShip.ENGINE) else "")},
	]
	if enemy_hp <= roundi(float(enemy["hp"]) * level_scale() * 0.4):
		choices.append({"id": "sky_board", "label": "На абордаж! (сундук капитана)"})
	var status := "\n\n%s: %s %d\n«Ветрокрыл»: %s %d" % [str(enemy["name"]), _bar(enemy_hp, roundi(float(enemy["hp"]) * level_scale())), enemy_hp, _bar(hull, hull_max), hull]
	game._show_dialogue_choices("Небесный бой", text + status, choices)

func _our_volley() -> int:
	return roundi((18.0 + float(game.player.level) * 1.5 + rng.randf_range(0.0, 10.0)))

func _their_volley() -> int:
	var low := int(enemy["volley"][0])
	var high := int(enemy["volley"][1])
	var hit := float(rng.randi_range(low, high)) * level_scale()
	if _ship().has_upgrade(SkyShip.HULL):
		hit *= 0.66
	return maxi(1, roundi(hit))

## One round; returns what happened, for tests: "won", "lost" or "".
func act(action: String) -> String:
	if not active:
		return ""
	var text := ""
	match action:
		"volley":
			var hit := _our_volley()
			enemy_hp = maxi(0, enemy_hp - hit)
			text = "Пушки «Ветрокрыла» рявкнули — ядра проломили пиратам борт (−%d)." % hit
			_view_volley("ours")
			game.shake(3.0, 0.2)
		"evade":
			evade = true
			text = "Мира заложила крутой вираж, уводя корабль в облако."
			if _ship().has_upgrade(SkyShip.ENGINE):
				var hit := _our_volley() / 2
				enemy_hp = maxi(0, enemy_hp - hit)
				text += " Двигатель бурь вынес вас им в борт — выстрел на ходу (−%d)." % hit
	if enemy_hp <= 0:
		_win(false)
		return "won"
	if evade:
		evade = false
		text += " Их залп ушёл в пустоту."
	else:
		var back := _their_volley()
		hull = maxi(0, hull - back)
		text += " Пираты отвечают залпом: «Ветрокрыл» трещит (−%d)." % back
		_view_volley("theirs")
		game.hud.flash_screen(Color(1.0, 0.6, 0.3, 0.25), 0.2)
	if hull <= 0:
		_lose()
		return "lost"
	_round(text)
	return ""

func _loot(mult: float) -> String:
	var hero := game.player
	var gold := roundi((80.0 + 20.0 * float(hero.level)) * mult)
	hero.add_gold(gold)
	var items := {"wood": 4, "iron_ore": 3, "wind_essence": 1}
	var parts: Array[String] = ["%d золота" % gold]
	for item in items:
		var amount := roundi(float(items[item]) * mult)
		hero.add_item(item, amount)
		parts.append("%s ×%d" % [hero.get_item_name(item), amount])
	hero.add_experience(roundi((60.0 + 10.0 * float(hero.level)) * mult))
	return ", ".join(parts)

func _win(boarded: bool) -> void:
	active = false
	_show_view(false)
	won += 1
	game.achievements.add("sky_battles")
	var loot := _loot(1.6 if boarded else 1.0)
	game.hud.show_title_card("Победа в небе!", 2.2)
	game._show_dialogue("Небесный бой", ("Последний пират сдался. В сундуке капитана: " if boarded else "Пиратский корабль %s кренится и уходит вниз, в облака, теряя груз. Мира подбирает, что смогла: " % str(enemy["name"])) + loot + ".")
	if boarded:
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
			game.hud.show_message("Палуба чиста. Мира: «Держитесь — летим дальше!»", 3.0)
			_continue())
	else:
		_continue()

func _lose() -> void:
	active = false
	_show_view(false)
	var taken := mini(300, roundi(float(game.player.gold) * 0.15))
	game.player.add_gold(-taken)
	game.hud.show_title_card("«Ветрокрыл» подбит", 2.2)
	game._show_dialogue("Мира", "«Держись!» Мира с трудом выровняла корабль. Пираты взяли на абордаж кормовой трюм и забрали %d золота. Летим дальше — но я им этого не прощу." % taken)
	_continue()

func _continue() -> void:
	if not destination.is_empty():
		var region := destination
		destination = ""
		game.ship.call_deferred("fly_now", region)

## Boarding: the ship lands at the destination, the boarders follow.
const DECK := "ship_deck"
const DECK_CENTER := Vector2(400, 240)

## Boarding: the fight moves onto the deck of the «Ветрокрыл»
## (region "ship_deck"); when the deck is clear the ship flies on.
func board() -> void:
	active = false
	_show_view(false)
	_boarding = true
	game._travel(DECK, DECK_CENTER + Vector2(-120, 0))
	game.hud.show_title_card("Абордаж!", 2.0)
	game.hud.show_message("Пираты прыгают к вам на палубу! Отбейтесь — и сундук капитана ваш.", 4.0)

## Called when the deck is built: its gear, and the boarders if a fight is on.
func populate() -> void:
	if game.current_region != DECK:
		return
	for piece in [["farm_barrel", Vector2(190, 160)], ["farm_barrel", Vector2(612, 160)], ["supply_crate", Vector2(200, 320)], ["supply_crate", Vector2(600, 322)], ["tower_banner", Vector2(400, 134)], ["farm_barrel", Vector2(228, 322)]]:
		var prop := TowerObject.new()
		prop.art = str(piece[0])
		prop.wall_width = 18.0
		prop.add_to_group("region_actor")
		game.add_child(prop)
		prop.global_position = piece[1]
	if not _boarding:
		return
	_boarders.clear()
	for i in BOARDERS.size():
		var kind := str(BOARDERS[i])
		var elite := ""
		if kind.ends_with("@"):
			kind = kind.trim_suffix("@")
			elite = EliteModifiers.pick(game.loot_rng)
		var spot := DECK_CENTER + Vector2(100 + 40 * (i % 2), -60 + 40 * i)
		var foe := game.spawn_enemy(kind, spot, elite)
		if foe == null:
			continue
		foe.detection_radius = 999.0
		foe.give_up_radius = 2000.0
		foe.set_meta("boarder", true)
		_boarders.append(foe)

var _nag: float = 0.0

func _process(delta: float) -> void:
	if game == null:
		return
	# The battle goes on even if the window was closed.
	if active and not game.hud.dialogue_visible:
		_nag += delta
		if _nag > 0.4:
			_nag = 0.0
			_round("Пираты не отстают!")
		return
	if not _boarding or game.get_tree().paused or game.current_region != DECK:
		return
	_boarders = _boarders.filter(func(foe: Variant) -> bool: return is_instance_valid(foe) and not (foe as Node).is_queued_for_deletion() and (foe as SlimeEnemy).health > 0)
	if _boarders.is_empty():
		_boarding = false
		_win(true)

func handle_choice(choice_id: String) -> bool:
	if not choice_id.begins_with("sky_"):
		return false
	match choice_id:
		"sky_fight":
			enemy_hp = roundi(float(enemy_hp) * 0.8)
			_round("Вы зашли со стороны солнца — первый залп пришёлся им в мачту!")
		"sky_around":
			active = false
			_show_view(false)
			game.dialogues._close()
			game.hud.show_message("Мира увела «Ветрокрыл» в облака. Пираты остались ни с чем.", 3.0)
			_continue()
		"sky_volley":
			act("volley")
		"sky_evade":
			act("evade")
		"sky_board":
			game.dialogues._close()
			board()
	return true

func make_snapshot() -> Dictionary:
	return {"won": won}

func restore_snapshot(value: Variant) -> void:
	var saved: Dictionary = value if value is Dictionary else {}
	won = int(saved.get("won", 0))
	active = false
	_show_view(false)
	_boarding = false
	_boarders.clear()
