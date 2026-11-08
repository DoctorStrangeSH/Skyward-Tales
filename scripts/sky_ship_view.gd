extends Node2D
class_name SkyShipView

## «Ветрокрыл» at a dock: the airship hovering with a gentle bob above its
## shadow, or the wreck on the Salt Coast. The node sits at the rope ladder
## (the boarding spot); the hull blocks walking.

signal used

const SHIP := "res://assets/world_hd/sky_ship.png"
const WRECK := "res://assets/world_hd/sky_ship_wreck.png"

var wrecked: bool = false
var prompt: String = "подняться на борт"
var _sprite: Sprite2D
var _clock: float = 0.0

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("region_actor")
	prompt = "осмотреть обломки" if wrecked else "подняться на борт"
	_sprite = Sprite2D.new()
	_sprite.texture = load(WRECK if wrecked else SHIP)
	_sprite.scale = Vector2(0.5, 0.5)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# The ladder foot (sprite x≈260/340, bottom) sits on this node.
	_sprite.centered = false
	_sprite.position = Vector2(-132, -150) if not wrecked else Vector2(-110, -100)
	add_child(_sprite)
	# Y-sort with the hero: the ship is drawn by its ladder foot.
	z_index = 0
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(110, 18) if not wrecked else Vector2(120, 26)
	shape.shape = rect
	shape.position = Vector2(-60, -6) if not wrecked else Vector2(-20, -20)
	body.add_child(shape)
	add_child(body)

func interact() -> void:
	used.emit()

func _process(delta: float) -> void:
	if wrecked:
		return
	_clock += delta
	_sprite.position.y = -150.0 + sin(_clock * 1.6) * 2.5
	queue_redraw()

func _draw() -> void:
	if wrecked:
		return
	# The hull's shadow on the ground, breathing with the bob.
	var squash := 1.0 - sin(_clock * 1.6) * 0.04
	draw_set_transform(Vector2(-50, -4), 0.0, Vector2(1.0, 0.28) * squash)
	draw_circle(Vector2.ZERO, 62.0, Color(0.0, 0.0, 0.05, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
