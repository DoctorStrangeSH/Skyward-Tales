extends Node
class_name WorldState

## Lasting consequences in the world, each for a number of in-game days
## (a day is 12 minutes): "trade_route" after a rescued caravan (new goods
## and a discount at Bran's), "caravan_lost" (prices up), "mine_overrun" …
## Other systems ask has(id); villagers gossip about them.

signal changed(state_id: String, active: bool)

const NAMES := {
	"trade_route": "Торговый путь открыт",
	"caravan_lost": "Караван разграблен",
}

var game: SkywardGame
## id -> day (absolute) when it ends.
var states: Dictionary = {}

func now() -> float:
	return game.day_night.now() if game != null and game.day_night != null else 0.0

func has(state_id: String) -> bool:
	return states.has(state_id) and float(states[state_id]) > now()

func set_state(state_id: String, days: float) -> void:
	states[state_id] = now() + days
	changed.emit(state_id, true)

func clear(state_id: String) -> void:
	if states.erase(state_id):
		changed.emit(state_id, false)

## Days left (rounded up), 0 when inactive.
func days_left(state_id: String) -> int:
	return ceili(float(states.get(state_id, 0.0)) - now()) if has(state_id) else 0

func _process(_delta: float) -> void:
	for state_id in states.keys():
		if float(states[state_id]) <= now():
			clear(str(state_id))

func make_snapshot() -> Dictionary:
	return {"states": states.duplicate()}

func restore_snapshot(data: Variant) -> void:
	if data is Dictionary and data.get("states", {}) is Dictionary:
		states = (data["states"] as Dictionary).duplicate()
