extends Node2D
class_name WorldNpc

signal interacted(source: Node2D)

const DIRECTIONAL_SPRITE_SCRIPT := preload("res://scripts/directional_sprite.gd")

@export var display_name: String = "Путник"
@export var outfit_color: Color = Color(0.53, 0.36, 0.66)
## Selects assets/sprites/npcs/<npc_id>.png; unknown ids fall back to a drawn figure.
@export var npc_id: String = ""

var visual: DirectionalSprite
## "", "quest", "ready" or "service" — set by SkywardGame every few frames.
var marker: String = ""
## Companions travel with the hero and are never cleared with the region.
var is_companion: bool = false
var _marker_time: float = 0.0
## Daily life (VillageLife): walking between spots, speech bubbles, sleep.
var walk_speed: float = 38.0
## Another character's sprite to wear ("look" in the region data).
var look_id: String = ""
var asleep: bool = false
var sleep_on_arrival: bool = false
var bubble_text: String = ""
var bubble_time: float = 0.0
var _path: Array = []
var _life_clock: float = 0.0
var _idle_moving: bool = false

func _ready() -> void:
	add_to_group("interactables")
	var sheet := "res://assets/sprites/npcs/%s.png" % npc_id
	var look := look_id if not look_id.is_empty() else npc_id
	if not look.is_empty() and DIRECTIONAL_SPRITE_SCRIPT.has_chibi(look):
		visual = DIRECTIONAL_SPRITE_SCRIPT.new() as DirectionalSprite
		visual.configure_chibi(look, 9.0)
		visual.set_direction_vector(Vector2.DOWN)
		visual.set_moving(false)
		add_child(visual)
	elif not npc_id.is_empty() and ResourceLoader.exists(sheet):
		visual = DIRECTIONAL_SPRITE_SCRIPT.new() as DirectionalSprite
		visual.configure(sheet, 4, 8, 1.0, 2.5)
		visual.offset = Vector2(0.0, -14.0)
		visual.set_direction_vector(Vector2.DOWN)
		visual.set_moving(true)  # gentle idle breathing
		_idle_moving = true
		add_child(visual)
	GroundShadows.attach(self, 14.0)
	queue_redraw()

func interact() -> void:
	# Asleep behind a door: no conversation, only a sleepy answer to a knock.
	if asleep and get_parent() != null and get_parent().has_method("knock_on_door"):
		get_parent().knock_on_door(self)
		return
	interacted.emit(self)

## A short line in a bubble above the head.
func say(text: String, duration: float = 4.5) -> void:
	bubble_text = text
	bubble_time = duration
	queue_redraw()

## Walks through the points; on arrival may fall asleep (go indoors).
func walk_path(points: Array, sleep_after: bool = false) -> void:
	_path = points.duplicate()
	sleep_on_arrival = sleep_after
	_wake()
	if visual != null:
		visual.set_moving(true)

func stop_walking() -> void:
	_path.clear()
	if visual != null:
		visual.set_direction_vector(Vector2.DOWN)
		visual.set_moving(_idle_moving)

func is_walking() -> bool:
	return not _path.is_empty()

func set_asleep(value: bool) -> void:
	asleep = value
	if visual != null:
		visual.visible = not value
	queue_redraw()

func _wake() -> void:
	if asleep:
		set_asleep(false)

func set_marker(kind: String) -> void:
	if kind != marker:
		marker = kind
		queue_redraw()

func _process(delta: float) -> void:
	_life_clock += delta
	if not marker.is_empty():
		_marker_time += delta
		queue_redraw()
	if bubble_time > 0.0:
		bubble_time -= delta
		if bubble_time <= 0.0:
			bubble_text = ""
		queue_redraw()
	if asleep:
		queue_redraw()
	if not _path.is_empty():
		var target: Vector2 = _path[0]
		var step := walk_speed * delta
		var to := target - global_position
		if to.length() <= step:
			global_position = target
			_path.pop_front()
			if _path.is_empty():
				if visual != null:
					visual.set_direction_vector(Vector2.DOWN)
					visual.set_moving(_idle_moving)
				if sleep_on_arrival:
					set_asleep(true)
		else:
			global_position += to.normalized() * step
			if visual != null:
				visual.set_direction_vector(to)

func _draw() -> void:
	if asleep:
		# Indoors: only a sleepy "z z" above the door.
		var font := UiFont.font()
		for i in 2:
			var rise := fmod(_life_clock * 0.6 + i * 0.5, 1.0)
			draw_string(font, Vector2(4 + i * 4 + rise * 4, -14 - rise * 12), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8 + i * 2), Color(0.85, 0.9, 1.0, 1.0 - rise))
	if not bubble_text.is_empty():
		_draw_bubble()
	if not marker.is_empty():
		# Gentle bob so the marker catches the eye.
		var bob := roundf(sin(_marker_time * 4.0) * 1.5)
		WorldArt.draw_prop(self, "props/marker_%s.png" % marker, false, Vector2(0, -30 + bob))
		draw_set_transform(Vector2.ZERO)
	if visual != null:
		return
	draw_rect(Rect2(-7, 5, 14, 4), Color(0.10, 0.12, 0.15, 0.4))
	draw_rect(Rect2(-5, -2, 10, 10), outfit_color)
	draw_rect(Rect2(-4, -9, 8, 8), Color(0.84, 0.65, 0.48))
	draw_rect(Rect2(-5, -11, 10, 4), Color(0.77, 0.78, 0.80))

func _draw_bubble() -> void:
	var font := UiFont.font()
	var font_size := UiFont.px(8)
	var width := minf(124.0, font.get_string_size(bubble_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 8.0)
	var lines := font.get_multiline_string_size(bubble_text, HORIZONTAL_ALIGNMENT_LEFT, width - 8.0, font_size)
	var height := lines.y + 4.0
	var top := -44.0 - height if marker.is_empty() else -58.0 - height
	var box := Rect2(-width * 0.5, top, width, height)
	var fade := clampf(bubble_time / 0.4, 0.0, 1.0)
	draw_rect(box.grow(1), Color(0.15, 0.1, 0.06, 0.9 * fade))
	draw_rect(box, Color(1.0, 0.97, 0.9, 0.95 * fade))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, box.end.y), Vector2(3, box.end.y), Vector2(0, box.end.y + 4)]), Color(1.0, 0.97, 0.9, 0.95 * fade))
	draw_multiline_string(font, box.position + Vector2(4, font_size), bubble_text, HORIZONTAL_ALIGNMENT_LEFT, width - 8.0, font_size, -1, Color(0.2, 0.13, 0.08, fade))
