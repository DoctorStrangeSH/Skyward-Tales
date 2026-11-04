extends Control
class_name WorldOverview

## The whole world at a glance (map tab "Мир"): every land at its
## "map_pos" from regions.json, roads between gates, levels; lands never
## visited are shown as "???".

var current: String = ""
var visited: Dictionary = {}

func set_world(current_region: String, visited_regions: Dictionary) -> void:
	current = current_region
	visited = visited_regions.duplicate()
	queue_redraw()

func _point(region_id: String) -> Vector2:
	var p: Variant = RegionCatalog.get_region(region_id).get("map_pos", [0.5, 0.5])
	return Vector2(20, 18) + Vector2(float(p[0]), float(p[1])) * (size - Vector2(40, 36))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.09, 0.07))
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(0.86, 0.76, 0.56, 0.06))
	var regions := RegionCatalog.all()
	for region_id in regions:
		for gate in regions[region_id].get("gates", []):
			var target := str(gate.get("target", ""))
			if regions.has(target) and str(region_id) < target:
				var known := visited.has(region_id) or visited.has(target)
				draw_line(_point(region_id), _point(target), Color(0.75, 0.6, 0.4, 0.8 if known else 0.25), 2.0)
	var font := UiFont.font()
	for region_id in regions:
		var at := _point(region_id)
		var seen := visited.has(region_id)
		var color := RegionCatalog.map_color(region_id) if seen else Color(0.35, 0.32, 0.3)
		draw_circle(at, 7.0, Color(0.13, 0.09, 0.08))
		draw_circle(at, 5.0, color)
		if region_id == current:
			draw_arc(at, 10.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.45), 2.0)
		var label := "%s · %d" % [RegionCatalog.display_name(region_id), RegionCatalog.level(region_id)] if seen else "???"
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(9)).x
		var p: Array = RegionCatalog.get_region(region_id).get("map_pos", [0.5, 0.5])
		var above := float(p[1]) > 0.2 and float(p[1]) <= 0.5
		var text_at := Vector2(clampf(at.x - width / 2.0, 2.0, size.x - width - 2.0), at.y - 11.0 if above else at.y + 19.0)
		draw_string_outline(font, text_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(9), 3, Color(0.08, 0.05, 0.04))
		draw_string(font, text_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(9), Color(0.96, 0.9, 0.78) if seen else Color(0.6, 0.56, 0.5))
