extends Control
class_name HotbarSlot

## One square of the skill bar: frame, icon, key, cooldown shade, lock.

const SIZE := Vector2(24, 24)

var key_text: String = ""
var icon: Texture2D
var cooldown: float = 0.0
var locked: String = ""
var count: int = -1
var skill_name: String = ""

func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func apply(entry: Dictionary) -> void:
	var path := str(entry.get("icon", ""))
	var next_icon: Texture2D = WorldArt.texture(path) if not path.is_empty() and ResourceLoader.exists("res://assets/" + path) else null
	var next_cooldown := float(entry.get("cooldown", 0.0))
	var next_locked := str(entry.get("locked", ""))
	var next_count := int(entry.get("count", -1))
	if next_icon == icon and is_equal_approx(next_cooldown, cooldown) and next_locked == locked and next_count == count and key_text == str(entry.get("key", "")):
		return
	icon = next_icon
	cooldown = next_cooldown
	locked = next_locked
	count = next_count
	key_text = str(entry.get("key", ""))
	skill_name = str(entry.get("name", ""))
	tooltip_text = skill_name
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, SIZE)
	draw_rect(rect, Color(0.09, 0.06, 0.06, 0.88))
	draw_rect(rect.grow(-1), Color(0.24, 0.16, 0.11, 0.9), false, 1.0)
	draw_rect(rect, Color(0.62, 0.45, 0.27), false, 1.0)
	if icon != null:
		var tint := Color(0.45, 0.45, 0.5) if not locked.is_empty() or count == 0 else Color.WHITE
		draw_texture_rect(icon, Rect2(Vector2(4, 4), Vector2(16, 16)), false, tint)
	if cooldown > 0.0:
		var shade_height := (SIZE.y - 2) * cooldown
		draw_rect(Rect2(Vector2(1, SIZE.y - 1 - shade_height), Vector2(SIZE.x - 2, shade_height)), Color(0.05, 0.05, 0.12, 0.7))
	var font := UiFont.font()
	var font_size := UiFont.px(8)
	if not key_text.is_empty():
		draw_string_outline(font, Vector2(2, 8), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(2, 8), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.9, 0.6))
	if count >= 0:
		var text := str(count)
		draw_string_outline(font, Vector2(0, SIZE.y - 2), text, HORIZONTAL_ALIGNMENT_RIGHT, SIZE.x - 2, font_size, 3, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(0, SIZE.y - 2), text, HORIZONTAL_ALIGNMENT_RIGHT, SIZE.x - 2, font_size, Color.WHITE)
	if not locked.is_empty():
		var text := locked if locked.length() <= 5 else "✦"
		draw_string_outline(font, Vector2(0, SIZE.y - 3), text, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, font_size, 3, Color(0, 0, 0, 0.95))
		draw_string(font, Vector2(0, SIZE.y - 3), text, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, font_size, Color(0.85, 0.85, 0.95))
