extends Node2D
class_name FarmBed

## One garden bed: tilled soil and the plant at its growth stage.

var farm: Farm
var index: int = 0
var _clock: float = 0.0

func _ready() -> void:
	add_to_group("interactables")
	z_index = -30

func interact() -> void:
	farm.use_bed(index)
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	var soil := Color(0.36, 0.24, 0.15)
	var watered: bool = bool(farm.beds.get(index, {}).get("watered", false)) or farm.level() >= 3
	if watered and farm.beds.has(index):
		soil = Color(0.26, 0.17, 0.11)
	draw_rect(Rect2(-15, -9, 30, 18), Color(0.22, 0.14, 0.08))
	draw_rect(Rect2(-14, -8, 28, 16), soil)
	for row in 3:
		draw_line(Vector2(-12, -5 + row * 5), Vector2(12, -5 + row * 5), soil.darkened(0.25), 1.0)
	var g := farm.growth(index)
	if g < 0.0:
		return
	var crop := farm.crop_of(index)
	var color: Color = Farm.CROP_COLORS.get(crop, Color.WHITE)
	var sway := sin(_clock * 2.0 + index) * 0.6
	for i in 3:
		var base := Vector2(-9 + i * 9, 4)
		var height := lerpf(2.0, 11.0, g)
		var leaf := Color(0.35, 0.7, 0.3).lerp(Color(0.5, 0.75, 0.3), g)
		draw_line(base, base + Vector2(sway, -height), leaf, 1.5)
		if g > 0.3:
			draw_line(base + Vector2(sway * 0.5, -height * 0.5), base + Vector2(-3 + sway, -height * 0.7), leaf, 1.0)
			draw_line(base + Vector2(sway * 0.5, -height * 0.5), base + Vector2(3 + sway, -height * 0.75), leaf, 1.0)
		if g >= 1.0:
			var top := base + Vector2(sway, -height)
			if crop == "wheat":
				draw_line(top, top + Vector2(0, -4), color, 2.0)
			else:
				draw_circle(top, 2.2, color)
				draw_circle(top + Vector2(1, 0), 1.0, color.lightened(0.4))
	if g >= 1.0:
		var pulse := 0.5 + 0.5 * sin(_clock * 4.0)
		draw_circle(Vector2(0, -20), 2.0 + pulse, Color(1.0, 0.95, 0.6, 0.7))
