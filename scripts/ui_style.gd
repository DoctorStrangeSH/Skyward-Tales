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
const GOLD := Color(1.0, 0.82, 0.42)
const SLOT_BG := Color(0.07, 0.05, 0.045, 0.92)
const SLOT_EDGE := Color(0.45, 0.33, 0.22)

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

## Compact toggle (tabs, 1–4 slot buttons): gold when pressed.
static func small_toggle(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(2)
		box.set_content_margin_all(1)
		box.set_border_width_all(1)
		var on: bool = state.contains("pressed")
		box.bg_color = Color(0.55, 0.36, 0.16) if on else (Color(0.26, 0.18, 0.12) if state == "hover" else Color(0.16, 0.11, 0.08))
		box.border_color = Color(1.0, 0.84, 0.45) if on else Color(0.5, 0.38, 0.25)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", MUTED)
	button.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.75))
	button.add_theme_color_override("font_hover_pressed_color", Color(1, 0.95, 0.75))

# --- Shared building blocks (hero window, crafting, action bar) -------------

## A dark inset box with a thin wood edge (cards, slots, lists).
static func inset(background: Color = SLOT_BG, edge: Color = SLOT_EDGE, content: int = 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(content)
	return box

## Pack-art icons are 32 px; old ones 16. Big icons are shrunk to `max_side`
## and smoothed, small ones stay crisp.
static func fit_icon(button: Button, max_side: int) -> void:
	if button.icon != null and button.icon.get_width() > 16:
		button.add_theme_constant_override("icon_max_width", max_side)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		button.remove_theme_constant_override("icon_max_width")
		button.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE

static func label(text: String, font_size: int, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", UiFont.px(font_size))
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

## A section caption: gold small caps with a thin rule under it.
static func section(text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label(text.to_upper(), 9, TITLE))
	var rule := ColorRect.new()
	rule.color = Color(0.62, 0.45, 0.27, 0.6)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	return box

static func icon(path: String, side: int, dim: bool = false) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(side, side)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not path.is_empty() and ResourceLoader.exists("res://assets/" + path):
		rect.texture = WorldArt.texture(path)
	if dim:
		rect.modulate = Color(0.45, 0.45, 0.5)
	return rect

static func drag_preview(path: String) -> Control:
	var holder := Control.new()
	var rect := icon(path, 22)
	rect.position = Vector2(-11, -11)
	rect.size = Vector2(22, 22)
	rect.modulate = Color(1, 1, 1, 0.85)
	holder.add_child(rect)
	return holder

## Slot frame drawn by custom controls: dark well, wood edge, gold on hover.
static func draw_slot(item: CanvasItem, rect: Rect2, hot: bool, accent: Color = Color(0, 0, 0, 0)) -> void:
	item.draw_rect(rect, SLOT_BG)
	item.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, 2)), Color(0, 0, 0, 0.35))
	if accent.a > 0.0:
		item.draw_rect(rect.grow(-1), accent, false, 1.0)
	item.draw_rect(rect, GOLD if hot else SLOT_EDGE, false, 1.0)

static func draw_key(item: CanvasItem, at: Vector2, text: String, color: Color = Color(1.0, 0.9, 0.6)) -> void:
	if text.is_empty():
		return
	var font := UiFont.font()
	var size := UiFont.px(7)
	item.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.9))
	item.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
