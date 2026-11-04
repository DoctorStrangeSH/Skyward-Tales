extends RefCounted
class_name UiStyle

## Interface frames in the pack's warm wood style (assets/ui/*.png, built by
## tools/art/village.py): nine-slice panels and plank buttons. Panels use
## UiStyle.panel(); buttons get UiStyle.style_button(button).

const PANEL := "res://assets/ui/panel.png"
const PANEL_GOLD := "res://assets/ui/panel_gold.png"
const TEXT := Color(0.96, 0.92, 0.82)
const TITLE := Color(1.0, 0.84, 0.5)
const MUTED := Color(0.78, 0.7, 0.6)

static var _cache: Dictionary = {}

static func _box(path: String, margin: int, content: int) -> StyleBox:
	var key := "%s:%d:%d" % [path, margin, content]
	if _cache.has(key):
		return _cache[key]
	if not ResourceLoader.exists(path):
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.13, 0.09, 0.08, 0.96)
		flat.set_content_margin_all(content)
		return flat
	var box := StyleBoxTexture.new()
	box.texture = load(path)
	box.texture_margin_left = margin
	box.texture_margin_top = margin
	box.texture_margin_right = margin
	box.texture_margin_bottom = margin
	box.set_content_margin_all(content)
	_cache[key] = box
	return box

## Big windows (journal, bag, skills, pause, dialogue).
static func panel(gold: bool = false, content: int = 9) -> StyleBox:
	return _box(PANEL_GOLD if gold else PANEL, 8, content)

## Small HUD frames (spell bar, toasts).
static func small_panel() -> StyleBox:
	return _box(PANEL, 8, 5)

static func button_box(state: String) -> StyleBox:
	var box := _box("res://assets/ui/button_%s.png" % state, 4, 3)
	if box is StyleBoxTexture:
		(box as StyleBoxTexture).content_margin_left = 6
		(box as StyleBoxTexture).content_margin_right = 6
	return box

static func style_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, button_box(state))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	button.add_theme_color_override("font_disabled_color", MUTED * Color(1, 1, 1, 0.6))
