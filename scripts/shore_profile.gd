extends RefCounted
class_name ShoreProfile

## One authored southern coastline, in world pixels, shared by art and physics.
const MAX_POINTS := 32
const STRIP := 8.0

static func points(terrain: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in terrain.get("south_shore", []):
		result.append(Vector2(float(point[0]), float(point[1])))
	return result

static func height_at(profile: PackedVector2Array, x: float, fallback: float) -> float:
	if profile.is_empty():
		return fallback
	for i in range(1, profile.size()):
		if x <= profile[i].x:
			var a := profile[i - 1]
			var b := profile[i]
			return lerpf(a.y, b.y, clampf((x - a.x) / (b.x - a.x), 0.0, 1.0))
	return profile[-1].y

static func apply(material: ShaderMaterial, profile: PackedVector2Array, rim_y: float) -> void:
	var padded := profile.duplicate()
	padded.resize(MAX_POINTS)
	material.set_shader_parameter("shore_points", padded)
	material.set_shader_parameter("shore_count", profile.size())
	material.set_shader_parameter("rim_y", rim_y)

## A conservative eight-pixel staircase. These same rectangles enter navigation.
static func walls(profile: PackedVector2Array, size: Vector2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if profile.is_empty():
		return result
	var x := 0.0
	while x < size.x:
		var end := minf(x + STRIP, size.x)
		var top := minf(height_at(profile, x, size.y), height_at(profile, end, size.y))
		# Include authored corners that fall inside this strip.
		for point in profile:
			if point.x > x and point.x < end:
				top = minf(top, point.y)
		if top < size.y:
			result.append(Rect2(x, top, end - x, size.y - top + 16.0))
		x = end
	return result

## Old cached thumbnails also follow the runtime contour, until art is rebuilt.
static func clip_thumbnail(image: Image, profile: PackedVector2Array, size: Vector2) -> void:
	if profile.is_empty():
		return
	image.convert(Image.FORMAT_RGBA8)
	var scale := size / Vector2(image.get_size())
	for x in image.get_width():
		var edge := height_at(profile, (float(x) + 0.5) * scale.x, size.y)
		var first := maxi(0, int(floor(edge / scale.y + 0.5)))
		for y in range(first, image.get_height()):
			var color := image.get_pixel(x, y)
			color.a = 0.0
			image.set_pixel(x, y, color)
