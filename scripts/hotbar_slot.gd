extends Control
class_name HotbarSlot

## One square of the action bar: frame, icon, key, cooldown shade, count,
## lock. Skill slots (1–4) accept a skill dragged from the hero window.

signal skill_dropped(slot_index: int, skill_id: String)

const SIZE := Vector2(24, 24)

var key_text: String = ""
var icon: Texture2D
var cooldown: float = 0.0
var locked: String = ""
var count: int = -1
var skill_name: String = ""
## 0..3 for skill slots (drop targets), -1 otherwise.
var skill_index: int = -1
## Shown under the count, e.g. mana cost.
var note: String = ""
var _hover := false

func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())

func apply(entry: Dictionary) -> void:
	var path := str(entry.get("icon", ""))
	var next_icon: Texture2D = WorldArt.texture(path) if not path.is_empty() and ResourceLoader.exists("res://assets/" + path) else null
	var next_cooldown := float(entry.get("cooldown", 0.0))
	var next_locked := str(entry.get("locked", ""))
	var next_count := int(entry.get("count", -1))
	var next_note := str(entry.get("note", ""))
	if next_icon == icon and is_equal_approx(next_cooldown, cooldown) and next_locked == locked and next_count == count and key_text == str(entry.get("key", "")) and next_note == note and skill_name == str(entry.get("name", "")):
		return
	icon = next_icon
	cooldown = next_cooldown
	locked = next_locked
	count = next_count
	note = next_note
	key_text = str(entry.get("key", ""))
	skill_name = str(entry.get("name", ""))
	tooltip_text = str(entry.get("tooltip", skill_name))
	queue_redraw()

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return skill_index >= 0 and data is Dictionary and data.has("skill_id")

func _drop_data(_at: Vector2, data: Variant) -> void:
	skill_dropped.emit(skill_index, str(data["skill_id"]))

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, SIZE)
	var ready_glow := Color(0, 0, 0, 0)
	if icon != null and cooldown <= 0.0 and locked.is_empty() and count != 0:
		ready_glow = Color(1.0, 0.85, 0.5, 0.18)
	UiStyle.draw_slot(self, rect, _hover, ready_glow)
	if icon != null:
		var tint := Color(0.45, 0.45, 0.5) if not locked.is_empty() or count == 0 else Color.WHITE
		draw_texture_rect(icon, Rect2(Vector2(4, 4), Vector2(16, 16)), false, tint)
	if cooldown > 0.0:
		var shade_height := (SIZE.y - 2) * cooldown
		draw_rect(Rect2(Vector2(1, SIZE.y - 1 - shade_height), Vector2(SIZE.x - 2, shade_height)), Color(0.05, 0.05, 0.12, 0.7))
	var font := UiFont.font()
	var font_size := UiFont.px(7)
	UiStyle.draw_key(self, Vector2(2, 8), key_text)
	var corner := note if not note.is_empty() else (str(count) if count >= 0 else "")
	if not corner.is_empty():
		draw_string_outline(font, Vector2(0, SIZE.y - 2), corner, HORIZONTAL_ALIGNMENT_RIGHT, SIZE.x - 2, font_size, 3, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(0, SIZE.y - 2), corner, HORIZONTAL_ALIGNMENT_RIGHT, SIZE.x - 2, font_size, Color(0.75, 0.88, 1.0) if not note.is_empty() else Color.WHITE)
	if not locked.is_empty():
		var text := locked if locked.length() <= 5 else "✦"
		draw_string_outline(font, Vector2(0, SIZE.y - 3), text, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, font_size, 3, Color(0, 0, 0, 0.95))
		draw_string(font, Vector2(0, SIZE.y - 3), text, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, font_size, Color(0.85, 0.85, 0.95))
