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
	var planted := farm.beds.has(index)
	var watered: bool = planted and (bool(farm.beds[index].get("watered", false)) or farm.level() >= 3)
	WorldArt.draw_prop(self, "world/props/farm_soil_wet.png" if watered else "world/props/farm_soil.png")
	var g := farm.growth(index)
	if g < 0.0:
		return
	var crop := farm.crop_of(index)
	var stage := 2 if g >= 1.0 else (1 if g >= 0.45 else 0)
	var sway := sin(_clock * 2.0 + index) * 0.6
	if Farm.CROP_ART.has(crop):
		# Two rows of the crop's own sprite.
		var art := "world/props/crop_%s_%d.png" % [Farm.CROP_ART[crop], stage]
		WorldArt.draw_prop(self, art, false, Vector2(sway * 0.3, -1))
		WorldArt.draw_prop(self, art, true, Vector2(-sway * 0.3, 8))
	else:
		_draw_herbs(g, crop, sway)
	if g >= 1.0:
		var pulse := 0.5 + 0.5 * sin(_clock * 4.0)
		draw_circle(Vector2(0, -22), 2.0 + pulse, Color(1.0, 0.95, 0.6, 0.7))

## Herbs without sprites of their own: stems with a flower when ripe.
func _draw_herbs(g: float, crop: String, sway: float) -> void:
	var color: Color = Farm.CROP_COLORS.get(crop, Color.WHITE)
	for i in 6:
		var base := Vector2(-10 + (i % 3) * 10, -2 + (i / 3) * 9)
		var height := lerpf(2.0, 10.0, g)
		var leaf := Color(0.3, 0.62, 0.26).lerp(Color(0.45, 0.72, 0.3), g)
		draw_line(base, base + Vector2(sway, -height), leaf.darkened(0.25), 2.5)
		draw_line(base, base + Vector2(sway, -height), leaf, 1.5)
		if g > 0.3:
			draw_line(base + Vector2(sway * 0.5, -height * 0.5), base + Vector2(-3 + sway, -height * 0.7), leaf, 1.2)
			draw_line(base + Vector2(sway * 0.5, -height * 0.5), base + Vector2(3 + sway, -height * 0.75), leaf, 1.2)
		if g >= 1.0:
			var top := base + Vector2(sway, -height)
			draw_circle(top, 2.6, color.darkened(0.3))
			draw_circle(top, 2.0, color)
			draw_circle(top + Vector2(0.6, -0.6), 0.9, color.lightened(0.5))
