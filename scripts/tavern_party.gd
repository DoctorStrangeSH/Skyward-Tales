extends Node
class_name TavernParty

## Этап 24: Friday evening at Greta's tavern (once the tavern is built).
## The villagers already spend their evenings at its door; on Fridays it is
## a party, and Greta's talk offers more:
##   • dice with Yar the carter — a bet of 20 gold, two dice each, the higher
##     sum takes the pot (a draw — bets back); three wins a night at most;
##   • a song from the bard — 10 gold: «good spirits» till the next evening,
##     +10% gold from everything;
##   • a round for the house — 40 gold: every villager warms to you a little.
## The calendar marks every Friday as «Вечер в таверне».

const WEEKDAY := 4
const FROM := 0.70
const TO := 0.95
const BET := 20
const SONG := 10
const ROUND := 40
const MAX_WINS := 3

var game: SkywardGame
var rng := RandomNumberGenerator.new()
## The day of the last party and the dice won on it.
var wins_day: int = -1
var wins: int = 0
var round_day: int = -1

func _ready() -> void:
	rng.randomize()

static func is_party_day(day: int) -> bool:
	return Seasons.weekday_of(day) == WEEKDAY

func tavern_built() -> bool:
	return game.settlement != null and game.settlement.building_level(VillageBuildings.TAVERN) >= 1

func tonight() -> bool:
	var t := game.day_night.time
	return tavern_built() and is_party_day(game.day_night.day) and t >= FROM and t < TO

func cheer() -> bool:
	return game.world_state != null and game.world_state.has("tavern_cheer")

func gold_mult() -> float:
	return 1.1 if cheer() else 1.0

func _wins_tonight() -> int:
	return wins if wins_day == game.day_night.day else 0

## Extra lines for Greta's menu on a party night.
func choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not tonight():
		return result
	if _wins_tonight() < MAX_WINS:
		result.append({"id": "tparty_dice", "label": "♪ Кости с возницей Яром — ставка %d" % BET})
	if not cheer():
		result.append({"id": "tparty_song", "label": "♪ Заказать песню барду — %d (весёлый дух: +10%% золота на сутки)" % SONG})
	if round_day != game.day_night.day:
		result.append({"id": "tparty_round", "label": "♪ Угостить всех — %d (жители потеплеют)" % ROUND})
	return result

func greeting() -> String:
	return "Пятница! В таверне не протолкнуться: бард настраивает лютню, возница Яр трясёт стаканчик с костями. Заходи, {hero}!" if tonight() else ""

## Two dice each. Returns {"hero", "yar", "result": "win"|"lose"|"draw"}.
func roll_dice() -> Dictionary:
	if game.player.gold < BET or _wins_tonight() >= MAX_WINS:
		return {}
	var hero := rng.randi_range(1, 6) + rng.randi_range(1, 6)
	var yar := rng.randi_range(1, 6) + rng.randi_range(1, 6)
	var result := "draw"
	if hero > yar:
		result = "win"
		game.player.add_gold(BET)
		if wins_day != game.day_night.day:
			wins_day = game.day_night.day
			wins = 0
		wins += 1
		game.achievements.add("dice_wins")
	elif hero < yar:
		result = "lose"
		game.player.add_gold(-BET)
	return {"hero": hero, "yar": yar, "result": result}

func handle_choice(choice_id: String) -> bool:
	if not choice_id.begins_with("tparty_"):
		return false
	match choice_id:
		"tparty_dice":
			var roll := roll_dice()
			if roll.is_empty():
				game._show_dialogue("Возница Яр", "«Хватит на сегодня, а то без штанов меня оставишь!»" if _wins_tonight() >= MAX_WINS else "«Ставка — %d. Мелочь потом, а?»" % BET)
				return true
			var text := "Твои кости: %d. Кости Яра: %d. " % [int(roll["hero"]), int(roll["yar"])]
			text += {"win": "Яр крякнул и подвинул тебе монеты: +%d золота." % BET, "lose": "Яр загрёб ставку: «Не везёт в кости — повезёт в любви!» −%d золота." % BET, "draw": "Ничья — ставки обратно."}[str(roll["result"])]
			var next: Array[Dictionary] = []
			if _wins_tonight() < MAX_WINS and game.player.gold >= BET:
				next.append({"id": "tparty_dice", "label": "Ещё раз (%d)" % BET})
			next.append({"id": "tparty_back", "label": "← К Грете"})
			game._show_dialogue_choices("Кости с Яром", text, next)
			GameAudio.play("ui", -4.0, 0.2)
		"tparty_song":
			if game.player.gold < SONG:
				game.hud.show_message("Не хватает золота.", 2.0)
				return true
			game.player.add_gold(-SONG)
			game.world_state.set_state("tavern_cheer", 1.0)
			game._show_dialogue("Бард Лель", "Лель ударил по струнам — и вся таверна подхватила «Ветер над островами». Ноги сами пошли в пляс. (Весёлый дух: +10% золота до завтрашнего вечера.)")
			GameAudio.play("quest", -6.0, 0.0)
		"tparty_round":
			if game.player.gold < ROUND:
				game.hud.show_message("Не хватает золота.", 2.0)
				return true
			game.player.add_gold(-ROUND)
			round_day = game.day_night.day
			for npc in ["elder", "mira", "bran", "toren"]:
				if game.relationships.has_npc(npc):
					game.relationships.adjust(npc, 2)
			game._show_dialogue("Грета, хозяйка таверны", StoryText.format("«Эль на всех — за счёт {hero}!» Таверна взревела. Старейшина поднял кружку за тебя, Бран впервые в жизни не торговался, а Торен даже улыбнулся."))
			game.achievements.add("tavern_rounds")
		"tparty_back":
			game.buildings.talk_tavern()
	return true

func make_snapshot() -> Dictionary:
	return {"wins_day": wins_day, "wins": wins, "round_day": round_day}

func restore_snapshot(value: Variant) -> void:
	var saved: Dictionary = value if value is Dictionary else {}
	wins_day = int(saved.get("wins_day", -1))
	wins = int(saved.get("wins", 0))
	round_day = int(saved.get("round_day", -1))
