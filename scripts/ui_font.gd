extends RefCounted
class_name UiFont

## The pixel font (assets/fonts/skyward_pixel.ttf, built by tools/art/font.py)
## is drawn on a 9-pixel grid: only sizes 9, 18 and 27 stay crisp. Every font
## size in the UI goes through px() so old sizes snap onto that grid.

const BASE := 9

static func px(size: int) -> int:
	if size <= 12:
		return BASE
	if size <= 23:
		return BASE * 2
	return BASE * 3

## The project theme's font, for custom _draw() code in any CanvasItem.
static func font() -> Font:
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.default_font != null:
		return theme.default_font
	return ThemeDB.fallback_font
