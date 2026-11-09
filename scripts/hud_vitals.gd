extends Control
class_name HudVitals

## Compact health / mana / experience frame in the top-left corner.

var level: int = 1
var health: int = 100
var max_health: int = 100
var mana: int = 60
var max_mana: int = 60
var experience: int = 0
var experience_to_next: int = 40
var gold: int = 0
var skill_points: int = 0

const FRAME := Color(0.07, 0.06, 0.11, 0.86)
const BORDER := Color(0.93, 0.78, 0.47)
const HP := [Color(1.0, 0.55, 0.52), Color(0.86, 0.27, 0.33), Color(0.55, 0.14, 0.24)]
const MP := [Color(0.62, 0.86, 1.0), Color(0.29, 0.56, 0.93), Color(0.16, 0.29, 0.62)]
const XP := Color(0.98, 0.85, 0.42)

const KIT := "res://assets/ui/hud/"
static var _kit: Dictionary = {}

## The owner's HUD kit (stage 21, tools/art/ui_kit.py), drawn at half size.
static func kit(name: String) -> Texture2D:
	if not _kit.has(name):
		_kit[name] = load(KIT + name + ".png") as Texture2D if ResourceLoader.exists(KIT + name + ".png") else null
	return _kit[name]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(179, 60)
	size = custom_minimum_size
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func set_values(player: PlayerCharacter) -> void:
	level = player.level
	health = player.health
	max_health = maxi(1, player.max_health)
	mana = player.mana
	max_mana = maxi(1, player.max_mana)
	experience = player.experience
	experience_to_next = maxi(1, player.experience_to_next)
	gold = player.gold
	skill_points = SkillTree.available_points(player)
	queue_redraw()

func _draw() -> void:
	var font := UiFont.font()
	var panel := kit("vitals_panel")
	if panel == null:
		draw_rect(Rect2(0, 0, 179, 60), FRAME)
	else:
		draw_texture_rect(panel, Rect2(0, 0, 179, 60), false)
	# Level medallion.
	var badge := Vector2(27, 30)
	draw_circle(badge, 15.0, Color(0.09, 0.09, 0.2))
	var rim := kit("level_badge_rim")
	if rim != null:
		draw_texture_rect(rim, Rect2(badge - Vector2(19, 19), Vector2(38, 38)), false)
	var level_text := str(level)
	var text_w := font.get_string_size(level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(13)).x
	draw_string_outline(font, Vector2(badge.x - text_w / 2.0, badge.y + 5), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(13), 3, Color(0.05, 0.04, 0.08))
	draw_string(font, Vector2(badge.x - text_w / 2.0, badge.y + 5), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(13), Color(1.0, 0.93, 0.7))
	_bar(Rect2(62, 14, 78, 9), float(health) / max_health, "health_fill", HP, "%d/%d" % [health, max_health], "health")
	_bar(Rect2(62, 28, 78, 9), float(mana) / max_mana, "mana_fill", MP, "%d/%d" % [mana, max_mana], "mana")
	# Experience sliver.
	draw_rect(Rect2(50, 42, 90, 3), Color(0.05, 0.05, 0.1))
	draw_rect(Rect2(50, 42, 90.0 * clampf(float(experience) / experience_to_next, 0.0, 1.0), 3), XP)
	draw_rect(Rect2(50, 42, 90.0 * clampf(float(experience) / experience_to_next, 0.0, 1.0), 1), Color(1.0, 0.96, 0.75))
	# Unspent skill points: a small star on the medallion.
	if skill_points > 0:
		draw_circle(Vector2(40, 44), 6.0, Color(1.0, 0.8, 0.3))
		draw_string_outline(font, Vector2(37, 47), str(skill_points), HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), 2, Color(0.25, 0.15, 0.05))
		draw_string(font, Vector2(37, 47), str(skill_points), HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), Color(0.2, 0.1, 0.02))
	# Gold.
	var coins := kit("coins")
	if coins != null:
		draw_texture_rect(coins, Rect2(145, 11, 13, 13), false)
	else:
		draw_circle(Vector2(151, 17), 3.5, Color(1.0, 0.83, 0.36))
	var gold_text := str(gold)
	var gold_w := font.get_string_size(gold_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(9)).x
	draw_string_outline(font, Vector2(152 - gold_w / 2.0, 38), gold_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(9), 3, Color(0.05, 0.04, 0.08))
	draw_string(font, Vector2(152 - gold_w / 2.0, 38), gold_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(9), Color(1.0, 0.9, 0.6))

func _bar(rect: Rect2, ratio: float, fill_name: String, colors: Array, label: String, icon_name: String) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	var icon := kit(icon_name)
	if icon != null:
		draw_texture_rect(icon, Rect2(rect.position + Vector2(-13, -2), Vector2(13, 13)), false)
	var track := kit("empty_track")
	if track != null:
		draw_texture_rect(track, rect.grow_individual(2, 1, 2, 1), false)
	else:
		draw_rect(rect.grow(1), Color(0.03, 0.02, 0.05))
	var fill := kit(fill_name)
	var inner := Rect2(rect.position + Vector2(0, 1), Vector2(rect.size.x * ratio, rect.size.y - 2))
	if fill != null and ratio > 0.0:
		draw_texture_rect_region(fill, inner, Rect2(0, 0, fill.get_width() * ratio, fill.get_height()))
	elif ratio > 0.0:
		draw_rect(inner, colors[1])
	var font := UiFont.font()
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8)).x
	draw_string_outline(font, rect.position + Vector2((rect.size.x - w) / 2.0, 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), 3, Color(0.05, 0.04, 0.08))
	draw_string(font, rect.position + Vector2((rect.size.x - w) / 2.0, 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), Color.WHITE)
