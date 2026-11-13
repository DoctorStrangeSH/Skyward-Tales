extends RefCounted
class_name Party

## Этап 17: companions beyond Mira and their personal stories.
##   Mira's quest «Последняя страница» (once the ship flies): her mother Ilva,
##     a cartographer of the Free Captains, vanished past the edge of the map.
##     Raina knows that old captain Vorn keeps Ilva's logbook in the hidden
##     Free Port; the hero fetches it and Mira grows braver (better first aid,
##     the compass of her mother).
##   Toren joins after a legend hunt — he shoots arrows.
##   Raina joins after Mira's quest — thunder pistol.
## One of them can travel with the hero next to Mira; the other waits home.

const MIRA_QUEST := "mira_logbook"
const MIRA_FLAG := "mira_inspired"
const JOINERS := {
	"hunter": {"name": "Торен, охотник", "role": "hunter", "look": "hunter"},
	"captain_raina": {"name": "Рейна Штормовая", "role": "captain", "look": "mercenary"},
}

var game: SkywardGame
## The second companion's NPC id ("" — none).
var extra: String = ""
## Mira's quest stage: "" → "raina" (ask Raina) → "port" (go to Vorn) → "logbook".
var stage: String = ""
var _follower: Companion

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

# --- Companions ---------------------------------------------------------------

func can_recruit(npc_id: String) -> bool:
	if not JOINERS.has(npc_id) or extra == npc_id:
		return false
	match npc_id:
		"hunter":
			return game.legends.hunts_done >= 1
		"captain_raina":
			return game.quests.is_completed(MIRA_QUEST)
	return false

func recruit(npc_id: String) -> bool:
	if not can_recruit(npc_id):
		return false
	dismiss(false)
	extra = npc_id
	# The NPC leaves their post and follows the hero.
	for actor in game.get_children():
		if actor is WorldNpc and not actor.is_companion and actor.npc_id == npc_id:
			game.remove_child(actor)
			actor.queue_free()
	ensure_follower()
	game.achievements.add("companions")
	game.hud.show_message("%s теперь в отряде." % str(JOINERS[npc_id]["name"]), 3.0)
	game.request_autosave()
	return true

func dismiss(announce: bool = true) -> void:
	if extra.is_empty():
		return
	var who := str(JOINERS[extra]["name"])
	extra = ""
	if _follower != null and is_instance_valid(_follower):
		_follower.queue_free()
	_follower = null
	if announce:
		game.hud.show_message("%s возвращается на свой пост." % who, 3.0)
		game.request_autosave()

## Spawns the second companion if one is in the party (after loading or
## changing regions it survives as a companion node).
func ensure_follower() -> void:
	if extra.is_empty() or (_follower != null and is_instance_valid(_follower)):
		return
	var info: Dictionary = JOINERS[extra]
	_follower = Companion.new()
	_follower.npc_id = extra
	_follower.look_id = str(info["look"])
	_follower.display_name = str(info["name"])
	_follower.role = str(info["role"])
	# Far enough not to steal the E prompt; step closer to talk.
	_follower.follow_offset = Vector2(34, 12)
	_follower.hero = game.player
	game.add_child(_follower)
	_follower.add_to_group("interactables")
	_follower.global_position = game.player.global_position + _follower.follow_offset
	_follower.interacted.connect(func(_source: Node2D) -> void:
		if game.calendar.talk(extra):
			return
		game.crew.talk(extra))
	game.crew.apply(extra)

func follower() -> Companion:
	return _follower if _follower != null and is_instance_valid(_follower) else null

func _talk_follower() -> void:
	var lines := {
		"hunter": "Звери чуют тебя за версту, {hero}. Хорошо, что теперь они чуют и меня.",
		"captain_raina": "Небо большое, а мы маленькие. Зато быстрые. Куда дальше, капитан?",
	}
	game._show_dialogue_choices(str(JOINERS[extra]["name"]), StoryText.format(str(lines.get(extra, ""))), [
		{"id": "party_dismiss", "label": "Отпустить на свой пост"},
		{"id": "party_later", "label": "Идём дальше"}])

## Mira's first aid after her quest (and every companion's level and gear).
func apply_mira() -> void:
	if game.companion != null and is_instance_valid(game.companion) and game.director.has_flag(MIRA_FLAG):
		game.companion.heal_amount = 35
		game.companion.heal_cooldown = 18.0
	if game.crew != null:
		game.crew.apply_all()

# --- Mira's quest ---------------------------------------------------------------

func port_known() -> bool:
	return stage in ["port", "logbook"] or game.quests.is_completed(MIRA_QUEST)

func can_offer_mira() -> bool:
	var q := game.quests
	return game.director.has_flag("mira_companion") and game.ship.is_ready() and not bool(q.states.get(MIRA_QUEST, {}).get("started", false)) and not q.is_completed(MIRA_QUEST)

func marker(npc_id: String) -> String:
	var q := game.quests
	if npc_id == "captain_raina" and q.is_active(MIRA_QUEST) and stage == "raina":
		return "quest"
	if npc_id == "port_captain_vorn" and q.is_active(MIRA_QUEST) and stage == "port":
		return "ready"
	return ""

## True when a companion story took the conversation.
func talk(npc_id: String) -> bool:
	var q := game.quests
	match npc_id:
		"cartographer":
			if q.is_active(MIRA_QUEST) and stage == "logbook":
				q.states[MIRA_QUEST]["progress"] = 1
				q.complete_quest(MIRA_QUEST)
				game.npc_reward(MIRA_QUEST)
				game.director.set_flag(MIRA_FLAG)
				apply_mira()
				game.achievements.add("mira_logbook")
				game.talk_line("cartographer", "Мира", [{"text": "Мира открыла журнал на последней странице и долго не могла начать читать. Потом начала — вслух, медленно, как читают письма от тех, кого давно нет."}, {"speaker": "self", "text": "«Если ты читаешь это, Мира, — я не заблудилась. Я ушла рисовать то, чего ещё нет на картах. Дорисуй за меня»."}, {"text": "Мира закрыла журнал и прижала его к груди. Она не плакала — только губы чуть дрожали, как у человека, который очень долго держал что-то тяжёлое и наконец поставил."}, {"speaker": "self", "text": "Она знала. Знала, что я стану картографом. Спасибо, {hero}. Возьми её компас — стрелка всегда показывает на неоткрытое. А я… я теперь буду беречь тебя вдвое лучше."}])
				return true
			if can_offer_mira():
				game.talk_line("cartographer", "Мира", [{"text": "Вечером у костра Мира долго вертела в руках перо, не решаясь заговорить. Потом решилась — быстро, как прыгают в холодную воду."}, {"speaker": "self", "text": "{hero}, можно тебя попросить? Моя мама, Илва, была картографом у Свободных Капитанов. Самым лучшим. Она улетела за край карты, когда мне было шесть."}, {"speaker": "self", "text": "Говорят, её журнал где-то у капитанов. Последние записи. Я никогда не думала, что смогу его найти — а теперь у нас есть корабль…"}], [
					{"id": "party_mira_accept", "label": "Найдём журнал твоей мамы"},
					{"id": "party_later", "label": "Чуть позже"}])
				return true
		"captain_raina":
			if q.is_active(MIRA_QUEST) and stage == "raina":
				stage = "port"
				game.factions.add_rep("captains", 5)
				game.talk_line("captain_raina", "Рейна Штормовая", [{"text": "Рейна долго смотрела на Миру — так пристально, что та покраснела. Потом капитанша усмехнулась и сдвинула шляпу на затылок."}, {"speaker": "self", "text": "Илва Звёздная? Лучший картограф Союза. Ты — её дочь? Те же уши. И то же упрямство в подбородке."}, {"speaker": "self", "text": "Её журнал хранит старый Ворн — в Вольной пристани. Мы не пускаем туда чужих… но дочь Илвы — не чужая. Держи координаты: «Ветрокрыл» найдёт пристань сам."}])
				game.update_npc_markers()
				game.request_autosave()
				return true
		"port_captain_vorn":
			if q.is_active(MIRA_QUEST) and stage == "port":
				stage = "logbook"
				q.states[MIRA_QUEST]["progress"] = 1
				game.talk_line("port_captain_vorn", "Старый капитан Ворн", [{"text": "Старый Ворн сидел в таверне за угловым столом — один, с трубкой и кружкой, к которой не прикасался. Увидев Миру, он медленно поднялся. Трубка выпала у него из рук."}, {"speaker": "self", "text": "Дочка Илвы? Ну наконец-то. Двадцать лет жду. Я обещал отдать журнал только ей — или тому, кого она пришлёт."}, {"speaker": "self", "text": "Держи. Последнюю страницу Илва писала здесь, за этим столом. Пила свой горелый кофе и смеялась. Сказала: «Ворн, я вернусь к ужину». Ужин я до сих пор держу тёплым."}])
				game.hud.show_message("Получен журнал Илвы. Отнесите его Мире.", 3.0)
				game.update_npc_markers()
				game.request_autosave()
				return true
		"port_quartermaster":
			if game.factions.value("captains") >= Factions.FRIENDS:
				game.factions.open_shop("captains")
			else:
				game._show_dialogue("Бруно, квартирмейстер", "Товар — для своих. Помоги Союзу, и поговорим (нужен ранг «Друзья» у Свободных Капитанов).")
			return true
	return false

func handle_choice(choice_id: String) -> bool:
	match choice_id:
		"party_mira_accept":
			game.quests.start_quest(MIRA_QUEST)
			stage = "raina"
			game.hud.show_message("Задание: Последняя страница. Рейна Штормовая ждёт на Солёном берегу.", 3.5)
			_close()
			return true
		"party_dismiss":
			dismiss()
			_close()
			return true
		"party_later":
			_close()
			return true
	if choice_id.begins_with("party_join:"):
		var npc_id := choice_id.trim_prefix("party_join:")
		_close()
		recruit(npc_id)
		return true
	return false

func _close() -> void:
	game.hud.close_dialogue()
	game.player.set_physics_process(true)
	game._refresh_hud()

func targets() -> Array:
	var q := game.quests
	if not q.is_active(MIRA_QUEST):
		return []
	match stage:
		"raina":
			return [{"region": "salt_coast", "position": Vector2(510, 800), "kind": "side", "title": "Рейна Штормовая"}]
		"port":
			return [{"region": "free_port", "position": Vector2(470, 600), "kind": "side", "title": "Капитан Ворн"}]
	return []

func make_snapshot() -> Dictionary:
	return {"extra": extra, "stage": stage}

func restore_snapshot(value: Variant) -> void:
	dismiss(false)
	extra = ""
	stage = ""
	if value is Dictionary:
		stage = str(value.get("stage", ""))
		var who := str(value.get("extra", ""))
		if JOINERS.has(who):
			extra = who
