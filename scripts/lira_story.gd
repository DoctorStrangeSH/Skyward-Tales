extends RefCounted
class_name LiraStory

## Lira the alchemist's own story (stage 20). After «Слизь для опытов»:
##   lira_still  — «Перегонный куб»: 5 iron ore and 4 slime for a still;
##   lira_blast  — «Сбежавшие зелья»: the first brew explodes (a scene on
##                 the engine) and five living potions crawl around the
##                 lab — catch them (foes with meta "lira_blob", not saved);
##   lira_recipe — «Записи алхимика Хранителей»: the stabilising formula
##                 lies in the Archive on the Sky Island (a collectible).
## The reward: the lab grows (flag "lira_lab_2", a copper still with a
## bubbling flask by the house) and Lira serves the hero — a free potion
## once a day, potions for gold, and brewing from monster materials.

const SPEAKER := "Лира, алхимик"
const NPC := "alchemist"
const STILL := "lira_still"
const BLAST := "lira_blast"
const RECIPE := "lira_recipe"
const FLAG := "lira_lab_2"
const MIN_LEVEL := 4
const NEEDS := {"iron_ore": 5, "slime_gel": 4}
const BLOBS := 5
const LAB := Vector2(924, 508)
const STILL_SPOT := Vector2(1004, 494)
## Where the blobs scatter around the lab.
const BLOB_SPOTS := [Vector2(860, 560), Vector2(1010, 580), Vector2(1080, 520), Vector2(840, 640), Vector2(960, 650)]
const NOTES_ID := "keeper_alchemy_notes"
const NOTES_REGION := "sky_island"
const NOTES_SPOT := Vector2(700, 372)
const SHOP := {"health_potion": 30, "mana_potion": 30, "swift_tonic": 110, "power_elixir": 150}
## Brewing: materials → potions.
const BREWS := {
	"brew_heal": {"label": "3 слизи → 2 зелья здоровья", "takes": {"slime_gel": 3}, "gives": {"health_potion": 2}},
	"brew_mana": {"label": "2 пыльцы духов → 2 зелья маны", "takes": {"spirit_dust": 2}, "gives": {"mana_potion": 2}},
	"brew_power": {"label": "2 крыла мыши + 1 эссенция ветра → эликсир мощи", "takes": {"bat_wing": 2, "wind_essence": 1}, "gives": {"power_elixir": 1}},
	"brew_swift": {"label": "2 волчьих клыка + синецвет → тоник ветра", "takes": {"wolf_fang": 2, "bluebell": 1}, "gives": {"swift_tonic": 1}},
}
const GIFTS := ["health_potion", "mana_potion", "swift_tonic", "power_elixir"]

var game: SkywardGame
## The game day of the last free potion.
var gift_day: int = -1

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

func make_snapshot() -> Dictionary:
	return {"gift_day": gift_day}

func restore_snapshot(data: Variant) -> void:
	gift_day = int((data as Dictionary).get("gift_day", -1)) if data is Dictionary else -1

func lab_grown() -> bool:
	return game.director.has_flag(FLAG)

func _q() -> QuestManager:
	return game.quests

func _started(id: String) -> bool:
	return bool(_q().states.get(id, {}).get("started", false))

func _fresh(id: String) -> bool:
	return not _started(id) and not _q().is_completed(id)

func can_offer_still() -> bool:
	return _q().is_completed("lira_slime") and game.player.level >= MIN_LEVEL and _fresh(STILL)

func can_offer_recipe() -> bool:
	return _q().is_completed(BLAST) and _fresh(RECIPE)

func has_materials() -> bool:
	for item in NEEDS:
		if int(game.player.inventory.get(item, 0)) < int(NEEDS[item]):
			return false
	return true

## The tracker counts what the hero carries.
func sync_progress() -> void:
	if _q().is_active(STILL):
		var done := 0
		for item in NEEDS:
			if int(game.player.inventory.get(item, 0)) >= int(NEEDS[item]):
				done += 1
		_q().states[STILL]["progress"] = done

func marker() -> String:
	if (_q().is_active(STILL) and has_materials()) or _q().is_ready_to_complete(BLAST) or _q().is_ready_to_complete(RECIPE):
		return "ready"
	if can_offer_still() or can_offer_recipe():
		return "quest"
	if lab_grown() and gift_ready():
		return "service"
	return ""

func gift_ready() -> bool:
	return lab_grown() and game.day_night.day != gift_day

## True when Lira's story took the conversation.
func talk(npc_id: String) -> bool:
	if npc_id != NPC:
		return false
	var q := _q()
	if q.is_active(STILL):
		if not has_materials():
			game._show_dialogue(SPEAKER, "Для куба: железная руда — %d из 5, слизь — %d из 4. Руду бьют на Каменном Перевале, слизь сама ползает у дороги." % [mini(5, int(game.player.inventory.get("iron_ore", 0))), mini(4, int(game.player.inventory.get("slime_gel", 0)))])
			return true
		_finish_still()
		return true
	if q.is_active(BLAST):
		if q.is_ready_to_complete(BLAST):
			q.complete_quest(BLAST)
			game.npc_reward(BLAST)
			game.talk_line(NPC, SPEAKER, [
				{"text": "Лира пересчитала пойманные склянки — пять, все до одной, все недовольно булькают."},
				{"speaker": "self", "text": "Ты {мой герой|моя героиня}. Серьёзно. Ещё час — и они бы добрались до огорода, а там капуста, а капуста потом разговаривает."},
				{"speaker": "self", "text": "Зелья убегают, потому что живут. Им нужна формула стабилизации — а её знали только Хранители. Говорят, их алхимик вёл записи. Если они где-то и уцелели — то в Архиве на Небесном острове."},
			], [{"id": "lira_accept:recipe", "label": "Поищу записи в Архиве"}, {"id": "lira_later", "label": "Позже"}])
		else:
			game._show_dialogue(SPEAKER, "Живые зелья: поймано %d из %d. Они розовые, наглые и прячутся за домами вокруг лаборатории!" % [mini(BLOBS, int(q.states[BLAST].get("progress", 0))), BLOBS])
		return true
	if q.is_ready_to_complete(RECIPE):
		_finish_recipe()
		return true
	if q.is_active(RECIPE):
		game._show_dialogue(SPEAKER, "Записи алхимика Хранителей — в Архиве на Небесном острове, у полок напротив входа. Только не читай вслух: формулы иногда слышат.")
		return true
	if can_offer_still():
		game.talk_line(NPC, SPEAKER, [
			{"text": "Лира сидела на крыльце и рисовала угольком на доске что-то, похожее на чайник, который проглотил змею."},
			{"speaker": "self", "text": "Это перегонный куб, {hero}. Ну, будет. С ним я смогу варить зелья сильнее, чем всё, что продают у Брана. Не говори ему."},
			{"speaker": "self", "text": "Нужны пять кусков железной руды — на котёл и змеевик — и четыре порции слизи для первой закваски. Достанешь?"},
		], [{"id": "lira_accept:still", "label": "Достану руду и слизь"}, {"id": "lira_later", "label": "Позже"}])
		return true
	if can_offer_recipe():
		game._show_dialogue_choices(SPEAKER, "Ну что, заглянешь в Архив Хранителей за формулой? Без неё мои зелья так и будут разбегаться.", [
			{"id": "lira_accept:recipe", "label": "Поищу записи в Архиве"}, {"id": "lira_later", "label": "Позже"}])
		return true
	if lab_grown():
		_open_lab()
		return true
	return false

func _finish_still() -> void:
	for item in NEEDS:
		game.player.remove_item(item, int(NEEDS[item]))
	_q().states[STILL]["progress"] = NEEDS.size()
	_q().complete_quest(STILL)
	game.npc_reward(STILL)
	# The first brew — and the explosion, told on the engine.
	game.story.play_steps([
		{"text": "К вечеру куб стоял у стены лаборатории — медный, пузатый, с трубкой, свёрнутой в три кольца. Лира погладила его, как кошку."},
		{"speaker": "self", "text": "Первая закваска! Слизь, лунный лист, щепотка соли — и капельку звёздной пыли для блеска. Смотри, сейчас будет красиво."},
		{"effect": "camera", "to": [LAB.x, LAB.y + 20], "zoom": 1.3, "time": 0.8},
		{"text": "Куб загудел. Потом засвистел. Потом начал подпрыгивать."},
		{"effect": "flash"},
		{"effect": "shake", "power": 6, "time": 0.7},
		{"text": "БАХ! Крышка улетела в небо, а из трубки одна за другой выскочили пять розовых капель — каждая размером с курицу. Капли огляделись, хихикнули и бросились врассыпную."},
		{"effect": "camera_back", "time": 0.6},
		{"speaker": "self", "text": "Они живые! {hero}, лови их! Пока они не нашли огород!"},
	], NPC, SPEAKER, func() -> void:
		_q().start_quest(BLAST)
		game.hud.show_message("Новое задание: Сбежавшие зелья — поймайте 5 живых зелий у лаборатории", 3.5)
		spawn_blobs()
		game.update_npc_markers()
		game._refresh_hud(), true)

func _finish_recipe() -> void:
	_q().complete_quest(RECIPE)
	game.npc_reward(RECIPE)
	game.director.set_flag(FLAG)
	game.refresh_world_art()
	populate()
	game.story.play_steps([
		{"text": "Лира читала записи Хранителя всю ночь. Под утро она вышла на крыльцо — глаза красные, на носу сажа, на лице такая улыбка, будто она сама изобрела утро."},
		{"speaker": "self", "text": "Стабилизация — это не формула. Это песня! Хранитель пел зельям, пока они остывали. Я спела — и они перестали убегать. Ну, почти: одно только уползло под шкаф."},
		{"effect": "title", "text": "Лаборатория Лиры"},
		{"speaker": "self", "text": "Теперь у меня настоящая лаборатория. Заходи каждый день — одно зелье в день тебе бесплатно. А если принесёшь материалы, сварю что попросишь."},
	], NPC, SPEAKER, func() -> void:
		game.update_npc_markers()
		game._refresh_hud(), true)

func _open_lab() -> void:
	var choices: Array[Dictionary] = []
	if gift_ready():
		choices.append({"id": "lira_gift", "label": "🎁 Зелье дня (бесплатно)"})
	for brew_id in BREWS:
		var brew: Dictionary = BREWS[brew_id]
		var label := "⚗ " + str(brew["label"])
		if not _has_all(brew["takes"]):
			label += " (нет материалов)"
		choices.append({"id": "lira_brew:" + brew_id, "label": label})
	for item_id in SHOP:
		choices.append({"id": "lira_buy:" + item_id, "label": "Купить: %s — %d золота" % [game.player.get_item_name(item_id), int(SHOP[item_id])]})
	choices.append({"id": "lira_later", "label": "Уйти"})
	var line := "Колбы поют, куб пыхтит, ничего не взрывается уже три дня. Почти рекорд! Что сварить?"
	game._show_dialogue_choices(SPEAKER, line, choices)

func _has_all(takes: Dictionary) -> bool:
	for item in takes:
		if int(game.player.inventory.get(item, 0)) < int(takes[item]):
			return false
	return true

func handle_choice(choice_id: String) -> bool:
	if choice_id == "lira_later":
		game.dialogues._close()
		return true
	if choice_id == "lira_accept:still":
		game.dialogues._close()
		_q().start_quest(STILL)
		sync_progress()
		game.hud.show_message("Новое задание: Перегонный куб", 3.0)
		game.update_npc_markers()
		game._refresh_hud()
		return true
	if choice_id == "lira_accept:recipe":
		game.dialogues._close()
		_q().start_quest(RECIPE)
		game.hud.show_message("Новое задание: Записи алхимика Хранителей — Архив на Небесном острове", 3.5)
		populate()
		game.update_npc_markers()
		game._refresh_hud()
		return true
	if choice_id == "lira_gift":
		if gift_ready():
			gift_day = game.day_night.day
			var item: String = GIFTS[posmod(game.day_night.day, GIFTS.size())]
			game.player.add_item(item)
			GameAudio.play("pickup", -4.0)
			game.hud.show_message("Лира: «Свежего розлива!» Получено: %s" % game.player.get_item_name(item), 3.0)
		_open_lab()
		game.update_npc_markers()
		return true
	if choice_id.begins_with("lira_brew:"):
		var brew: Dictionary = BREWS.get(choice_id.trim_prefix("lira_brew:"), {})
		if not brew.is_empty() and _has_all(brew["takes"]):
			for item in brew["takes"]:
				game.player.remove_item(item, int(brew["takes"][item]))
			for item in brew["gives"]:
				game.player.add_item(item, int(brew["gives"][item]))
			GameAudio.play("cast_ice", -10.0)
			game.hud.show_message("Лира сварила: %s" % str(brew["label"]).split("→")[1].strip_edges(), 2.5)
		else:
			game.hud.show_message("Не хватает материалов.", 1.8)
		_open_lab()
		return true
	if choice_id.begins_with("lira_buy:"):
		var item_id := choice_id.trim_prefix("lira_buy:")
		var price := int(SHOP.get(item_id, 0))
		if price > 0 and game.player.gold >= price:
			game.player.add_gold(-price)
			game.player.add_item(item_id)
			GameAudio.play("pickup", -6.0)
			game.hud.show_message("Куплено: %s" % game.player.get_item_name(item_id), 2.0)
		else:
			game.hud.show_message("Не хватает золота.", 1.8)
		game._refresh_hud()
		_open_lab()
		return true
	return false

# --- The world: blobs, notes, the still ---------------------------------------

## Called when a land is built and when the story changes it.
func populate() -> void:
	match game.current_region:
		"greenreach":
			if _q().is_active(BLAST) and not _q().is_ready_to_complete(BLAST):
				spawn_blobs()
			if lab_grown():
				_spawn_still()
		NOTES_REGION:
			if _q().is_active(RECIPE) and int(_q().states[RECIPE].get("progress", 0)) < 1:
				for actor in game.get_children():
					if actor is WorldCollectible and actor.item_id == NOTES_ID and not actor.is_queued_for_deletion():
						return
				game._spawn_herb(NOTES_SPOT, NOTES_ID, "Записи алхимика Хранителей")

func spawn_blobs() -> void:
	if game.current_region != "greenreach":
		return
	var alive := 0
	for actor in game.get_children():
		if actor is SlimeEnemy and actor.has_meta("lira_blob") and not actor.is_queued_for_deletion():
			alive += 1
	var caught := int(_q().states.get(BLAST, {}).get("progress", 0))
	for i in range(alive + caught, BLOBS):
		var blob := game.spawn_enemy("slime", BLOB_SPOTS[i % BLOB_SPOTS.size()])
		if blob == null:
			continue
		blob.set_meta("lira_blob", true)
		blob.set_meta("event_foe", true)
		# Pink, not green: the slime's colours turned on the wheel.
		if blob.visual != null and blob.visual.material is ShaderMaterial:
			(blob.visual.material as ShaderMaterial).set_shader_parameter("hue_shift", 0.62)
		blob.modulate = Color(1.7, 1.2, 1.6)
		blob.max_health = maxi(8, blob.max_health / 2)
		blob.health = blob.max_health
		blob.defeated.connect(func(_xp: int) -> void: _on_blob_caught(blob.global_position))

func _on_blob_caught(at: Vector2) -> void:
	if not _q().is_active(BLAST):
		return
	_q().add_progress(BLAST, 1)
	Vfx.burst(game, at, [Color(1, 0.9, 1), Color(1.0, 0.55, 0.85), Color(0.8, 0.3, 0.7, 0.0)], 16, 60.0, 0.5)
	var caught := int(_q().states[BLAST].get("progress", 0))
	game.hud.show_message("Живое зелье поймано: %d/%d" % [mini(caught, BLOBS), BLOBS], 2.0)
	if caught >= BLOBS:
		game.hud.show_message("Все зелья пойманы! Вернитесь к Лире.", 3.0)
	game.update_npc_markers()
	game._refresh_hud()

## The notes in the Archive: read, then back to Lira.
func handles(item_id: String) -> bool:
	return item_id == NOTES_ID

func collect(herb: WorldCollectible) -> void:
	if not _q().is_active(RECIPE):
		herb.queue_free()
		return
	game.story.play_steps([
		{"text": "Тетрадь лежала на нижней полке, под стопкой звёздных карт. Обложка из коры, страницы тонкие, как крыло стрекозы, и все исписаны мелким прыгающим почерком."},
		{"text": "«Зелье живо, пока оно тёплое. Не держи его силой — спой ему, пока остывает, и оно останется с тобой». Ниже — ноты. Простые, как колыбельная."},
		{"speaker": "hero", "text": "Лира будет в восторге. Или споёт так, что взорвётся весь куб. Одно из двух."},
	], "", "", func() -> void:
		_q().add_progress(RECIPE, 1)
		game.hud.show_message("Записи найдены — отнесите их Лире в Зелёные Пределы.", 3.0)
		game.update_npc_markers()
		game._refresh_hud())
	Vfx.sparkle(game, herb.global_position)
	herb.queue_free()

func _spawn_still() -> void:
	for actor in game.get_children():
		if actor is LabStill:
			return
	var still := LabStill.new()
	game.add_child(still)
	still.global_position = STILL_SPOT

## Lira's copper still with a bubbling flask (art: tools/art/personal_art.py).
class LabStill extends StaticBody2D:
	func _ready() -> void:
		add_to_group("region_actor")
		collision_layer = 4
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(20, 8)
		shape.shape = rect
		shape.position = Vector2(0, -3)
		add_child(shape)
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/world_hd/props/alchemy_still.png")
		sprite.scale = Vector2(0.5, 0.5)
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if sprite.texture != null:
			sprite.position = Vector2(-sprite.texture.get_width() * 0.25, -sprite.texture.get_height() * 0.5)
		add_child(sprite)
		var bubbles := CPUParticles2D.new()
		bubbles.amount = 6
		bubbles.lifetime = 1.4
		bubbles.position = Vector2(7, -30)
		bubbles.direction = Vector2.UP
		bubbles.spread = 20.0
		bubbles.initial_velocity_min = 6.0
		bubbles.initial_velocity_max = 12.0
		bubbles.gravity = Vector2.ZERO
		bubbles.scale_amount_min = 1.0
		bubbles.scale_amount_max = 2.0
		bubbles.color = Color(0.85, 1.0, 0.7, 0.8)
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(0.9, 1.0, 0.75, 0.9), Color(0.7, 1.0, 0.6, 0.0)])
		bubbles.color_ramp = ramp
		add_child(bubbles)
