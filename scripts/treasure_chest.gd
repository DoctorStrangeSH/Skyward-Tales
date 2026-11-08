extends Node2D
class_name TreasureChest

signal opened(chest_id: String, gold: int, item_id: String, amount: int)
signal bonus_found(item_id: String, rarity: String)

var chest_id: String = ""
var gold_reward: int = 0
var item_reward: String = ""
var item_amount: int = 0
var is_opened: bool = false
## "wood", "iron" or "gold": better chests hold rolled equipment.
var tier: String = "wood"
var _twinkle: float = 0.0
var _pop: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_twinkle = rng.randf() * 3.0
	add_to_group("interactables")
	queue_redraw()

func interact() -> void:
	if is_opened or is_queued_for_deletion():
		return
	is_opened = true
	_pop = 0.3
	Vfx.sparkle(get_parent(), global_position)
	Vfx.burst(get_parent(), global_position + Vector2(0, -10), [Color(1, 1, 0.85), Color(1.0, 0.82, 0.3), Color(1.0, 0.6, 0.2, 0.0)], 18 if tier == "gold" else 10, 80.0, 0.6)
	opened.emit(chest_id, gold_reward, item_reward, item_amount)
	var drop: Dictionary = roll_bonus(rng.randf())
	bonus_found.emit(str(drop["item"]), str(drop["rarity"]))
	queue_redraw()
	remove_from_group("interactables")

static func roll_bonus(chance: float) -> Dictionary:
	# 65% common, 28% uncommon, 7% rare; rare tier is split between four finds.
	var value: float = clampf(chance, 0.0, 0.999999)
	if value < 0.65:
		return {"item": "health_potion", "rarity": "common"}
	if value < 0.93:
		return {"item": "mana_amulet", "rarity": "uncommon"}
	var rare_roll: float = (value - 0.93) / 0.07
	if rare_roll < 0.25:
		return {"item": "starlight_essence", "rarity": "rare"}
	if rare_roll < 0.50:
		return {"item": "pyromancer_core", "rarity": "rare"}
	if rare_roll < 0.75:
		return {"item": "frost_heart", "rarity": "rare"}
	return {"item": "storm_eye", "rarity": "rare"}

func _process(delta: float) -> void:
	_twinkle += delta
	if _pop > 0.0:
		_pop = maxf(0.0, _pop - delta)
	if not is_opened or _pop > 0.0:
		queue_redraw()

func _draw() -> void:
	var squash := 1.0 + 0.25 * sin(_pop / 0.3 * PI) if _pop > 0.0 else 1.0
	var art := "props/chest_%s_%s.png" % [tier, "open" if is_opened else "closed"]
	if not ResourceLoader.exists("res://assets/" + art):
		art = "props/chest_open.png" if is_opened else "props/chest_closed.png"
	WorldArt.draw_prop(self, art, false, Vector2.ZERO, Vector2(2.0 - squash, squash))
	if not is_opened:
		# A glint runs over the lid every few seconds so chests catch the eye.
		var phase := fmod(_twinkle, 3.0)
		if phase < 0.5:
			var t := phase / 0.5
			var at := Vector2(-6 + 12 * t, -12)
			var size := 3.0 * sin(t * PI)
			var color := Color(1, 1, 0.9, 0.9)
			draw_line(at - Vector2(size, 0), at + Vector2(size, 0), color, 1.0)
			draw_line(at - Vector2(0, size), at + Vector2(0, size), color, 1.0)
