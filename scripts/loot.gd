extends Node2D
class_name WorldLoot

## A drop on the ground. Shows the item's icon over a glow in its rarity
## colour (rare and better also get a light beam), bobs, and flies into the
## hero once she walks close — no button needed. "gold" is a coin pile.

signal collected(item_id: String, amount: int)

const RARITY_GLOW := {
	"common": Color(1.0, 1.0, 0.95, 0.35),
	"uncommon": Color(0.4, 1.0, 0.45, 0.5),
	"rare": Color(0.35, 0.65, 1.0, 0.6),
	"epic": Color(0.8, 0.45, 1.0, 0.65),
	"legendary": Color(1.0, 0.62, 0.15, 0.75),
}
const MAGNET_RADIUS := 34.0
const PICKUP_RADIUS := 8.0
const FLY_SPEED := 190.0

var item_id: String = "health_potion"
var item_name: String = "Зелье здоровья"
var amount: int = 1
var rarity: String = "common"
## Freshly dropped loot waits a moment before it can be pulled in.
var settle_time: float = 0.35
var _clock: float = 0.0
var _flying: bool = false
var _icon: Texture2D
var _picked: bool = false

func _ready() -> void:
	add_to_group("interactables")
	_clock = randf() * TAU
	if item_id == "gold":
		rarity = "common"
	else:
		var player := _player()
		var definition: Dictionary = player.get_item_definition(item_id) if player != null else {}
		rarity = str(definition.get("rarity", "common"))
		var icon_id := str(definition.get("icon", item_id))
		if ResourceLoader.exists("res://assets/icons/%s.png" % icon_id):
			_icon = WorldArt.texture("icons/%s.png" % icon_id)
	queue_redraw()

func _player() -> PlayerCharacter:
	var parent := get_parent()
	if parent != null and "player" in parent:
		return parent.player as PlayerCharacter
	return null

func interact() -> void:
	if _picked:
		return
	_picked = true
	Vfx.sparkle(get_parent(), global_position)
	collected.emit(item_id, amount)
	queue_free()

func _process(delta: float) -> void:
	_clock += delta
	settle_time = maxf(0.0, settle_time - delta)
	var player := _player()
	if player != null and player.health > 0 and settle_time <= 0.0:
		var offset := player.global_position + Vector2(0, -4) - global_position
		if _flying or offset.length() < MAGNET_RADIUS:
			_flying = true
			if offset.length() < PICKUP_RADIUS:
				interact()
				return
			global_position += offset.normalized() * minf(offset.length(), FLY_SPEED * delta)
	queue_redraw()

func _draw() -> void:
	var bob := sin(_clock * 3.0) * 1.5
	var glow: Color = RARITY_GLOW.get(rarity, RARITY_GLOW["common"])
	if rarity in ["rare", "epic", "legendary"]:
		var beam := glow
		beam.a = 0.3 + 0.1 * sin(_clock * 4.0)
		draw_rect(Rect2(-3, -40, 6, 38), beam)
		draw_rect(Rect2(-1, -46, 2, 44), Color(beam.r, beam.g, beam.b, beam.a + 0.1))
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 9.0 + sin(_clock * 4.0), Color(glow.r, glow.g, glow.b, glow.a * 0.6))
	draw_circle(Vector2.ZERO, 5.0, glow)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if item_id == "gold":
		WorldArt.draw_prop(self, "props/loot_coins.png", false, Vector2(0, bob * 0.5))
	elif _icon != null:
		if _icon.get_width() > 16:
			texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			draw_texture_rect(_icon, Rect2(Vector2(-10, -20 + bob), Vector2(20, 20)), false)
		else:
			draw_texture(_icon, Vector2(-8, -16 + bob))
	else:
		var art := "pouch"
		if item_id in ["health_potion", "mana_potion", "wolf_pelt"]:
			art = item_id
		elif item_id == "ancient_relic":
			art = "relic"
		WorldArt.draw_prop(self, "props/%s.png" % art, false, Vector2(0, bob))
