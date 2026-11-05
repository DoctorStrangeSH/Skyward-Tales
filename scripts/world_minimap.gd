extends Control
class_name WorldMinimap

## Minimap. `follow` (HUD): a window over the region's real thumbnail
## (assets/world/<region>_mini.png, 1/6 scale) centred on the hero, sky
## beyond the island's rim. Otherwise (M map) the whole region fitted in.
## Icons: quest givers (! / ?), exits, chests, sky stones, fishing spots,
## workshops, quest items, enemies (elites, bosses) and the hero's heading.

const WORLD_SIZE := Vector2(1280.0, 864.0)
const THUMB_SCALE := 6.0
const HUD_SIZE := Vector2(150, 116)
const AREA := Rect2(4, 18, 142, 94)

var region_id: String = "greenreach"
var hero_position: Vector2 = Vector2(270, 625)
var facing := Vector2.DOWN
var known_landmarks: Dictionary = {}
## Live icons this frame: {"kind", "position": Vector2, "label"?}.
var live: Array = []
var follow: bool = true
## Day progress 0..1 (DayNight.time) and whether the sky is seen here.
var day_time: float = -1.0
var _thumb: Texture2D
var _thumb_region: String = ""
var _clock: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if follow:
		custom_minimum_size = HUD_SIZE
		size = HUD_SIZE
	queue_redraw()

func update_map(new_region: String, position: Vector2, landmarks: Dictionary) -> void:
	region_id = new_region
	hero_position = position
	known_landmarks = landmarks
	queue_redraw()

func set_live(markers: Array, heading: Vector2) -> void:
	live = markers
	if heading.length() > 0.1:
		facing = heading.normalized()
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta

func _world_size() -> Vector2:
	var value: Variant = RegionCatalog.terrain(region_id).get("size", [WORLD_SIZE.x, WORLD_SIZE.y])
	return Vector2(float(value[0]), float(value[1]))

func _area() -> Rect2:
	return AREA if follow else Rect2(Vector2.ZERO, size)

## Pixels per world unit in the current mode.
func _scale() -> float:
	if follow:
		return 1.0 / THUMB_SCALE
	var world := _world_size()
	return minf(size.x / world.x, size.y / world.y)

func _origin() -> Vector2:
	var area := _area()
	if follow:
		return area.get_center() - hero_position * _scale()
	var world := _world_size() * _scale()
	return area.position + (area.size - world) * 0.5

func _map_point(point: Vector2) -> Vector2:
	return _origin() + point * _scale()

func _texture() -> Texture2D:
	if _thumb_region != region_id:
		_thumb_region = region_id
		var path := "world/%s_mini.png" % region_id
		_thumb = WorldArt.texture(path) if ResourceLoader.exists("res://assets/" + path) else null
	return _thumb

func _draw() -> void:
	var area := _area()
	var style := RegionCatalog.style(region_id)
	var cave := RegionCatalog.is_underground(style)
	if follow:
		# Frame: dark wood, a gold line, the region banner.
		draw_rect(Rect2(Vector2.ZERO, HUD_SIZE), Color(0.17, 0.11, 0.08, 0.95))
		draw_rect(Rect2(Vector2(1, 1), HUD_SIZE - Vector2(2, 2)), Color(0.85, 0.66, 0.38), false, 1.0)
		var font := UiFont.font()
		draw_string(font, Vector2(6, 13), RegionCatalog.display_name(region_id).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 110, UiFont.px(9), Color(1.0, 0.9, 0.62))
		draw_string(font, Vector2(6, 13), "ур. %d" % RegionCatalog.level(region_id), HORIZONTAL_ALIGNMENT_RIGHT, HUD_SIZE.x - 24, UiFont.px(8), Color(0.75, 0.85, 1.0))
		_draw_sky_clock(Vector2(HUD_SIZE.x - 10, 9))
	# Beyond the island: sky (or rock underground).
	var beyond := Color(0.62, 0.78, 0.94)
	if cave:
		beyond = Color(0.12, 0.1, 0.16)
	elif style == "ash":
		beyond = Color(0.34, 0.22, 0.2)
	elif style in ["night", "marsh", "rift"]:
		beyond = Color(0.2, 0.24, 0.42)
	draw_rect(area, beyond)
	var texture := _texture()
	var world_rect := Rect2(_origin(), _world_size() * _scale())
	var visible := world_rect.intersection(area)
	if texture != null and visible.has_area():
		var source := Rect2((visible.position - world_rect.position) / world_rect.size * texture.get_size(), visible.size / world_rect.size * texture.get_size())
		draw_texture_rect_region(texture, visible, source)
	elif visible.has_area():
		draw_rect(visible, RegionCatalog.map_color(region_id))
	if visible.has_area() and not cave:
		# The island rim.
		draw_rect(world_rect.intersection(area.grow(1)), Color(0.3, 0.24, 0.2, 0.9), false, 1.0)
	for marker in _all_markers():
		var at := _map_point(marker["position"])
		var kind: String = marker["kind"]
		if not area.grow(-2).has_point(at):
			if kind in ["goal_main", "goal_gate"]:
				_draw_edge_arrow(area, at, Color(1.0, 0.78, 0.2), 1.4)
			elif kind in ["goal_side", "ready", "quest"]:
				_draw_edge_arrow(area, at, QuestColors.GOLD if bool(marker.get("main", false)) else QuestColors.BLUE)
			elif kind in ["gate", "treasure", "rift"] and follow:
				_draw_edge_arrow(area, at, Color(0.95, 0.95, 0.8, 0.7))
			continue
		_draw_marker(kind, at, str(marker.get("label", "")), bool(marker.get("main", false)))
	_draw_hero(_map_point(hero_position))
	if follow:
		draw_rect(area, Color(0.1, 0.07, 0.06), false, 1.0)

## Discovered landmarks (saved) and live icons together.
func _all_markers() -> Array:
	var result: Array = []
	for id in known_landmarks:
		var data: Dictionary = known_landmarks[id]
		var coordinates: Array = data.get("position", [])
		if coordinates.size() != 2:
			continue
		var kind := str(data.get("kind", ""))
		if kind in ["npc", "gate", "chest"]:
			continue  # live icons carry the current state
		result.append({"kind": kind, "position": Vector2(float(coordinates[0]), float(coordinates[1]))})
	result.append_array(live)
	return result

func _draw_marker(kind: String, at: Vector2, label: String, main: bool = false) -> void:
	var font := UiFont.font()
	var pulse := 0.5 + 0.5 * sin(_clock * 5.0)
	match kind:
		"npc":
			draw_rect(Rect2(at - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.95, 0.92, 0.85))
		"quest", "ready":
			var color := QuestColors.GOLD if main else QuestColors.BLUE
			draw_circle(at, 4.0 + pulse, Color(color, 0.25))
			draw_circle(at, 3.0, Color(0.1, 0.07, 0.05))
			draw_string(font, at + Vector2(-2, 3), "!" if kind == "quest" else "?", HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), color)
		"service":
			draw_circle(at, 2.5, QuestColors.GREEN)
		"gate":
			draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), Color(0.1, 0.07, 0.05))
			draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.92, 0.7))
			if not follow and not label.is_empty():
				var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8)).x
				var spot := Vector2(clampf(at.x - width * 0.5, 2, size.x - width - 2), clampf(at.y - 6, 9, size.y - 2))
				draw_string_outline(font, spot, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), 3, Color(0, 0, 0, 0.9))
				draw_string(font, spot, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), Color(1.0, 0.92, 0.7))
		"chest":
			draw_rect(Rect2(at - Vector2(2.5, 2), Vector2(5, 4)), Color(0.55, 0.33, 0.16))
			draw_line(at + Vector2(-2.5, -0.5), at + Vector2(2.5, -0.5), Color(1.0, 0.82, 0.3), 1.0)
		"waystone":
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -4), at + Vector2(3, 0), at + Vector2(0, 4), at + Vector2(-3, 0)]), Color(0.45, 0.95, 1.0))
		"station":
			draw_rect(Rect2(at - Vector2(2, 1.5), Vector2(4, 3)), Color(0.8, 0.8, 0.85))
		"fish":
			draw_line(at + Vector2(-2, 0), at + Vector2(2, 0), Color(0.75, 0.95, 1.0), 1.0)
			draw_line(at + Vector2(-1, -1.5), at + Vector2(1, -1.5), Color(0.75, 0.95, 1.0), 1.0)
		"item":
			draw_circle(at, 1.5 + pulse, Color(1.0, 0.95, 0.5, 0.9))
		"enemy":
			draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.3, 0.25))
		"elite":
			draw_circle(at, 2.5, Color(1.0, 0.55, 0.15))
		"boss":
			draw_circle(at, 4.0 + pulse, Color(0.8, 0.2, 0.9, 0.35))
			draw_circle(at, 3.0, Color(0.6, 0.15, 0.7))
			draw_rect(Rect2(at - Vector2(1.5, 1), Vector2(1, 1)), Color.WHITE)
			draw_rect(Rect2(at + Vector2(0.5, -1), Vector2(1, 1)), Color.WHITE)
		"treasure":
			var red := Color(0.95, 0.2, 0.15)
			draw_line(at + Vector2(-3, -3), at + Vector2(3, 3), Color(0, 0, 0), 3.0)
			draw_line(at + Vector2(-3, 3), at + Vector2(3, -3), Color(0, 0, 0), 3.0)
			draw_line(at + Vector2(-3, -3), at + Vector2(3, 3), red, 1.5)
			draw_line(at + Vector2(-3, 3), at + Vector2(3, -3), red, 1.5)
		"rift":
			draw_circle(at, 4.5 + pulse, Color(0.7, 0.35, 1.0, 0.3))
			draw_circle(at, 3.0, Color(0.15, 0.05, 0.25))
			draw_arc(at, 2.4, _clock * 3.0, _clock * 3.0 + PI * 1.3, 8, Color(0.95, 0.75, 1.0), 1.0)
		"goal_main", "goal_side":
			var gold := QuestColors.GOLD if kind == "goal_main" else QuestColors.BLUE
			draw_circle(at, 5.5 + pulse * 1.5, Color(gold, 0.25))
			_draw_diamond(at, 4.2, Color(0.12, 0.08, 0.04))
			_draw_diamond(at, 3.0, gold)
			draw_rect(Rect2(at + Vector2(-0.5, -2), Vector2(1, 2.5)), Color(0.12, 0.08, 0.04))
			draw_rect(Rect2(at + Vector2(-0.5, 1), Vector2(1, 1)), Color(0.12, 0.08, 0.04))
		"goal_gate":
			draw_arc(at, 6.0 + pulse * 1.5, 0.0, TAU, 16, Color(1.0, 0.8, 0.2, 0.9), 1.2)
			draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), Color(0.1, 0.07, 0.05))
			draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.8, 0.2))
			if not label.is_empty():
				var text := "→ " + label
				var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8)).x
				var spot := Vector2(clampf(at.x - width * 0.5, _area().position.x + 1, _area().end.x - width - 1), clampf(at.y - 8, _area().position.y + 8, _area().end.y - 2))
				draw_string_outline(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), 3, Color(0, 0, 0, 0.9))
				draw_string(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), Color(1.0, 0.85, 0.35))
		"secret":
			draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color(0.82, 0.55, 1.0))
		_:
			draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color(0.38, 0.83, 0.98))

## Sun by day, moon by night, grey underground.
func _draw_sky_clock(at: Vector2) -> void:
	if day_time < 0.0:
		draw_circle(at, 3.5, Color(0.45, 0.42, 0.5))
		return
	var night := day_time >= 0.8 or day_time < 0.22
	if night:
		draw_circle(at, 3.8, Color(0.92, 0.94, 1.0))
		draw_circle(at + Vector2(1.6, -1.0), 3.2, Color(0.17, 0.11, 0.08))
	else:
		var warm := day_time < 0.32 or day_time >= 0.7
		draw_circle(at, 4.6, Color(1.0, 0.7, 0.3, 0.35))
		draw_circle(at, 3.4, Color(1.0, 0.62, 0.3) if warm else Color(1.0, 0.88, 0.35))

func _draw_diamond(at: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius, 0), at + Vector2(0, radius), at + Vector2(-radius, 0)]), color)

func _draw_edge_arrow(area: Rect2, at: Vector2, color: Color, size_mult: float = 1.0) -> void:
	var center := area.get_center()
	var direction := (at - center).normalized()
	var inner := area.grow(-5)
	var t := INF
	if absf(direction.x) > 0.001:
		t = minf(t, ((inner.end.x if direction.x > 0 else inner.position.x) - center.x) / direction.x)
	if absf(direction.y) > 0.001:
		t = minf(t, ((inner.end.y if direction.y > 0 else inner.position.y) - center.y) / direction.y)
	var tip := center + direction * t
	var side := Vector2(-direction.y, direction.x)
	var a := tip + direction * 3.0 * size_mult
	var b := tip - direction * 2.0 * size_mult + side * 2.5 * size_mult
	var c := tip - direction * 2.0 * size_mult - side * 2.5 * size_mult
	draw_colored_polygon(PackedVector2Array([a + direction, b + side - direction, c - side - direction]), Color(0.08, 0.05, 0.03, 0.9))
	draw_colored_polygon(PackedVector2Array([a, b, c]), color)

func _draw_hero(at: Vector2) -> void:
	var side := Vector2(-facing.y, facing.x)
	var points := PackedVector2Array([at + facing * 5.0, at - facing * 3.0 + side * 3.5, at - facing * 1.5, at - facing * 3.0 - side * 3.5])
	var outline := PackedVector2Array([at + facing * 6.5, at - facing * 4.2 + side * 4.8, at - facing * 2.0, at - facing * 4.2 - side * 4.8])
	draw_colored_polygon(outline, Color(0.08, 0.06, 0.1))
	draw_colored_polygon(points, Color(1.0, 0.97, 0.9))
