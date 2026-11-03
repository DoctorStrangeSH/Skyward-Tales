extends Control
class_name WorldMinimap

const WORLD_SIZE := Vector2(1280.0, 864.0)
const MAP_SIZE := Vector2(116.0, 78.0)
var region_id: String = "greenreach"
var hero_position: Vector2 = Vector2(130, 210)
var known_landmarks: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(132, 108)
	queue_redraw()

func update_map(new_region: String, position: Vector2, landmarks: Dictionary) -> void:
	if region_id == new_region and hero_position.distance_squared_to(position) < 1.0 and known_landmarks == landmarks:
		return
	region_id = new_region
	hero_position = position
	known_landmarks = landmarks.duplicate(true)
	queue_redraw()

func _map_point(point: Vector2) -> Vector2:
	return Vector2(8.0, 25.0) + Vector2(clampf(point.x / WORLD_SIZE.x, 0.0, 1.0), clampf(point.y / WORLD_SIZE.y, 0.0, 1.0)) * MAP_SIZE

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(132, 108)), Color(0.03, 0.06, 0.08, 0.88))
	var name: String = "ЗАЧАРОВАННЫЙ ЛЕС" if region_id == "moonlit_grove" else "ЗЕЛЁНЫЕ ПРЕДЕЛЫ"
	draw_string(ThemeDB.fallback_font, Vector2(7, 16), name, HORIZONTAL_ALIGNMENT_LEFT, 126, 10, Color(0.92, 0.88, 0.64))
	draw_rect(Rect2(Vector2(8, 25), MAP_SIZE), Color(0.11, 0.27, 0.23) if region_id == "moonlit_grove" else Color(0.18, 0.32, 0.19))
	# Simple route silhouette, matching each region's general direction.
	var route: Array = [Vector2(70, 205), Vector2(320, 245), Vector2(630, 255), Vector2(900, 205), Vector2(1120, 205)] if region_id == "greenreach" else [Vector2(40, 430), Vector2(330, 360), Vector2(650, 445), Vector2(960, 365), Vector2(1220, 365)]
	for i in range(route.size() - 1):
		draw_line(_map_point(route[i]), _map_point(route[i + 1]), Color(0.57, 0.45, 0.29), 2.0)
	for id in known_landmarks:
		var data: Dictionary = known_landmarks[id]
		var coordinates: Array = data.get("position", [])
		if coordinates.size() != 2:
			continue
		var marker_kind: String = str(data.get("kind", ""))
		var color: Color = Color(0.95, 0.81, 0.38) if marker_kind == "npc" else (Color(0.82, 0.55, 1.0) if marker_kind == "secret" else Color(0.38, 0.83, 0.98))
		draw_rect(Rect2(_map_point(Vector2(float(coordinates[0]), float(coordinates[1]))) - Vector2(2, 2), Vector2(4, 4)), color)
	var hero: Vector2 = _map_point(hero_position)
	draw_circle(hero, 3.0, Color(1.0, 0.95, 0.9))
	draw_arc(hero, 4.5, 0, TAU, 12, Color(0.07, 0.10, 0.13), 1.0)
