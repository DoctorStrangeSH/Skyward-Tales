extends Node
class_name SkyShip

## «Ветрокрыл», the Keepers' last sky ship (Этап 16).
##   ship_wreck  — Sol, the anchor keeper in Haven, tells of the wreck on the
##                 Salt Coast (after the first act); the hero examines it;
##   ship_repair — Yar the carpenter fixes it for wood, ore and wind essence.
## Then the ship (flag "ship_ready") waits at every dock (regions.json →
## "dock") and flies between them; Mira rides along as navigator and has a
## word about every place. The sky has its own weather, changing every half
## day: clear, thunderstorm or fog. Upgrades open two islands found nowhere
## else: the storm engine flies into a thunderstorm to «Грозовой остров»
## (lightning strikes, the Storm Warden), the radar finds «Остров-мираж» in
## the fog (Veira, the Keepers' navigator, and the mirage cloak).

const WRECK := "ship_wreck"
const REPAIR := "ship_repair"
const READY_FLAG := "ship_ready"
const ENGINE := "ship_engine"
const RADAR := "ship_radar"
const WARDEN_FLAG := "storm_warden_defeated"
const SOL := "haven_anchor"
const YAR := "haven_villager_b"
const REQUIRES := "main_echo"
const REPAIR_MATERIALS := {"wood": 15, "iron_ore": 8, "wind_essence": 3}
const ENGINE_COST := {"gold": 700, "materials": {"iron_ore": 10, "wind_essence": 5}}
const RADAR_COST := {"gold": 600, "materials": {"gear_cog": 4, "shadow_essence": 3}}
const ROUTE := ["salt_coast", "haven", "sky_island", "wind_spires", "sky_rift", "sky_heart", "storm_isle", "mirage_isle"]
const WEATHER := {"clear": "Ясно", "storm": "Гроза", "fog": "Туман"}
const MIRA := {
	"salt_coast": "Солёный берег! Отсюда «Ветрокрыл» ушёл в последний рейс. Теперь — в первый.",
	"haven": "Гавань с высоты — как ладонь с вишнёвыми цветами. Тиша машет нам!",
	"sky_island": "Архив… Ориэн, наверное, опять не спит над свитками.",
	"wind_spires": "Шпили поют, когда мы пролетаем. Слышишь? Это они нас узнали.",
	"sky_rift": "Держись крепче — над Расколотым островом всегда болтает.",
	"sky_heart": "Сердце неба. Отсюда видно все острова сразу — я дорисую карту!",
	"storm_isle": "Двигатель держит! {hero}, мы прошли сквозь грозу. Смотри под ноги — молнии бьют без предупреждения… почти.",
	"mirage_isle": "Его нет ни на одной карте… кроме моей. Значит, я не выдумала этот остров!",
}

var game: SkywardGame
var flights: int = 0
var _view: SkyShipView
var _overlay: WeatherOverlay
var _storm_clock: float = 2.0
var _bolt_clock: float = 6.0
var _flying: bool = false

# --- State --------------------------------------------------------------

func is_ready() -> bool:
	return game.director.has_flag(READY_FLAG)

func has_upgrade(flag: String) -> bool:
	return game.director.has_flag(flag)

func dock(region_id: String) -> Variant:
	return RegionCatalog.get_region(region_id).get("dock", null)

## The sky's weather for a half-day slot (today's by default).
func weather(slot: int = -1) -> String:
	if slot < 0:
		slot = current_slot()
	var rng := RandomNumberGenerator.new()
	rng.seed = slot * 7919 + 13
	var roll := rng.randf()
	if roll < 0.4:
		return "clear"
	return "storm" if roll < 0.7 else "fog"

func current_slot() -> int:
	return game.day_night.day * 2 + (1 if game.day_night.time >= 0.5 else 0)

func forecast_text() -> String:
	var now := current_slot()
	return "Погода в небе: %s, дальше — %s." % [WEATHER[weather(now)], str(WEATHER[weather(now + 1)]).to_lower()]

## "" when the ship can fly there now, otherwise why not.
func blocked(region_id: String) -> String:
	if region_id == game.current_region:
		return "вы здесь"
	match region_id:
		"storm_isle":
			if not has_upgrade(ENGINE):
				return "нужен двигатель бурь"
			if weather() != "storm":
				return "ждите грозы"
		"mirage_isle":
			if not has_upgrade(RADAR):
				return "нужен радар"
			if weather() != "fog":
				return "виден лишь в тумане"
		_:
			if not game.visited_regions.has(region_id):
				return "путь ещё не известен"
	return ""

# --- Story: Sol and Yar ---------------------------------------------------

func can_offer() -> bool:
	var q := game.quests
	return q.is_completed(REQUIRES) and not bool(q.states.get(WRECK, {}).get("started", false)) and not q.is_completed(WRECK)

func materials_ready() -> int:
	var count := 0
	for item_id in REPAIR_MATERIALS:
		if int(game.player.inventory.get(item_id, 0)) >= int(REPAIR_MATERIALS[item_id]):
			count += 1
	return count

func sync_progress() -> void:
	if game.quests.is_active(REPAIR):
		game.quests.states[REPAIR]["progress"] = materials_ready()

func marker(npc_id: String) -> String:
	var q := game.quests
	if npc_id == SOL:
		if q.is_ready_to_complete(WRECK):
			return "ready"
		if can_offer():
			return "quest"
	if npc_id == YAR and q.is_active(REPAIR) and materials_ready() >= REPAIR_MATERIALS.size():
		return "ready"
	return ""

## True when the ship story took the conversation.
func talk(npc_id: String) -> bool:
	var q := game.quests
	if npc_id == SOL:
		if q.is_ready_to_complete(WRECK):
			q.complete_quest(WRECK)
			game.npc_reward(WRECK)
			q.start_quest(REPAIR)
			sync_progress()
			game._show_dialogue("Сол, хранитель якоря", "Значит, корпус цел… Тогда иди к Яру. Он, прежде чем строить дома, строил лодки для небесных рыбаков. Яр починит «Ветрокрыл», если добудешь дерево, руду и эссенцию ветра.")
			return true
		if can_offer():
			game._show_dialogue_choices("Сол, хранитель якоря", "Видишь цепь? Её привёз «Ветрокрыл» — последний корабль Хранителей. Он разбился на Солёном берегу, когда орден уходил. Элиан говорил: пока корабль цел, у неба есть надежда. Взглянешь на него?", [
				{"id": "ship_accept", "label": "Найду «Ветрокрыл»"},
				{"id": "ship_later", "label": "Позже"}])
			return true
		if q.is_active(WRECK):
			game._show_dialogue("Сол, хранитель якоря", "Обломки на западе Солёного берега, у самой воды. Мачту видно издалека.")
			return true
		if is_ready():
			game._show_dialogue("Сол, хранитель якоря", "«Ветрокрыл» снова в небе… Элиан бы улыбнулся. Береги его, капитан.")
			return true
	if npc_id == YAR:
		if q.is_active(REPAIR):
			sync_progress()
			if materials_ready() >= REPAIR_MATERIALS.size():
				_finish_repair()
			else:
				game._show_dialogue("Плотник Яр", "Для «Ветрокрыла» нужно: %s. Дерево — у лесорубных пней, руда — в пещерах и на Перевале, эссенция ветра — у блуждающих огоньков." % _materials_text())
			return true
		if is_ready():
			var choices: Array[Dictionary] = []
			if not has_upgrade(ENGINE):
				choices.append({"id": "ship_upgrade:engine", "label": "Двигатель бурь — %s" % game.borin.cost_text(ENGINE_COST)})
			if not has_upgrade(RADAR):
				choices.append({"id": "ship_upgrade:radar", "label": "Радар скрытых островов — %s" % game.borin.cost_text(RADAR_COST)})
			if choices.is_empty():
				game._show_dialogue("Плотник Яр", "Корабль в полном порядке: двигатель гудит, радар слушает. Лучше, чем при Хранителях!")
				return true
			choices.append({"id": "ship_later", "label": "Позже"})
			game._show_dialogue_choices("Плотник Яр", "Корабль летает, но можно лучше. Двигатель бурь пронесёт сквозь грозу, а радар услышит острова, спрятанные в тумане.", choices)
			return true
	return false

func _materials_text() -> String:
	var parts: Array[String] = []
	for item_id in REPAIR_MATERIALS:
		var have := int(game.player.inventory.get(item_id, 0))
		parts.append("%s %d/%d" % [game.player.get_item_name(item_id), mini(have, int(REPAIR_MATERIALS[item_id])), int(REPAIR_MATERIALS[item_id])])
	return ", ".join(parts)

func _finish_repair() -> void:
	for item_id in REPAIR_MATERIALS:
		game.player.remove_item(item_id, int(REPAIR_MATERIALS[item_id]))
	game.quests.states[REPAIR]["progress"] = REPAIR_MATERIALS.size()
	game.quests.complete_quest(REPAIR)
	game.npc_reward(REPAIR)
	game.director.set_flag(READY_FLAG)
	game.hud.show_title_card("«Ветрокрыл» снова в небе", 3.0)
	game._show_dialogue("Плотник Яр", "Готово! Новый киль, заплаты на оболочке, а пропеллер вертится как в молодости. Корабль ждёт у Солёного берега — и у любого причала, где ты его позовёшь. Мира уже выпросила место штурмана.")
	game.update_npc_markers()
	game.request_autosave()

func upgrade(kind: String) -> bool:
	var flag := ENGINE if kind == "engine" else RADAR
	var cost: Dictionary = ENGINE_COST if kind == "engine" else RADAR_COST
	if has_upgrade(flag) or not game.player.can_pay(cost):
		return false
	game.player.add_gold(-int(cost["gold"]))
	var materials: Dictionary = cost["materials"]
	for material in materials:
		game.player.remove_item(str(material), int(materials[material]))
	game.director.set_flag(flag)
	game.hud.show_title_card("Двигатель бурь установлен" if kind == "engine" else "Радар скрытых островов", 2.5)
	game.request_autosave()
	return true

func handle_choice(choice_id: String) -> bool:
	if choice_id == "ship_accept":
		game.quests.start_quest(WRECK)
		game.hud.show_message("Задание: Последний корабль. Обломки — на Солёном берегу.", 3.5)
		_close()
		return true
	if choice_id == "ship_later":
		_close()
		return true
	if choice_id.begins_with("ship_upgrade:"):
		var kind := choice_id.trim_prefix("ship_upgrade:")
		if upgrade(kind):
			game._show_dialogue("Плотник Яр", "Ставлю! Через час будет как новенький." if kind == "engine" else "Радар из старых шестерёнок и теней — звучит странно, но слышит он всё.")
		else:
			game._show_dialogue("Плотник Яр", "Не хватает материалов или золота: %s." % game.borin.cost_text(ENGINE_COST if kind == "engine" else RADAR_COST))
		return true
	if choice_id.begins_with("ship_fly:"):
		_close()
		fly(choice_id.trim_prefix("ship_fly:"))
		return true
	return false

func _close() -> void:
	game.hud.close_dialogue()
	game.player.set_physics_process(true)
	game._refresh_hud()

# --- The ship at the dock ---------------------------------------------------

## Builds the dock for the region (called from _populate_region).
func populate() -> void:
	_view = null
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	var spot: Variant = dock(game.current_region)
	if spot is Array:
		if is_ready():
			_view = SkyShipView.new()
			_view.wrecked = false
		elif game.current_region == "salt_coast":
			_view = SkyShipView.new()
			_view.wrecked = true
		if _view != null:
			game.add_child(_view)
			_view.global_position = Vector2(float(spot[0]), float(spot[1]))
			_view.used.connect(_on_ship_used)
	match game.current_region:
		"storm_isle":
			_overlay = WeatherOverlay.new()
			_overlay.mode = "storm"
			game.add_child(_overlay)
			if not game.director.has_flag(WARDEN_FLAG):
				_spawn_warden()
		"mirage_isle":
			_overlay = WeatherOverlay.new()
			_overlay.mode = "fog"
			game.add_child(_overlay)
			for node in game.get_children():
				if node is WorldNpc and node.npc_id == "mirage_keeper":
					node.modulate = Color(0.8, 0.92, 1.25, 0.72)
			if game.achievements.stats.get("mirage_found", 0) == 0:
				game.achievements.add("mirage_found")

func _on_ship_used() -> void:
	if _view == null:
		return
	if _view.wrecked:
		_examine_wreck()
		return
	open_menu()

func _examine_wreck() -> void:
	var q := game.quests
	if q.is_active(WRECK) and not q.is_ready_to_complete(WRECK):
		q.add_progress(WRECK, 1)
		game._show_dialogue("Мира", "Это он, {hero}! «Ветрокрыл». Корпус цел, оболочка порвана, но киль… киль живой. Его можно починить! Расскажем Солу?")
		game.update_npc_markers()
		game.request_autosave()
		return
	var entry: Dictionary = game.lore.entry("lore_wreck")
	game.lore.mark("lore_wreck", "salt_coast")
	game._show_dialogue(str(entry.get("title", "Обломки корабля")), str(entry.get("text", "Старый корабль врос в песок. На борту — полустёртая надпись «Ветрокрыл».")))

func open_menu() -> void:
	var choices: Array[Dictionary] = []
	for region_id in ROUTE:
		if dock(region_id) == null or region_id == game.current_region:
			continue
		var reason := blocked(region_id)
		if region_id in ["storm_isle", "mirage_isle"] and reason == "нужен радар" and not has_upgrade(RADAR):
			continue  # the hidden island is unknown until the radar hears it
		var title := RegionCatalog.display_name(region_id)
		choices.append({"id": "ship_fly:" + region_id if reason.is_empty() else "ship_later", "label": ("➤ " + title) if reason.is_empty() else "%s — %s" % [title, reason]})
	choices.append({"id": "ship_later", "label": "Остаться на земле"})
	game._show_dialogue_choices("«Ветрокрыл»", "Мира у штурвала разворачивает карту. %s Куда летим, капитан?" % forecast_text(), choices)

func fly(region_id: String) -> bool:
	var spot: Variant = dock(region_id)
	if _flying or not is_ready() or spot == null or not blocked(region_id).is_empty():
		return false
	_flying = true
	var transition := FlightTransition.new()
	transition.title = "«Ветрокрыл» · курс на %s" % RegionCatalog.display_name(region_id)
	transition.storm = region_id == "storm_isle"
	game.add_child(transition)
	transition.midpoint.connect(func() -> void:
		game._travel(region_id, Vector2(float(spot[0]), float(spot[1])) + Vector2(0, 26))
		flights += 1
		game.achievements.add("ship_flights"))
	transition.finished.connect(func() -> void:
		_flying = false
		game.hud.show_message("Мира: " + StoryText.format(str(MIRA.get(region_id, "Приземлились!"))), 4.5))
	return true

## Instant flight for tests and save loading (no transition).
func fly_now(region_id: String) -> bool:
	var spot: Variant = dock(region_id)
	if not is_ready() or spot == null or not blocked(region_id).is_empty():
		return false
	game._travel(region_id, Vector2(float(spot[0]), float(spot[1])) + Vector2(0, 26))
	flights += 1
	game.achievements.add("ship_flights")
	return true

# --- Grozovoy island: the warden and lightning ------------------------------

func _spawn_warden() -> void:
	var enemy := game.spawn_enemy("sentinel", Vector2(640, 260), "fierce")
	if enemy == null:
		return
	enemy.set_meta("storm_warden", true)
	enemy.max_health = roundi(enemy.max_health * 5.0)
	enemy.health = enemy.max_health
	enemy.attack_damage = roundi(enemy.attack_damage * 1.3)
	enemy.xp_reward = roundi(enemy.xp_reward * 4.0)
	enemy.knockback_resist = maxf(enemy.knockback_resist, 0.85)
	enemy.visual.scale *= 1.7
	enemy.combat_feedback.elite = true
	enemy.combat_feedback.elite_name = "♦ Грозовой страж"
	enemy.combat_feedback.elite_color = Color(0.7, 0.85, 1.0)
	enemy.combat_feedback.bar_y *= 1.7
	enemy.base_visual_tint = Color(0.7, 0.8, 1.1)
	enemy.visual.modulate = enemy.base_visual_tint
	enemy.combat_feedback.set_health(enemy.health, enemy.max_health)
	enemy.defeated.connect(func(_xp: int) -> void: _on_warden_down(enemy.global_position))

func _on_warden_down(at: Vector2) -> void:
	if game.director.has_flag(WARDEN_FLAG):
		return
	game.director.set_flag(WARDEN_FLAG)
	game.achievements.add("storm_warden")
	game._spawn_loot(at, "storm_crown")
	game._spawn_loot(at + Vector2(-18, 10), "gold").amount = 450
	game._spawn_loot(at + Vector2(18, 10), VillageBuildings.TOME)
	game.spawn_generated_loot(at + Vector2(0, 22), "epic")
	game.shake(6.0, 0.5)
	game.hud.show_title_card("Гроза стихает", 2.5)
	game.request_autosave()

func _process(delta: float) -> void:
	if game == null or game.current_region != "storm_isle" or game.get_tree().paused:
		return
	_storm_clock -= delta
	_bolt_clock -= delta
	if _storm_clock <= 0.0 and not game.director.has_flag(WARDEN_FLAG):
		_storm_clock = randf_range(3.5, 5.5)
		var strike := CrystalStrike.new()
		strike.lightning = true
		strike.damage = maxi(5, roundi(game.player.max_health * 0.12))
		game.add_child(strike)
		strike.global_position = game.player.global_position + Vector2(randf_range(-60, 60), randf_range(-40, 40))
	if _bolt_clock <= 0.0:
		_bolt_clock = randf_range(5.0, 9.0)
		game.hud.flash_screen(Color(0.85, 0.9, 1.0, 0.35), 0.25)
		GameAudio.play("hit", -14.0, 0.5)

## Quest pins on the map.
func targets() -> Array:
	var q := game.quests
	var result: Array = []
	if q.is_active(WRECK) and not q.is_ready_to_complete(WRECK):
		var spot: Array = dock("salt_coast")
		result.append({"region": "salt_coast", "position": Vector2(float(spot[0]), float(spot[1])), "kind": "side", "title": "Обломки «Ветрокрыла»"})
	return result

func make_snapshot() -> Dictionary:
	return {"flights": flights}

func restore_snapshot(value: Variant) -> void:
	if value is Dictionary:
		flights = int(value.get("flights", 0))
