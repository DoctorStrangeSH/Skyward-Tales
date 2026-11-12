@tool
extends Node2D
class_name IslandWaterfall

## Editable continuous water. Preview this scene in Godot; the same instance
## is used by the game. Grain keeps its world scale when the stream is widened.
const ATLAS := "res://assets/world_hd/cliffs/waterfall.png"
const FLOW := preload("res://assets/shaders/island_waterfall.gdshader")
const APPROACH := preload("res://assets/shaders/waterfall_approach.gdshader")

@export_group("Размер потока")
@export_range(8.0, 384.0, 1.0) var stream_width: float = 64.0:
	set(value):
		stream_width = clampf(value, 8.0, 384.0)
		_request_refresh()
@export_range(64.0, 1024.0, 1.0) var drop_length: float = 240.0:
	set(value):
		drop_length = clampf(value, 64.0, 1024.0)
		_request_refresh()
@export_group("Вода")
## Length of visible surface flow before a lake-fed outlet; zero for springs.
@export_range(0.0, 64.0, 1.0) var approach_length: float = 0.0:
	set(value):
		approach_length = clampf(value, 0.0, 64.0)
		_request_refresh()
@export_range(0.0, 4.0, 0.05) var flow_speed: float = 1.0:
	set(value):
		flow_speed = clampf(value, 0.0, 4.0)
		_request_refresh()
@export var water_tint: Color = Color(0.90, 0.98, 1.0, 1.0):
	set(value):
		water_tint = value
		_request_refresh()
@export_range(0.0, 0.8, 0.01) var cloud_fade: float = 0.28:
	set(value):
		cloud_fade = clampf(value, 0.0, 0.8)
		_request_refresh()
@export var show_lip: bool = true:
	set(value):
		show_lip = value
		_request_refresh()
@export_group("Предпросмотр")
@export var animate_in_editor: bool = false:
	set(value):
		animate_in_editor = value
		_request_refresh()

var stream: ColorRect
var flow_material: ShaderMaterial
var approach: ColorRect
var approach_material: ShaderMaterial
var left_cap: Sprite2D
var right_cap: Sprite2D
var clock: float = 0.0

## Legacy/data-driven outlets still use this; scene instances use the exports.
func setup(width: float, length: float, phase: float = 0.0, speed: float = 1.0) -> void:
	stream_width = width
	drop_length = length
	flow_speed = speed
	clock = fposmod(phase, 120.0)
	if stream != null:
		_refresh()

func _ready() -> void:
	if not ResourceLoader.exists(ATLAS):
		return
	stream = get_node_or_null("Flow") as ColorRect
	if stream == null:
		stream = ColorRect.new()
		stream.name = "Flow"
		stream.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stream)
	flow_material = ShaderMaterial.new()
	flow_material.shader = FLOW
	flow_material.set_shader_parameter("atlas", load(ATLAS))
	stream.material = flow_material
	approach = get_node_or_null("Approach") as ColorRect
	if approach == null:
		approach = ColorRect.new()
		approach.name = "Approach"
		approach.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(approach)
	approach_material = ShaderMaterial.new()
	approach_material.shader = APPROACH
	approach.material = approach_material
	left_cap = _cap("res://assets/world_hd/props/waterfall_lip_left.png", "LeftBank")
	right_cap = _cap("res://assets/world_hd/props/waterfall_lip_right.png", "RightBank")
	_refresh()

func _cap(path: String, child_name: String) -> Sprite2D:
	if not ResourceLoader.exists(path):
		return null
	var cap := get_node_or_null(NodePath(child_name)) as Sprite2D
	if cap == null:
		cap = Sprite2D.new()
		cap.name = child_name
		add_child(cap)
	cap.texture = load(path)
	cap.scale = Vector2.ONE * 0.5
	cap.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	cap.z_index = 1
	return cap

func _request_refresh() -> void:
	if is_inside_tree():
		_refresh.call_deferred()

func _refresh() -> void:
	if stream == null or flow_material == null:
		return
	stream.position = Vector2(-stream_width * 0.5, 0.0)
	stream.size = Vector2(stream_width, drop_length)
	if approach != null:
		approach.visible = approach_length > 0.0
		approach.position = Vector2(-stream_width * 0.5, -approach_length)
		# A slight overlap hides the planar seam at the brink.
		approach.size = Vector2(stream_width, approach_length + 3.0)
		approach_material.set_shader_parameter("surface_size", approach.size)
		approach_material.set_shader_parameter("water_tint", water_tint)
		approach_material.set_shader_parameter("clock", clock)
	if is_instance_valid(left_cap):
		left_cap.position = Vector2(-stream_width * 0.5 - 3.0, -2.0)
		left_cap.visible = show_lip
	if is_instance_valid(right_cap):
		right_cap.position = Vector2(stream_width * 0.5 + 3.0, -2.0)
		right_cap.visible = show_lip
	flow_material.set_shader_parameter("stream_width", stream_width)
	flow_material.set_shader_parameter("drop_length", drop_length)
	flow_material.set_shader_parameter("water_tint", water_tint)
	flow_material.set_shader_parameter("cloud_fade", cloud_fade)
	flow_material.set_shader_parameter("clock", clock)
	set_process(not Engine.is_editor_hint() or animate_in_editor)

func _process(delta: float) -> void:
	if flow_material == null:
		return
	# 120 is a common period of the atlas and flow phases, at every speed.
	clock = fposmod(clock + delta * flow_speed, 120.0)
	flow_material.set_shader_parameter("clock", clock)
	if approach_material != null:
		approach_material.set_shader_parameter("clock", clock)
