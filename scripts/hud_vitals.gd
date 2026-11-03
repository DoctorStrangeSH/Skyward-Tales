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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(150, 40)
	size = custom_minimum_size

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
	var font := ThemeDB.fallback_font
	# Frame with a pixel bevel.
	draw_rect(Rect2(1, 1, 148, 38), FRAME)
	draw_rect(Rect2(0, 1, 150, 38), BORDER, false, 1.0)
	draw_rect(Rect2(2, 3, 146, 1), Color(1, 1, 1, 0.06))
	# Level badge.
	draw_circle(Vector2(15, 20), 11.0, Color(0.16, 0.12, 0.22))
	draw_arc(Vector2(15, 20), 11.0, 0.0, TAU, 24, BORDER, 1.5)
	var level_text := str(level)
	var text_w := font.get_string_size(level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string_outline(font, Vector2(15 - text_w / 2.0, 24), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.05, 0.04, 0.08))
	draw_string(font, Vector2(15 - text_w / 2.0, 24), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.93, 0.7))
	_bar(Rect2(31, 6, 82, 9), float(health) / max_health, HP, "%d/%d" % [health, max_health])
	_bar(Rect2(31, 18, 82, 9), float(mana) / max_mana, MP, "%d/%d" % [mana, max_mana])
	# Experience sliver.
	draw_rect(Rect2(31, 31, 82, 3), Color(0.12, 0.1, 0.16))
	draw_rect(Rect2(31, 31, 82.0 * clampf(float(experience) / experience_to_next, 0.0, 1.0), 3), XP)
	# Unspent skill points: a small star on the level badge.
	if skill_points > 0:
		draw_circle(Vector2(25, 31), 6.0, Color(1.0, 0.8, 0.3))
		draw_string_outline(font, Vector2(22, 34), str(skill_points), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0.25, 0.15, 0.05))
		draw_string(font, Vector2(22, 34), str(skill_points), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.2, 0.1, 0.02))
	# Gold.
	draw_circle(Vector2(123, 11), 3.5, Color(1.0, 0.83, 0.36))
	draw_circle(Vector2(122, 10), 1.2, Color(1.0, 0.96, 0.75))
	var gold_text := str(gold)
	draw_string_outline(font, Vector2(118, 28), gold_text, HORIZONTAL_ALIGNMENT_LEFT, 30, 9, 3, Color(0.05, 0.04, 0.08))
	draw_string(font, Vector2(118, 28), gold_text, HORIZONTAL_ALIGNMENT_LEFT, 30, 9, Color(1.0, 0.9, 0.6))

func _bar(rect: Rect2, ratio: float, colors: Array, label: String) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	draw_rect(rect.grow(1), Color(0.03, 0.02, 0.05))
	draw_rect(rect, Color(0.13, 0.11, 0.18))
	var fill := Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y))
	draw_rect(fill, colors[1])
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, 2)), colors[0])
	draw_rect(Rect2(fill.position + Vector2(0, fill.size.y - 2), Vector2(fill.size.x, 2)), colors[2])
	var font := ThemeDB.fallback_font
	draw_string_outline(font, rect.position + Vector2(3, 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.05, 0.04, 0.08))
	draw_string(font, rect.position + Vector2(3, 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
