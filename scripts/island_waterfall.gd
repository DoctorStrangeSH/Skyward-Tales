extends Node2D
class_name IslandWaterfall

## One continuous outlet into the clouds. Reuses the approved water atlas;
## width and drop are independent of frame size, without a tapered icicle end.
const ATLAS := "res://assets/world_hd/cliffs/waterfall.png"
const FLOW := preload("res://assets/shaders/island_waterfall.gdshader")

var stream: ColorRect
var flow_material: ShaderMaterial
var clock: float = 0.0
var stream_width: float = 20.0
var drop_length: float = 180.0

func setup(width: float, length: float, phase: float = 0.0) -> void:
	stream_width = clampf(width, 8.0, 48.0)
	drop_length = clampf(length, 96.0, 320.0)
	clock = phase
	if stream != null:
		_refresh()

func _ready() -> void:
	if not ResourceLoader.exists(ATLAS):
		return
	flow_material = ShaderMaterial.new()
	flow_material.shader = FLOW
	flow_material.set_shader_parameter("atlas", load(ATLAS))
	stream = ColorRect.new()
	stream.name = "Flow"
	stream.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stream.material = flow_material
	add_child(stream)
	_refresh()

func _refresh() -> void:
	stream.position = Vector2(-stream_width * 0.5, 0.0)
	stream.size = Vector2(stream_width, drop_length)
	flow_material.set_shader_parameter("drop_length", drop_length)
	flow_material.set_shader_parameter("clock", clock)

func _process(delta: float) -> void:
	if flow_material == null:
		return
	clock = fmod(clock + delta, 120.0)
	flow_material.set_shader_parameter("clock", clock)
