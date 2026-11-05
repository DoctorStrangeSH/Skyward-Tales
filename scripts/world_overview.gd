extends Control
class_name WorldOverview

## The whole world (map tab "Мир"): every land as a little floating island
## drawn from its own thumbnail, at its "map_pos" from regions.json, rope
## bridges between gates, caves and dungeons as dark entrances. Shows the
## hero, awakened sky stones (◆ — click the land to travel there), quest
## badges (! main / ! side / ? reward) and the road to the main goal.

signal travel_requested(region_id: String)

const MARGIN_X := 46.0
const MARGIN_TOP := 32.0
const MARGIN_BOTTOM := 40.0
## World units → map pixels for island size.
const ISLAND_SCALE := 54.0 / 1280.0
const BADGE_SIZE := Vector2(46, 22)
const LABEL_BELOW := ["ruins_depths"]

var current: String = ""
var visited: Dictionary = {}
var awake: Array = []
var badges: Dictionary = {}
var goal_route: Array = []
var hovered: String = ""
var _clock := 0.0
var _clouds: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 14:
		_clouds.append([rng.randf(), rng.randf(), rng.randf_range(10, 22), rng.randf_range(0.6, 1.4)])

func set_world(current_region: String, visited_regions: Dictionary, awake_regions: Array = [], quest_badges: Dictionary = {}, route: Array = []) -> void:
	current = current_region
	visited = visited_regions.duplicate()
	awake = awake_regions.duplicate()
	badges = quest_badges.duplicate(true)
	goal_route = route.duplicate()
	queue_redraw()

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_clock += delta
		queue_redraw()

func _point(region_id: String) -> Vector2:
	var p: Variant = RegionCatalog.get_region(region_id).get("map_pos", [0.5, 0.5])
	var usable := size - Vector2(MARGIN_X * 2.0, MARGIN_TOP + MARGIN_BOTTOM)
	return Vector2(MARGIN_X, MARGIN_TOP) + Vector2(float(p[0]), float(p[1])) * usable

func _underground(region_id: String) -> bool:
	return RegionCatalog.is_underground(RegionCatalog.style(region_id))

func _seen(region_id: String) -> bool:
	return visited.has(region_id) or region_id == current

## The land's footprint on the map.
func _rect(region_id: String) -> Rect2:
	var at := _point(region_id)
	if _underground(region_id):
		return Rect2(at - BADGE_SIZE * 0.5, BADGE_SIZE)
	var terrain_size: Array = RegionCatalog.terrain(region_id).get("size", [1280, 864])
	var island := Vector2(float(terrain_size[0]), float(terrain_size[1])) * ISLAND_SCALE
	return Rect2((at - island * 0.5).round(), island.round())

func region_at(point: Vector2) -> String:
	for region_id in RegionCatalog.ids():
		if _rect(region_id).grow(4).has_point(point):
			return str(region_id)
	return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var now := region_at(event.position)
		if now != hovered:
			hovered = now
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var region_id := region_at(event.position)
		if not region_id.is_empty() and awake.has(region_id) and region_id != current:
			travel_requested.emit(region_id)
			accept_event()

## What the bottom line says about the hovered land.
func info_text() -> String:
	if hovered.is_empty():
		return "◆ — небесный камень пробуждён: щёлкните по земле, чтобы переместиться.   ! — задание   ? — награда"
	if not _seen(hovered):
		return "Неизведанная земля. Рекомендуемый уровень: %d." % RegionCatalog.level(hovered)
	var text := "%s · ур. %d" % [RegionCatalog.display_name(hovered), RegionCatalog.level(hovered)]
	if hovered == current:
		text += " — вы здесь"
	elif awake.has(hovered):
		text += " — ЛКМ: переместиться"
	elif RegionCatalog.waystone(hovered) is Array:
		text += " — небесный камень спит"
	var marks: Dictionary = badges.get(hovered, {})
	if marks.has("main"):
		text += " · сюжет"
	if marks.has("side"):
		text += " · задание"
	if marks.has("turnin"):
		text += " · награда ждёт"
	if marks.has("offer"):
		text += " · новое задание"
	return text

# --- Drawing ------------------------------------------------------------------

func _draw() -> void:
	_draw_sky()
	var regions := RegionCatalog.all()
	var drawn := {}
	for region_id in regions:
		for gate in regions[region_id].get("gates", []):
			var target := str(gate.get("target", ""))
			var key := [str(region_id), target]
			key.sort()
			if not regions.has(target) or drawn.has(str(key)):
				continue
			drawn[str(key)] = true
			_draw_link(str(region_id), target)
	_draw_route()
	for region_id in regions:
		if not _underground(str(region_id)):
			_draw_island(str(region_id))
	for region_id in regions:
		if _underground(str(region_id)):
			_draw_cave(str(region_id))
	for region_id in regions:
		_draw_marks(str(region_id))
	_draw_info()

func _draw_sky() -> void:
	var top := Color(0.2, 0.32, 0.55)
	var bottom := Color(0.5, 0.66, 0.84)
	var bands := 12
	for i in bands:
		var t := float(i) / bands
		draw_rect(Rect2(0, size.y * t, size.x, size.y / bands + 1.0), top.lerp(bottom, t))
	# Slow clouds, soft and round.
	for cloud in _clouds:
		var x := fmod(float(cloud[0]) * size.x + _clock * 3.0 * float(cloud[3]), size.x + 60.0) - 30.0
		var y := float(cloud[1]) * size.y
		var r := float(cloud[2])
		var color := Color(1, 1, 1, 0.13)
		draw_circle(Vector2(x, y), r, color)
		draw_circle(Vector2(x + r * 0.9, y + 2), r * 0.75, color)
		draw_circle(Vector2(x - r * 0.9, y + 3), r * 0.6, color)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.45, 0.27), false, 1.0)

func _edge_point(region_id: String, toward: Vector2) -> Vector2:
	var rect := _rect(region_id)
	var center := rect.get_center()
	var direction := (toward - center)
	if direction.length() < 0.01:
		return center
	var half := rect.size * 0.5
	var t := minf(half.x / maxf(0.001, absf(direction.x)), half.y / maxf(0.001, absf(direction.y)))
	return center + direction * minf(t, 1.0)

func _draw_link(a: String, b: String) -> void:
	var known := _seen(a) and _seen(b)
	var half_known := _seen(a) or _seen(b)
	var start := _edge_point(a, _point(b))
	var end := _edge_point(b, _point(a))
	if _underground(a) or _underground(b):
		# Stairs into the dark: a dotted line.
		var steps := int(start.distance_to(end) / 4.0)
		for i in steps:
			if i % 2 == 0:
				draw_line(start.lerp(end, float(i) / steps), start.lerp(end, float(i + 1) / steps), Color(0.15, 0.1, 0.08, 0.8 if half_known else 0.3), 1.5)
		return
	# A rope bridge with a gentle sag.
	var alpha := 1.0 if known else (0.55 if half_known else 0.2)
	var points := PackedVector2Array()
	var count := 14
	for i in count + 1:
		var t := float(i) / count
		points.append(start.lerp(end, t) + Vector2(0, sin(t * PI) * 5.0))
	draw_polyline(points, Color(0.2, 0.13, 0.08, alpha), 3.0)
	draw_polyline(points, Color(0.78, 0.6, 0.38, alpha), 1.0)
	for i in range(1, count):
		var p := points[i]
		draw_line(p + Vector2(0, -1.5), p + Vector2(0, 1.5), Color(0.45, 0.3, 0.18, alpha), 1.0)

## The road to the main goal: glowing dashes along the bridges.
func _draw_route() -> void:
	if goal_route.size() < 2:
		return
	for i in goal_route.size() - 1:
		var a := str(goal_route[i])
		var b := str(goal_route[i + 1])
		var start := _point(a)
		var end := _point(b)
		var length := start.distance_to(end)
		var dash := 6.0
		var offset := fmod(_clock * 14.0, dash * 2.0)
		var d := -offset
		while d < length:
			var from := start.lerp(end, clampf(d / length, 0, 1)) + Vector2(0, sin(clampf(d / length, 0, 1) * PI) * 5.0)
			var to := start.lerp(end, clampf((d + dash) / length, 0, 1)) + Vector2(0, sin(clampf((d + dash) / length, 0, 1) * PI) * 5.0)
			draw_line(from, to, Color(1.0, 0.82, 0.3, 0.95), 2.0)
			d += dash * 2.0

func _rock_colors(region_id: String) -> Array:
	match RegionCatalog.style(region_id):
		"ash":
			return [Color(0.3, 0.2, 0.18), Color(0.18, 0.12, 0.11)]
		"sky", "spires", "rift":
			return [Color(0.56, 0.52, 0.64), Color(0.38, 0.34, 0.48)]
		"coast":
			return [Color(0.66, 0.56, 0.4), Color(0.46, 0.38, 0.28)]
		"mountain":
			return [Color(0.5, 0.48, 0.48), Color(0.34, 0.32, 0.34)]
	return [Color(0.48, 0.34, 0.22), Color(0.3, 0.2, 0.13)]

func _draw_island(region_id: String) -> void:
	var rect := _rect(region_id)
	var seen := _seen(region_id)
	var bob := sin(_clock * 1.2 + rect.position.x * 0.05) * 1.0
	rect.position.y += round(bob)
	var x0 := rect.position.x
	var x1 := rect.end.x
	var y1 := rect.end.y
	var w := rect.size.x
	var cx := rect.get_center().x
	var depth := rect.size.y * 0.45
	# Shadow on the clouds.
	draw_set_transform(Vector2(cx, y1 + depth + 8.0), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, w * 0.4, Color(0.05, 0.08, 0.2, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The rock underneath.
	var rock: Array = _rock_colors(region_id)
	var cliff := PackedVector2Array([Vector2(x0, y1 - 1), Vector2(x1, y1 - 1), Vector2(x1 - 3, y1 + depth * 0.35),
		Vector2(x1 - w * 0.22, y1 + depth * 0.7), Vector2(cx + w * 0.06, y1 + depth), Vector2(cx - w * 0.1, y1 + depth * 0.8),
		Vector2(x0 + w * 0.2, y1 + depth * 0.55), Vector2(x0 + 3, y1 + depth * 0.25)])
	draw_colored_polygon(cliff, rock[1] if seen else Color(0.25, 0.27, 0.35))
	var band := PackedVector2Array([Vector2(x0, y1 - 1), Vector2(x1, y1 - 1), Vector2(x1 - 3, y1 + depth * 0.3), Vector2(x0 + 3, y1 + depth * 0.25)])
	draw_colored_polygon(band, rock[0] if seen else Color(0.32, 0.34, 0.42))
	# The land itself.
	var texture: Texture2D = null
	if seen and ResourceLoader.exists("res://assets/world/%s_mini.png" % region_id):
		texture = WorldArt.texture("world/%s_mini.png" % region_id)
	if texture != null:
		draw_texture_rect(texture, rect, false)
	else:
		draw_rect(rect, RegionCatalog.map_color(region_id).darkened(0.55) if seen else Color(0.52, 0.6, 0.72))
	if not seen:
		# Unexplored land hides under clouds.
		var mid := rect.get_center()
		var puff := Color(0.93, 0.95, 1.0, 0.9)
		for offset in [Vector2(-0.28, 0.1), Vector2(0.0, -0.12), Vector2(0.27, 0.08), Vector2(-0.05, 0.22)]:
			draw_circle(mid + Vector2(offset.x * rect.size.x, offset.y * rect.size.y), rect.size.y * 0.3, puff)
		var font := UiFont.font()
		draw_string_outline(font, rect.get_center() + Vector2(-3, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(12), 3, Color(1, 1, 1))
		draw_string(font, rect.get_center() + Vector2(-3, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(12), Color(0.55, 0.62, 0.78))
	draw_rect(rect, Color(0.12, 0.08, 0.05) if seen else Color(0.4, 0.45, 0.58), false, 1.5)
	draw_line(rect.position + Vector2(1, 1), Vector2(x1 - 1, rect.position.y + 1), Color(1, 1, 1, 0.25), 1.0)
	if hovered == region_id:
		draw_rect(rect.grow(2.5), Color(1.0, 0.86, 0.45), false, 1.5)
	_draw_label(region_id, Vector2(cx, rect.position.y - 5.0), seen)

func _draw_cave(region_id: String) -> void:
	var rect := _rect(region_id)
	var seen := _seen(region_id)
	var magma := RegionCatalog.style(region_id) == "magma"
	draw_rect(rect.grow(1.5), Color(0.08, 0.06, 0.05))
	draw_rect(rect, Color(0.24, 0.2, 0.22) if seen else Color(0.28, 0.3, 0.36))
	# The cave mouth: an arch with a glow inside.
	var mouth := rect.get_center() + Vector2(0, 4)
	var glow := Color(1.0, 0.45, 0.15) if magma else (Color(0.55, 0.85, 1.0) if RegionCatalog.style(region_id) == "cave" else Color(0.55, 0.9, 0.6))
	draw_circle(mouth + Vector2(0, -3), 7.0, Color(0.05, 0.03, 0.04))
	draw_rect(Rect2(mouth + Vector2(-7, -3), Vector2(14, 8)), Color(0.05, 0.03, 0.04))
	if seen:
		draw_circle(mouth + Vector2(0, 0), 3.0 + 0.6 * sin(_clock * 3.0), Color(glow, 0.7))
	for side in [-1, 1]:
		draw_rect(Rect2(mouth + Vector2(side * 11 - 2, -6), Vector2(4, 11)), Color(0.4, 0.36, 0.38) if seen else Color(0.4, 0.42, 0.48))
	if hovered == region_id:
		draw_rect(rect.grow(3.0), Color(1.0, 0.86, 0.45), false, 1.5)
	if region_id in LABEL_BELOW:
		_draw_label(region_id, Vector2(rect.get_center().x, rect.end.y + 11.0), seen)
	else:
		_draw_label(region_id, Vector2(rect.end.x + 4.0, rect.get_center().y + 3.0), seen, true)

func _draw_label(region_id: String, at: Vector2, seen: bool, left_aligned: bool = false) -> void:
	var font := UiFont.font()
	var text := RegionCatalog.display_name(region_id) if seen else "???"
	var level := "%d" % RegionCatalog.level(region_id)
	var font_size := UiFont.px(8)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var level_width := font.get_string_size(level, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 6.0
	var total := width + level_width + 3.0
	var start := Vector2(at.x if left_aligned else at.x - total * 0.5, at.y)
	start.x = clampf(start.x, 2.0, size.x - total - 2.0)
	var plaque := Rect2(start + Vector2(-3, -8), Vector2(total + 6, 11))
	draw_rect(plaque, Color(0.1, 0.07, 0.05, 0.82))
	var danger := RegionCatalog.level(region_id) > 0 and current != "" and RegionCatalog.level(region_id) >= RegionCatalog.level(current) + 4
	draw_string(font, start, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.98, 0.92, 0.78) if seen else Color(0.75, 0.75, 0.8))
	var level_at := start + Vector2(width + 3.0, 0)
	draw_rect(Rect2(level_at + Vector2(0, -7), Vector2(level_width, 9)), Color(0.75, 0.25, 0.2) if danger else Color(0.25, 0.4, 0.6))
	draw_string(font, level_at + Vector2(3, 0), level, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

## Sky stone, quest badges and the hero on top of every land.
func _draw_marks(region_id: String) -> void:
	var rect := _rect(region_id)
	var font := UiFont.font()
	var pulse := 0.5 + 0.5 * sin(_clock * 4.0)
	if RegionCatalog.waystone(region_id) is Array and _seen(region_id):
		var at := Vector2(rect.end.x - 2, rect.position.y + 2)
		if awake.has(region_id):
			draw_circle(at, 6.0 + pulse, Color(0.4, 0.95, 1.0, 0.3))
			_diamond(at, 4.5, Color(0.06, 0.12, 0.16))
			_diamond(at, 3.4, Color(0.5, 0.97, 1.0))
		else:
			_diamond(at, 4.0, Color(0.06, 0.12, 0.16, 0.8))
			_diamond(at, 2.6, Color(0.4, 0.45, 0.5))
	var marks: Dictionary = badges.get(region_id, {})
	var x := rect.position.x + 2.0
	for kind in ["main", "side", "turnin", "offer"]:
		if not marks.has(kind):
			continue
		var at := Vector2(x, rect.position.y + 2)
		var color: Color = QuestColors.GOLD if kind == "main" or marks.has(kind + "_main") else QuestColors.BLUE
		var radius := 5.0 if kind == "main" else 4.0
		if kind == "main":
			draw_circle(at, radius + 2.0 + pulse * 1.5, Color(color, 0.3))
		draw_circle(at, radius + 1.0, Color(0.1, 0.06, 0.04))
		draw_circle(at, radius, color)
		draw_string(font, at + Vector2(-2, 3), "?" if kind == "turnin" else "!", HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), Color(0.1, 0.06, 0.04))
		x += radius * 2.0 + 2.0
	if region_id == current:
		var hero := rect.get_center() + Vector2(0, -2)
		draw_arc(hero, 7.0 + pulse * 2.0, 0.0, TAU, 20, Color(1, 1, 1, 0.7), 1.2)
		draw_colored_polygon(PackedVector2Array([hero + Vector2(-4, -8), hero + Vector2(4, -8), hero + Vector2(0, -1)]), Color(0.1, 0.06, 0.06))
		draw_circle(hero + Vector2(0, -10), 4.5, Color(0.1, 0.06, 0.06))
		draw_colored_polygon(PackedVector2Array([hero + Vector2(-3, -8.5), hero + Vector2(3, -8.5), hero + Vector2(0, -2.5)]), Color(0.86, 0.2, 0.2))
		draw_circle(hero + Vector2(0, -10), 3.3, Color(0.86, 0.2, 0.2))
		draw_circle(hero + Vector2(0, -10), 1.3, Color(1, 0.95, 0.9))

func _diamond(at: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius, 0), at + Vector2(0, radius), at + Vector2(-radius, 0)]), color)

func _draw_info() -> void:
	var font := UiFont.font()
	var bar := Rect2(0, size.y - 14, size.x, 14)
	draw_rect(bar, Color(0.06, 0.04, 0.03, 0.85))
	draw_string(font, bar.position + Vector2(6, 10), info_text(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, UiFont.px(8), Color(1.0, 0.9, 0.65) if not hovered.is_empty() else Color(0.8, 0.85, 0.9))
