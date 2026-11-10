extends Node2D
class_name TowerObject

## A piece of the Tower of Trials (scripts/trial_tower.gd): the gate, the
## lever, the coffer, the altar, the stairs, a brazier… Art is a prop from
## assets/world_hd/props/tower_*.png; `label` makes it interactable,
## `wall_width` makes it solid, `glow` lights it up.

signal used(object: TowerObject)

var art: String = ""
var label: String = ""
var wall_width: float = 0.0
var glow: Color = Color(0, 0, 0, 0)
var flat: bool = false

func _ready() -> void:
	add_to_group("region_actor")
	if not label.is_empty():
		add_to_group("interactables")
	if flat:
		z_index = -90
	if wall_width > 0.0:
		var body := StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(wall_width, 12)
		shape.shape = rect
		shape.position = Vector2(0, -6)
		body.add_child(shape)
		add_child(body)
	if glow.a > 0.0:
		var light := PointLight2D.new()
		light.texture = _light_texture()
		light.color = glow
		light.energy = 0.9
		light.texture_scale = 1.4
		light.position = Vector2(0, -16)
		add_child(light)
	queue_redraw()

static func _light_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 96
	texture.height = 96
	return texture

func set_art(value: String) -> void:
	art = value
	queue_redraw()

func interact() -> void:
	used.emit(self)

func _draw() -> void:
	if not art.is_empty():
		WorldArt.draw_prop(self, "world/props/%s.png" % art)
