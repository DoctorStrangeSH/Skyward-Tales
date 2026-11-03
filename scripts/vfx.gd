extends RefCounted
class_name Vfx

## One-shot particle bursts and hit flashes. Pixel-sized square particles,
## nearest filtering, everything frees itself.

const FLASH_SHADER := preload("res://shaders/hit_flash.gdshader")

const SPELL_COLORS := {
	"fireball": [Color(1.0, 0.95, 0.6), Color(1.0, 0.55, 0.2), Color(0.8, 0.2, 0.2, 0.0)],
	"frostbolt": [Color(1, 1, 1), Color(0.6, 0.9, 1.0), Color(0.25, 0.5, 0.9, 0.0)],
	"chain_lightning": [Color(1, 1, 1), Color(0.8, 0.65, 1.0), Color(0.45, 0.3, 0.9, 0.0)],
}

static func _gradient(colors: Array) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	gradient.colors = PackedColorArray(colors)
	return gradient

## Radial burst at a world position.
static func burst(parent: Node, at: Vector2, colors: Array, amount: int = 12, speed: float = 60.0, lifetime: float = 0.45) -> CPUParticles2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 90)
	p.damping_min = 40.0
	p.damping_max = 80.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color_ramp = _gradient(colors)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.z_index = 40
	p.global_position = at
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p

static func spell_impact(parent: Node, at: Vector2, spell_id: String) -> void:
	burst(parent, at, SPELL_COLORS.get(spell_id, SPELL_COLORS["fireball"]), 14, 70.0, 0.4)

## Puff of smoke plus coloured bits when an enemy is defeated.
static func defeat(parent: Node, at: Vector2) -> void:
	burst(parent, at + Vector2(0, -8), [Color(1, 1, 1, 0.95), Color(0.85, 0.85, 0.95, 0.7), Color(0.6, 0.6, 0.75, 0.0)], 18, 45.0, 0.6)
	burst(parent, at + Vector2(0, -8), [Color(1.0, 0.95, 0.6), Color(1.0, 0.8, 0.3), Color(1.0, 0.6, 0.2, 0.0)], 8, 90.0, 0.5)

static func sparkle(parent: Node, at: Vector2) -> void:
	burst(parent, at + Vector2(0, -6), [Color(1, 1, 0.9), Color(1.0, 0.85, 0.4), Color(1.0, 0.7, 0.3, 0.0)], 10, 50.0, 0.55)

static func level_up(parent: Node, at: Vector2) -> void:
	var p := burst(parent, at + Vector2(0, -10), [Color(1, 1, 0.85), Color(1.0, 0.85, 0.35), Color(0.6, 0.9, 1.0, 0.0)], 32, 110.0, 0.9)
	if p != null:
		p.gravity = Vector2(0, -20)

## Gives a CanvasItem a private hit-flash material.
static func enable_flash(item: CanvasItem) -> void:
	var material := ShaderMaterial.new()
	material.shader = FLASH_SHADER
	item.material = material

static func flash(item: CanvasItem, color: Color = Color.WHITE, duration: float = 0.14) -> void:
	if item == null or not item.is_inside_tree() or not item.material is ShaderMaterial:
		return
	var material := item.material as ShaderMaterial
	material.set_shader_parameter("flash_color", color)
	material.set_shader_parameter("flash", 1.0)
	var tween := item.create_tween()
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter("flash", v), 1.0, 0.0, duration)
