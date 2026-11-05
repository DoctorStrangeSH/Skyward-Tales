extends Node
class_name PassMine

## The Stone Pass mine (world state "mine_overrun" / "mine_cleared").
## Now and then monsters take the mine: the miners flee, the iron veins at
## its mouth are lost and iron sells dear. Beat the Ore Leader (ore_golem)
## and the miners come back for four days with rich veins and a gift.
## Borin's story needs star iron from this mine.

const REGION := "stone_pass"
const ENTRANCE := Vector2(1190, 575)
const OVERRUN_CHANCE := 0.25
const CLEARED_DAYS := 4.0
const OVERRUN_DAYS := 6.0

var game: SkywardGame
var rng := RandomNumberGenerator.new()
var _day: int = -1
## The miner's gift: one per freeing.
var gift_ready: bool = false

func _ready() -> void:
	rng.randomize()

func overrun() -> bool:
	return game.world_state.has("mine_overrun")

func cleared() -> bool:
	return game.world_state.has("mine_cleared")

## Each new day the mine may be overrun again (only once the hero knows the pass).
func _process(_delta: float) -> void:
	if game == null or game.day_night == null:
		return
	var day := game.day_night.day
	if _day < 0:
		_day = day
		return
	if day == _day:
		return
	_day = day
	if game.visited_regions.has(REGION) and not overrun() and not cleared() and rng.randf() < OVERRUN_CHANCE:
		start_overrun(OVERRUN_DAYS)

func start_overrun(days: float) -> void:
	game.world_state.clear("mine_cleared")
	game.world_state.set_state("mine_overrun", days)
	if game.current_region != REGION:
		game.hud.show_message("Вести с Перевала: твари захватили шахту! Железо дорожает.", 4.0)

## The Ore Leader fell: the mine is free.
func on_leader_defeated() -> void:
	if not overrun():
		return
	game.world_state.clear("mine_overrun")
	game.world_state.set_state("mine_cleared", CLEARED_DAYS)
	gift_ready = true
	game.achievements.add("mines")
	game.hud.show_title_card("Шахта освобождена!", 2.5)
	game.hud.show_message("Шахтёры возвращаются: у входа открылись богатые жилы.", 4.0)
	GameAudio.play("quest", -4.0, 0.0)
	if game.current_region == REGION:
		# Miners, veins and (for Borin) star iron appear right away.
		for npc_data in RegionCatalog.get_region(REGION).get("npcs", []):
			if str(npc_data.get("requires_state", "")) == "mine_cleared":
				game._spawn_npc(npc_data)
		game.spawn_story_objects()
		game._spawn_gathering_entries(RegionCatalog.get_region(REGION).get("gather", []), "mine_cleared")
	game.request_autosave()

func talk_miner() -> void:
	if gift_ready:
		gift_ready = false
		game.player.add_item("iron_ore", 6)
		game.player.add_gold(80)
		game._show_dialogue("Шахтёрка Ветта", "Ты {вернул|вернула} нам шахту, {hero}! Держи первую добычу — шесть кусков руды и немного монет. Жилы у входа сейчас богатые, копай на здоровье.")
		game._refresh_hud()
	else:
		game._show_dialogue("Шахтёрка Ветта", "Работа кипит! Пока твари не вернулись, жилы у входа щедрые. Заходи ещё, {hero}.")

## Iron sells dear while the mine is lost.
func iron_price_mult() -> float:
	return 1.6 if overrun() else 1.0

func rumor() -> String:
	if overrun():
		return "Шахту на Каменном Перевале захватили твари! Железо теперь на вес золота."
	if cleared():
		return "Шахтёры вернулись на Перевал — говорят, у входа такие жилы, что кирка звенит!"
	return ""

func minimap_marker() -> Array:
	return []

func make_snapshot() -> Dictionary:
	return {"gift": gift_ready}

func restore_snapshot(data: Variant) -> void:
	if data is Dictionary:
		gift_ready = bool(data.get("gift", false))
