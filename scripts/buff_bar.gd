extends Control
class_name BuffBar

## The hero's active effects as badges with seconds left (art from the
## owner's pack: assets/ui/status, tools/art/village_life_art.py). Long
## effects (blessings of the tower) show no timer. Hover-free: the name of
## the newest effect is written under the row.

const ICONS := {"power": "strength", "attack": "strength", "armor": "shield", "defense": "shield", "speed": "haste",
	"regen": "regeneration", "heal": "healing", "crit": "burn", "slow": "slow", "poison": "poison", "freeze": "freeze", "curse": "curse"}
const SIZE := 16.0

var buffs: Dictionary = {}
var _textures: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_buffs(value: Dictionary) -> void:
	buffs = value
	queue_redraw()

static func icon_for(type: String) -> String:
	return str(ICONS.get(type, "healing"))

func _texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var path := "res://assets/ui/status/%s.png" % name
		_textures[name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[name]

func _draw() -> void:
	var font := UiFont.font()
	var x := size.x - SIZE
	var names: Array[String] = []
	for type in buffs:
		var buff: Dictionary = buffs[type]
		var texture := _texture(icon_for(str(type)))
		if texture != null:
			draw_texture_rect(texture, Rect2(x, 0, SIZE, SIZE), false)
		else:
			draw_circle(Vector2(x + SIZE / 2.0, SIZE / 2.0), SIZE / 2.0 - 1.0, Color(0.4, 0.8, 0.5))
		var left := float(buff.get("time", 0.0))
		if left < 3600.0:
			var text := "%d" % int(ceil(left)) if left < 100.0 else "%dм" % int(left / 60.0)
			draw_string_outline(font, Vector2(x - 2, SIZE + 8), text, HORIZONTAL_ALIGNMENT_CENTER, SIZE + 4, UiFont.px(7), 3, Color(0.04, 0.05, 0.1))
			draw_string(font, Vector2(x - 2, SIZE + 8), text, HORIZONTAL_ALIGNMENT_CENTER, SIZE + 4, UiFont.px(7), Color(0.85, 1.0, 0.85))
		names.append(str(buff.get("label", type)))
		x -= SIZE + 4.0
	if not names.is_empty():
		var line := " · ".join(names)
		draw_string_outline(font, Vector2(0, SIZE + 19), line, HORIZONTAL_ALIGNMENT_RIGHT, size.x, UiFont.px(7), 3, Color(0.04, 0.05, 0.1))
		draw_string(font, Vector2(0, SIZE + 19), line, HORIZONTAL_ALIGNMENT_RIGHT, size.x, UiFont.px(7), Color(0.72, 1.0, 0.72))
