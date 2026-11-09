extends PanelContainer
class_name ActivitiesPanel

## «Занятия» tab (owner's list №33): every activity of the world as a card —
## open or still locked (and how to open it), progress, where to find it.

var grid: GridContainer
var summary: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.panel(false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiStyle.label("ЗАНЯТИЯ МИРА", 13, UiStyle.TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	summary = UiStyle.label("", 8, UiStyle.MUTED)
	head.add_child(summary)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(596, 292)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	visible = false

func populate(rows: Array[Dictionary]) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var open := 0
	for row in rows:
		if bool(row["open"]):
			open += 1
		grid.add_child(_card(row))
	summary.text = "открыто %d из %d" % [open, rows.size()]

func _card(row: Dictionary) -> Control:
	var is_open := bool(row["open"])
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(290, 50)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.1, 0.95) if is_open else Color(0.1, 0.09, 0.1, 0.9)
	style.border_color = Color(0.85, 0.66, 0.35, 0.8) if is_open else Color(0.4, 0.36, 0.36, 0.6)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	card.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiStyle.label(("" if is_open else "🔒 ") + str(row["title"]), 9, Color(1.0, 0.88, 0.56) if is_open else Color(0.62, 0.6, 0.6))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiStyle.label(str(row["group"]), 7, UiStyle.MUTED))
	if is_open and not str(row["progress"]).is_empty():
		box.add_child(UiStyle.label(str(row["progress"]), 8, Color(0.6, 1.0, 0.65)))
	var where := UiStyle.label("Где: " + str(row["where"]), 7, Color(0.75, 0.85, 0.95))
	where.clip_text = true
	where.custom_minimum_size = Vector2(280, 0)
	box.add_child(where)
	var how := UiStyle.label(str(row["how"]), 7, Color(0.85, 0.82, 0.76) if is_open else Color(1.0, 0.75, 0.5))
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(280, 0)
	box.add_child(how)
	return card
