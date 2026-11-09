extends RefCounted
class_name BranStory

## Bran the merchant's own story (stage 20): a shop that flies. After
## «Потерянные поставки», from level 7:
##   bran_hull    — «Корпус для лавки»: 10 logs, 6 iron ore, 2 wind essences;
##   bran_charter — «Торговая грамота»: the Free Port's quartermaster Bruno
##                  must write a trading charter (300 gold — or a golden
##                  fish, which Bruno cannot resist).
## Then the flying shop «Ласточка» lifts off over the village (a scene on
## the engine, flag "bran_ship"): it hovers above the market from now on,
## and Bran sells «товары с островов» — three rare or epic pieces a day,
## plus rare materials — and keeps a 10% discount for the hero.

const SPEAKER := "Торговец Бран"
const NPC := "merchant"
const BRUNO := "port_quartermaster"
const BRUNO_NAME := "Бруно, квартирмейстер"
const HULL := "bran_hull"
const CHARTER := "bran_charter"
const FLAG := "bran_ship"
const MIN_LEVEL := 7
const NEEDS := {"wood": 10, "iron_ore": 6, "wind_essence": 2}
const FEE := 300
const SHIP_SPOT := Vector2(700, 700)
## Rare materials on board: id → price.
const MATERIALS := {"wind_essence": 90, "starlight_essence": 260, "obsidian_shard": 120, "whetstone": 60}

var game: SkywardGame
## Pieces bought today (indices into today's stock) and the day they belong to.
var bought: Array = []
var bought_day: int = -1

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

func make_snapshot() -> Dictionary:
	return {"bought": bought.duplicate(), "day": bought_day}

func restore_snapshot(data: Variant) -> void:
	bought = []
	bought_day = -1
	if data is Dictionary:
		bought = (data.get("bought", []) as Array).duplicate()
		bought_day = int(data.get("day", -1))

func flying() -> bool:
	return game.director.has_flag(FLAG)

func _q() -> QuestManager:
	return game.quests

func _fresh(id: String) -> bool:
	return not bool(_q().states.get(id, {}).get("started", false)) and not _q().is_completed(id)

func can_offer_hull() -> bool:
	return _q().is_completed("bran_supply_run") and game.player.level >= MIN_LEVEL and _fresh(HULL)

func has_materials() -> bool:
	for item in NEEDS:
		if int(game.player.inventory.get(item, 0)) < int(NEEDS[item]):
			return false
	return true

func sync_progress() -> void:
	if _q().is_active(HULL):
		var done := 0
		for item in NEEDS:
			if int(game.player.inventory.get(item, 0)) >= int(NEEDS[item]):
				done += 1
		_q().states[HULL]["progress"] = done

func marker(npc_id: String) -> String:
	if npc_id == NPC:
		if (_q().is_active(HULL) and has_materials()) or _q().is_ready_to_complete(CHARTER):
			return "ready"
		if can_offer_hull():
			return "quest"
	elif npc_id == BRUNO and _q().is_active(CHARTER) and not _q().is_ready_to_complete(CHARTER):
		return "ready"
	return ""

## True when Bran's story took the conversation (the shop stays one choice away).
func talk(npc_id: String) -> bool:
	var q := _q()
	if npc_id == BRUNO:
		if not q.is_active(CHARTER) or q.is_ready_to_complete(CHARTER):
			return false
		var choices: Array[Dictionary] = [{"id": "bran_fee", "label": "Заплатить пошлину — %d золота" % FEE}]
		if int(game.player.inventory.get("golden_fish", 0)) > 0:
			choices.append({"id": "bran_fish", "label": "Предложить золотую рыбку"})
		choices.append({"id": "bran_later", "label": "Позже"})
		game.talk_line(BRUNO, BRUNO_NAME, [
			{"text": "Бруно выслушал, не поднимая глаз от счётной книги. Перо у него было из чаячьего хвоста, а чернила пахли ромом."},
			{"speaker": "self", "text": "Летающая лавка, значит. Бран… Помню Брана. Он однажды продал мне компас, который показывал на ближайший пирог. Лучший компас в моей жизни."},
			{"speaker": "self", "text": "Грамоту дам. Пристань берёт пошлину — %d золотом. Таков закон. Ну, или… я давно мечтаю о золотой рыбке для конторы. Рыбка — тоже закон." % FEE},
		], choices)
		return true
	if npc_id != NPC:
		return false
	if q.is_active(HULL):
		if has_materials():
			_finish_hull()
		else:
			game._show_dialogue_choices(SPEAKER, "Для корпуса: брёвна — %d из 10, железная руда — %d из 6, эссенция ветра — %d из 2. Сухие брёвна рубят в лесу у деревни, ветер ловят на островах." % [mini(10, int(game.player.inventory.get("wood", 0))), mini(6, int(game.player.inventory.get("iron_ore", 0))), mini(2, int(game.player.inventory.get("wind_essence", 0)))],
				[{"id": "bran_shop", "label": "Открыть лавку"}, {"id": "bran_later", "label": "Уйти"}])
		return true
	if q.is_ready_to_complete(CHARTER):
		_launch()
		return true
	if q.is_active(CHARTER):
		game._show_dialogue_choices(SPEAKER, "Грамоту пишет Бруно, квартирмейстер Вольной пристани. Он ворчит, но перо у него доброе.", [{"id": "bran_shop", "label": "Открыть лавку"}, {"id": "bran_later", "label": "Уйти"}])
		return true
	if can_offer_hull():
		game.talk_line(NPC, SPEAKER, [
			{"text": "Бран стоял за прилавком и смотрел не на товар, а в небо — туда, где над лесом плыли острова. Счёты лежали забытые."},
			{"speaker": "self", "text": "Знаешь, {hero}, сорок лет я жду караваны. Дождь — нет каравана. Тварь на дороге — нет каравана. А острова — вот они, над головой, и на каждом кто-то чего-то хочет купить."},
			{"speaker": "self", "text": "Хочу лавку, которая летает. Маленькую, пузатую, с навесом. Назову «Ласточкой». Для корпуса нужны десять брёвен, шесть кусков железной руды и две эссенции ветра — чтобы держалась в воздухе. Поможешь?"},
		], [{"id": "bran_accept:hull", "label": "Помогу построить «Ласточку»"}, {"id": "bran_shop", "label": "Сначала — лавка"}, {"id": "bran_later", "label": "Позже"}])
		return true
	return false

func _finish_hull() -> void:
	for item in NEEDS:
		game.player.remove_item(item, int(NEEDS[item]))
	_q().states[HULL]["progress"] = NEEDS.size()
	_q().complete_quest(HULL)
	game.npc_reward(HULL)
	game.talk_line(NPC, SPEAKER, [
		{"text": "Корпус собирали всей деревней. Борин выковал скобы, Ярош обтесал брёвна, дети таскали гвозди и тут же их теряли. Через три дня за лавкой стояла «Ласточка» — круглая, как бочка, с полосатым навесом."},
		{"speaker": "self", "text": "Красавица, а? Осталась мелочь: торговая грамота. Без неё в небе любая лавка — контрабанда. Грамоты пишет Бруно, квартирмейстер Вольной пристани. Слетаешь к нему?"},
	], [{"id": "bran_accept:charter", "label": "Слетаю к Бруно"}, {"id": "bran_later", "label": "Позже"}])

func _launch() -> void:
	_q().complete_quest(CHARTER)
	game.npc_reward(CHARTER)
	game.director.set_flag(FLAG)
	var ship := populate()
	if ship != null:
		ship.rise = 0.0
		ship.create_tween().tween_property(ship, "rise", 1.0, 3.5).set_delay(1.4).set_trans(Tween.TRANS_SINE)
	game.story.play_steps([
		{"text": "Бран прочёл грамоту трижды. Потом сложил её вчетверо, спрятал за пазуху и похлопал по груди, как по кошельку."},
		{"speaker": "self", "text": "Ну, «Ласточка». Не подведи старика."},
		{"effect": "camera", "to": [SHIP_SPOT.x, SHIP_SPOT.y - 40], "zoom": 0.85, "time": 1.4},
		{"text": "Канаты ослабли. Лавка качнулась, скрипнула — и пошла вверх, медленно, будто раздумывая. Над рынком закачался полосатый навес, а с борта посыпались яблоки: Бран забыл закрыть ящик."},
		{"text": "Вся деревня стояла задрав головы. Кто-то захлопал. Потом захлопали все."},
		{"effect": "camera_back", "time": 1.0},
		{"speaker": "self", "text": "Теперь у меня товары с островов — каждый день новые! А для тебя, {hero}, — скидка навсегда. Без тебя «Ласточка» так и осталась бы рисунком на прилавке."},
	], NPC, SPEAKER, func() -> void:
		game.update_npc_markers()
		game._refresh_hud(), true)

func handle_choice(choice_id: String) -> bool:
	var q := _q()
	match choice_id:
		"bran_later":
			game.dialogues._close()
			return true
		"bran_shop":
			game.dialogues._close()
			game.dialogues.open_bran_shop()
			return true
		"bran_accept:hull":
			game.dialogues._close()
			q.start_quest(HULL)
			sync_progress()
			game.hud.show_message("Новое задание: Корпус для лавки", 3.0)
			game.update_npc_markers()
			game._refresh_hud()
			return true
		"bran_accept:charter":
			game.dialogues._close()
			q.start_quest(CHARTER)
			game.hud.show_message("Новое задание: Торговая грамота — Бруно в Вольной пристани", 3.5)
			game.update_npc_markers()
			game._refresh_hud()
			return true
		"bran_fee":
			if game.player.gold < FEE:
				game._show_dialogue(BRUNO_NAME, "Пошлина — %d золотом, ни монетой меньше. Приходи, когда кошелёк потяжелеет." % FEE)
				return true
			game.player.add_gold(-FEE)
			_charter_written("Бруно пересчитал монеты дважды, кивнул и вывел грамоту красивым почерком с завитушками. Печать он подышал и прижал с таким звуком, будто захлопнул сундук.")
			return true
		"bran_fish":
			if not game.player.remove_item("golden_fish", 1):
				return true
			_charter_written("Бруно взял рыбку двумя руками, как новорождённого. «Её зовут Пошлина», — сказал он торжественно и выписал грамоту, не взяв ни монеты.")
			return true
	if choice_id.begins_with("bran_isle:"):
		_buy_isle(int(choice_id.trim_prefix("bran_isle:")))
		return true
	if choice_id.begins_with("bran_mat:"):
		var item_id := choice_id.trim_prefix("bran_mat:")
		var price := int(MATERIALS.get(item_id, 0))
		if price > 0 and game.player.gold >= price:
			game.player.add_gold(-price)
			game.player.add_item(item_id)
			GameAudio.play("pickup", -6.0)
			game.hud.show_message("Куплено: %s" % game.player.get_item_name(item_id), 2.0)
		else:
			game.hud.show_message("Не хватает золота.", 1.8)
		open_isle_shop()
		return true
	if choice_id == "bran_isle_menu":
		open_isle_shop()
		return true
	return false

func _charter_written(line: String) -> void:
	_q().add_progress(CHARTER, 1)
	game.talk_line(BRUNO, BRUNO_NAME, [{"text": line}, {"speaker": "self", "text": "Передай Брану: если «Ласточка» залетит в Пристань — пусть швартуется у моей конторы. Пироги у нас тоже есть."}])
	game.hud.show_message("Грамота у вас — отнесите её Брану.", 3.0)
	game.update_npc_markers()
	game._refresh_hud()

# --- Goods from the islands -------------------------------------------------

## Today's three pieces: rare or epic, for the hero's level (deterministic).
func stock() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("lastochka:%d:%d" % [game.day_night.day, game.player.level / 3])
	var out: Array[Dictionary] = []
	for i in 3:
		var rarity := "epic" if rng.randf() < 0.3 else "rare"
		var definition := LootGenerator.generate(rng, game.player.level, rarity)
		if definition.is_empty():
			continue
		var price := (260 if rarity == "rare" else 620) + 18 * game.player.level
		out.append({"definition": definition, "price": int(price * 0.9), "rarity": rarity})
	return out

func _refresh_day() -> void:
	if bought_day != game.day_night.day:
		bought_day = game.day_night.day
		bought = []

func open_isle_shop() -> void:
	_refresh_day()
	var choices: Array[Dictionary] = []
	var goods := stock()
	for i in goods.size():
		var entry: Dictionary = goods[i]
		var name := str(entry["definition"].get("name", "?"))
		var tag := "эпическое" if entry["rarity"] == "epic" else "редкое"
		if bought.has(i):
			choices.append({"id": "bran_isle_menu", "label": "✓ %s — продано" % name})
		else:
			choices.append({"id": "bran_isle:%d" % i, "label": "%s (%s) — %d золота" % [name, tag, int(entry["price"])]})
	for item_id in MATERIALS:
		choices.append({"id": "bran_mat:" + item_id, "label": "%s — %d золота" % [game.player.get_item_name(item_id), int(MATERIALS[item_id])]})
	choices.append({"id": "bran_later", "label": "Уйти"})
	game._show_dialogue_choices(SPEAKER, "Товары с островов — сегодня такие, завтра другие. Для тебя со скидкой, {hero}.", choices)

func _buy_isle(index: int) -> void:
	_refresh_day()
	var goods := stock()
	if index < 0 or index >= goods.size() or bought.has(index):
		open_isle_shop()
		return
	var entry: Dictionary = goods[index]
	if game.player.gold < int(entry["price"]):
		game.hud.show_message("Не хватает золота.", 1.8)
		open_isle_shop()
		return
	game.player.add_gold(-int(entry["price"]))
	var item_id := game.player.register_generated_item(entry["definition"])
	game.player.add_item(item_id)
	bought.append(index)
	GameAudio.play("chest", -8.0)
	game.hud.show_message("Куплено: %s" % game.player.get_item_name(item_id), 2.5)
	game._refresh_hud()
	open_isle_shop()

# --- «Ласточка» over the market ----------------------------------------------

func populate() -> FlyingShop:
	if game.current_region != "greenreach" or not flying():
		return null
	for actor in game.get_children():
		if actor is FlyingShop and not actor.is_queued_for_deletion():
			return actor
	var ship := FlyingShop.new()
	game.add_child(ship)
	ship.global_position = SHIP_SPOT
	return ship

## The flying shop hovering above the market (art: tools/art/personal_art.py).
## High above the ground: no collision, a soft shadow below.
class FlyingShop extends Node2D:
	var _sprite: Sprite2D
	var _shadow: Polygon2D
	var _clock := 0.0
	var rise := 1.0

	func _ready() -> void:
		add_to_group("region_actor")
		z_index = 20
		_shadow = Polygon2D.new()
		var points := PackedVector2Array()
		for i in 16:
			points.append(Vector2(cos(TAU * i / 16.0) * 26.0, sin(TAU * i / 16.0) * 7.0))
		_shadow.polygon = points
		_shadow.color = Color(0, 0, 0, 0.18)
		_shadow.z_index = -19
		add_child(_shadow)
		_sprite = Sprite2D.new()
		_sprite.texture = load("res://assets/world_hd/sky_shop_lastochka.png")
		_sprite.scale = Vector2(0.5, 0.5)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_sprite)

	func _process(delta: float) -> void:
		_clock += delta
		var height := lerpf(10.0, 62.0, rise)
		_sprite.position = Vector2(0, -height + sin(_clock * 1.3) * 2.5)
		_sprite.rotation = sin(_clock * 0.9) * 0.02
		_shadow.scale = Vector2.ONE * lerpf(1.0, 0.8, rise)
		# See-through while the hero walks under it.
		var game := get_parent() as SkywardGame
		var under := false
		if game != null and game.player != null:
			var d := game.player.global_position - (global_position + _sprite.position)
			under = absf(d.x) < 34.0 and d.y > -30.0 and d.y < 34.0
		_sprite.modulate.a = move_toward(_sprite.modulate.a, 0.4 if under else 1.0, delta * 3.0)
