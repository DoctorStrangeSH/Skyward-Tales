extends RefCounted
class_name Crew

## Owner's list №18, 19, 21: companions grow, wear gear and talk.
##   Each companion (Mira, Toren, Raina) has a level of their own — they get
##   half the experience the hero gets while travelling together — and a
##   point per level for their own skills (data/companions.json), not the
##   hero's. Three gear slots take pieces from the hero's bag: a weapon of
##   their kind, armour or a cloak, a charm (amulet, ring, earrings).
##   Tactics: «Защищать» (default — fights what attacks the hero or what the
##   hero fights), «Нападать» (anything nearby), «В стороне» (only helps).
##   Talking to a companion opens a small menu: a chat line that fits the
##   place, gear and skills, tactics.

const IDS := ["cartographer", "hunter", "captain_raina"]
const GEAR_SLOTS := ["weapon", "armor", "charm"]
const SLOT_NAMES := {"weapon": "Оружие", "armor": "Доспех", "charm": "Оберег"}
const STANCES := {"defend": "Защищать", "attack": "Нападать", "passive": "В стороне"}
const XP_SHARE := 0.5

var game: SkywardGame
## id → {"xp", "level", "points", "skills": {id: rank}, "gear": {slot: item}, "stance"}
var members: Dictionary = {}
## The companion whose page is open in the hero window.
var selected: String = ""

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open("res://data/companions.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data

static func info(id: String) -> Dictionary:
	return data().get(id, {})

## Companions travelling with the hero right now.
func active_ids() -> Array[String]:
	var result: Array[String] = []
	if game.companion != null and is_instance_valid(game.companion):
		result.append("cartographer")
	if game.party != null and not game.party.extra.is_empty():
		result.append(game.party.extra)
	return result

func node_for(id: String) -> Companion:
	if id == "cartographer":
		return game.companion if game.companion != null and is_instance_valid(game.companion) else null
	return game.party.follower() if game.party != null and game.party.extra == id else null

## The companion's record; joins at the hero's level − 2.
func state(id: String) -> Dictionary:
	if not members.has(id):
		var start := maxi(1, game.player.level - 2)
		members[id] = {"xp": 0, "level": start, "points": start, "skills": {}, "gear": {"weapon": "", "armor": "", "charm": ""}, "stance": "defend"}
	return members[id]

# --- Growth ------------------------------------------------------------------

func on_hero_experience(amount: int) -> void:
	for id in active_ids():
		var s := state(id)
		s["xp"] = int(s["xp"]) + maxi(1, roundi(amount * XP_SHARE))
		while int(s["xp"]) >= PlayerCharacter.xp_for_level(int(s["level"])):
			s["xp"] = int(s["xp"]) - PlayerCharacter.xp_for_level(int(s["level"]))
			s["level"] = int(s["level"]) + 1
			s["points"] = int(s["points"]) + 1
			game.hud.show_message("%s: уровень %d — новое очко навыков (окно героя → «Отряд»)." % [str(info(id).get("name", id)), int(s["level"])], 3.5)
		apply(id)

func rank(id: String, skill_id: String) -> int:
	return int(state(id)["skills"].get(skill_id, 0))

func can_learn(id: String, skill_id: String) -> String:
	var skill: Dictionary = info(id).get("skills", {}).get(skill_id, {})
	if skill.is_empty():
		return "нет такого навыка"
	var s := state(id)
	if rank(id, skill_id) >= int(skill.get("max", 1)):
		return "изучено полностью"
	if int(s["level"]) < int(skill.get("level", 1)):
		return "нужен ур. %d" % int(skill.get("level", 1))
	if int(s["points"]) <= 0:
		return "нет очков"
	return ""

func learn(id: String, skill_id: String) -> bool:
	if not can_learn(id, skill_id).is_empty():
		return false
	var s := state(id)
	s["points"] = int(s["points"]) - 1
	s["skills"][skill_id] = rank(id, skill_id) + 1
	apply(id)
	game.request_autosave()
	return true

# --- Gear --------------------------------------------------------------------

## Which slot of a companion an item fits ("" — it doesn't).
func slot_for(id: String, item_id: String) -> String:
	var kind := game.player._slot_for_item(item_id)
	match kind:
		"blade":
			return "weapon" if game.player.weapon_kind_of(item_id) in info(id).get("accepts", []) else ""
		"armor", "cloak":
			return "armor"
		"amulet", "ring", "earrings":
			return "charm"
	return ""

## Bag items that fit a slot of this companion.
func candidates(id: String, slot: String) -> Array[String]:
	var result: Array[String] = []
	for item_id in game.player.inventory:
		if int(game.player.inventory[item_id]) > 0 and slot_for(id, str(item_id)) == slot:
			result.append(str(item_id))
	return result

func equip(id: String, item_id: String) -> bool:
	var slot := slot_for(id, item_id)
	if slot.is_empty() or int(game.player.inventory.get(item_id, 0)) <= 0:
		return false
	var gear: Dictionary = state(id)["gear"]
	var previous := str(gear.get(slot, ""))
	game.player.inventory[item_id] = int(game.player.inventory[item_id]) - 1
	if int(game.player.inventory[item_id]) <= 0:
		game.player.inventory.erase(item_id)
	if not previous.is_empty():
		game.player.add_item(previous)
	gear[slot] = item_id
	apply(id)
	game.player.stats_changed.emit()
	return true

func unequip(id: String, slot: String) -> bool:
	var gear: Dictionary = state(id)["gear"]
	var item_id := str(gear.get(slot, ""))
	if item_id.is_empty():
		return false
	gear[slot] = ""
	game.player.add_item(item_id)
	apply(id)
	return true

func _gear_stat(id: String, stat: String) -> int:
	var total := 0
	for slot in GEAR_SLOTS:
		var item_id := str(state(id)["gear"].get(slot, ""))
		if item_id.is_empty():
			continue
		var definition := game.player.get_item_definition(item_id)
		if stat == "spell":
			var spells: Variant = definition.get("spell_bonus", {})
			if spells is Dictionary:
				for value in spells.values():
					total += int(value)
		else:
			total += int(definition.get(stat, 0))
	return total

## Everything that makes the companion hit and hold: shown on the page too.
func stats(id: String) -> Dictionary:
	var s := state(id)
	var level := int(s["level"])
	var main_rank := rank(id, {"cartographer": "frost_vial", "hunter": "sharp_arrows", "captain_raina": "powder"}.get(id, ""))
	return {
		"level": level,
		"damage_bonus": _gear_stat(id, "melee") + _gear_stat(id, "ranged") + _gear_stat(id, "spell") / 2,
		"damage_mult": (1.0 + 0.06 * float(level - 1)) * (1.0 + 0.2 * float(main_rank)) * (1.0 + 0.01 * float(_gear_stat(id, "melee_pct") + _gear_stat(id, "spell_pct"))),
		"crit": 0.05 + 0.01 * float(_gear_stat(id, "crit")),
		"haste": 1.0 - 0.01 * float(mini(40, _gear_stat(id, "haste") + _gear_stat(id, "agility") * 2)),
		"max_health": 60 + 12 * (level - 1) + _gear_stat(id, "max_health") + 4 * _gear_stat(id, "armor"),
		"armor": _gear_stat(id, "armor"),
		"regen": _gear_stat(id, "hp_regen"),
	}

## Pushes the record into the companion on the map.
func apply(id: String) -> void:
	var node := node_for(id)
	if node == null:
		return
	var st := stats(id)
	node.crew_level = int(st["level"])
	node.damage_bonus = int(st["damage_bonus"])
	node.damage_mult = float(st["damage_mult"])
	node.crit_chance = float(st["crit"])
	node.cooldown_mult = clampf(float(st["haste"]), 0.6, 1.0)
	var grown := int(st["max_health"]) - node.max_health
	node.max_health = int(st["max_health"])
	node.health = clampi(node.health + maxi(0, grown), 0, node.max_health)
	node.armor = int(st["armor"])
	node.regen = int(st["regen"])
	node.ranks = (state(id)["skills"] as Dictionary).duplicate()
	node.stance = str(state(id).get("stance", "defend"))
	if id == "cartographer":
		var base_heal := 35 if game.director.has_flag(Party.MIRA_FLAG) else 25
		node.heal_amount = base_heal + 8 * rank(id, "first_aid")
		node.heal_cooldown = maxf(8.0, (18.0 if game.director.has_flag(Party.MIRA_FLAG) else 25.0) - 2.0 * rank(id, "first_aid"))
	node.queue_redraw()

func apply_all() -> void:
	for id in active_ids():
		apply(id)

func set_stance(id: String, stance: String) -> void:
	if STANCES.has(stance):
		state(id)["stance"] = stance
		apply(id)

# --- Talk (owner's list №21) ---------------------------------------------------

## Opens the companion's menu; quest business comes first.
func talk(id: String) -> void:
	selected = id
	var name := str(info(id).get("name", id))
	var s := state(id)
	var stance := str(s.get("stance", "defend"))
	var choices: Array[Dictionary] = [
		{"id": "crew_chat:" + id, "label": "Как ты?"},
		{"id": "crew_page:" + id, "label": "Снаряжение и навыки%s" % (("  (очков: %d)" % int(s["points"])) if int(s["points"]) > 0 else "")},
		{"id": "crew_stance:" + id, "label": "Тактика: «%s» → «%s»" % [STANCES[stance], STANCES[_next_stance(stance)]]},
	]
	if id == "cartographer":
		choices.append({"id": "crew_business:" + id, "label": "О делах и картах"})
	else:
		choices.append({"id": "party_dismiss", "label": "Отпустить на свой пост"})
	choices.append({"id": "crew_bye", "label": "Идём дальше"})
	var hp := ""
	var node := node_for(id)
	if node != null and node.down_left > 0.0:
		hp = " (без сил — отдохнёт %d с)" % ceili(node.down_left)
	game._show_dialogue_choices("%s · ур. %d%s" % [name, int(s["level"]), hp], StoryText.format(_greeting(id)), choices)

func _greeting(id: String) -> String:
	match id:
		"cartographer":
			return "Мира подняла глаза от планшета и улыбнулась краешком губ. — Привал? Или опять что-то нашёл{|а}?"
		"hunter":
			return "Торен кивнул, не отрывая взгляда от кромки леса. — Говори. Только негромко."
		"captain_raina":
			return "Рейна сдвинула шляпу на затылок. — Слушаю, капитан. Ну, почти капитан."
	return "…"

func _next_stance(stance: String) -> String:
	var keys := STANCES.keys()
	return str(keys[(keys.find(stance) + 1) % keys.size()])

## A line that fits the place and the hour.
func chat_line(id: String) -> String:
	var talk: Dictionary = info(id).get("talk", {})
	var pool: Array = []
	if game.day_night != null and game.day_night.is_night() and talk.has("night"):
		pool.append_array(talk["night"])
	pool.append_array(talk.get(game.current_region, []))
	if pool.is_empty() or randf() < 0.35:
		pool.append_array(talk.get("default", []))
	return str(pool[randi() % pool.size()]) if not pool.is_empty() else "…"

func handle_choice(choice_id: String) -> bool:
	var id := choice_id.get_slice(":", 1)
	if choice_id == "crew_bye":
		_close()
		return true
	if choice_id.begins_with("crew_chat:"):
		game._show_dialogue_choices(str(info(id).get("name", id)), StoryText.format(chat_line(id)), [
			{"id": "crew_chat:" + id, "label": "Расскажи ещё"},
			{"id": "crew_back:" + id, "label": "← Назад"},
			{"id": "crew_bye", "label": "Идём дальше"}])
		return true
	if choice_id.begins_with("crew_back:"):
		talk(id)
		return true
	if choice_id.begins_with("crew_stance:"):
		set_stance(id, _next_stance(str(state(id).get("stance", "defend"))))
		game.hud.show_message("%s: тактика «%s»." % [str(info(id).get("name", id)), STANCES[str(state(id)["stance"])]], 2.5)
		talk(id)
		return true
	if choice_id.begins_with("crew_page:"):
		_close()
		selected = id
		game.hud.open_party_page(game.player)
		return true
	if choice_id.begins_with("crew_business:"):
		game.hud.close_dialogue()
		game.dialogues.on_cartographer()
		return true
	return false

func _close() -> void:
	game.hud.close_dialogue()
	game.player.set_physics_process(true)
	game._refresh_hud()

# --- Save --------------------------------------------------------------------

func make_snapshot() -> Dictionary:
	return {"members": members.duplicate(true)}

func restore_snapshot(value: Variant) -> void:
	members = {}
	if value is Dictionary and value.get("members", {}) is Dictionary:
		for id in value["members"]:
			if IDS.has(str(id)) and value["members"][id] is Dictionary:
				var s: Dictionary = (value["members"][id] as Dictionary).duplicate(true)
				for key in ["xp", "level", "points"]:
					s[key] = int(s.get(key, 0))
				s["level"] = maxi(1, int(s["level"]))
				if not s.get("skills", {}) is Dictionary:
					s["skills"] = {}
				if not s.get("gear", {}) is Dictionary:
					s["gear"] = {"weapon": "", "armor": "", "charm": ""}
				s["stance"] = str(s.get("stance", "defend"))
				members[str(id)] = s
	apply_all.call_deferred()
