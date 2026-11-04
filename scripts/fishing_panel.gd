extends PanelContainer
class_name FishingPanel

## On-screen fishing helper: what to do now, the reel bar (green zone, fish)
## and the catch progress.

var hint: Label
var bar: Control
var progress: ProgressBar
var _fishing: Fishing
var _fish_icon: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(240, 0)
	position = Vector2(200, 244)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiStyle.panel(false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	var title := Label.new()
	title.text = "РЫБАЛКА"
	title.add_theme_font_size_override("font_size", UiFont.px(11))
	title.add_theme_color_override("font_color", UiStyle.TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", UiFont.px(9))
	hint.add_theme_color_override("font_color", UiStyle.TEXT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(224, 0)
	box.add_child(hint)
	bar = Control.new()
	bar.custom_minimum_size = Vector2(224, 16)
	bar.draw.connect(_draw_bar)
	box.add_child(bar)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(224, 6)
	progress.show_percentage = false
	progress.max_value = 1.0
	box.add_child(progress)
	_fish_icon = WorldArt.texture("icons/fish.png")
	visible = false

func show_for(fishing: Fishing) -> void:
	_fishing = fishing
	visible = true
	refresh()

func refresh() -> void:
	if _fishing == null:
		return
	match _fishing.state:
		"waiting":
			hint.text = "Ждём поклёвку… Подсекайте, когда поплавок нырнёт (E / ЛКМ). Шаг в сторону — смотать удочку."
		"bite":
			hint.text = "КЛЮЁТ! Жмите E / ЛКМ!"
		"reel":
			hint.text = "Тяните! Держите E / ЛКМ — зона идёт вверх, отпустите — вниз. Держите рыбу в зелёной зоне."
	var reeling := _fishing.state == "reel"
	bar.visible = reeling
	progress.visible = reeling
	progress.value = _fishing.progress
	bar.queue_redraw()

func _draw_bar() -> void:
	if _fishing == null:
		return
	var w := bar.size.x
	var h := bar.size.y
	bar.draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.16, 0.26, 0.95))
	bar.draw_rect(Rect2(0, 0, w, h), Color(0.62, 0.45, 0.27), false, 1.0)
	var inside := _fishing.fish_inside()
	var zone_color := Color(0.35, 0.9, 0.4, 0.75) if inside else Color(0.35, 0.75, 0.4, 0.45)
	bar.draw_rect(Rect2(1 + _fishing.zone * (w - 2), 1, _fishing.zone_width * (w - 2), h - 2), zone_color)
	var fx := 1 + _fishing.fish_pos * (w - 2)
	if _fish_icon != null:
		bar.draw_texture(_fish_icon, Vector2(fx - 8, h * 0.5 - 8))
