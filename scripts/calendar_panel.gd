extends PanelContainer
class_name CalendarPanel

## «Календарь» tab (N): the year as four rows of seasons, four days each.
## Every day shows its festivals, the fair and birthdays; today is framed,
## past days fade. On the right — what comes next. Clicking a day tells
## everything about it below.

const SEASON_COLORS := {
	"summer": Color(0.98, 0.78, 0.3),
	"autumn": Color(0.95, 0.5, 0.2),
	"winter": Color(0.7, 0.85, 1.0),
	"spring": Color(0.6, 0.92, 0.5),
}
const KIND_COLORS := {
	"festival": Color(1.0, 0.82, 0.35),
	"fair": Color(0.55, 0.9, 0.55),
	"birthday": Color(1.0, 0.6, 0.78),
}
const KIND_MARKS := {"festival": "★", "fair": "⚑", "birthday": "♥"}

var calendar: GameCalendar
var title: Label
var grid: GridContainer
var upcoming_box: VBoxContainer
var detail: Label
var _selected: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.panel(false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var name_label := UiStyle.label("КАЛЕНДАРЬ НЕБЕСНЫХ ОСТРОВОВ", 13, UiStyle.TITLE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	title = UiStyle.label("", 9, Color(1.0, 0.9, 0.65))
	head.add_child(title)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	box.add_child(body)
	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	body.add_child(grid)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 2)
	side.custom_minimum_size = Vector2(178, 0)
	body.add_child(side)
	side.add_child(UiStyle.label("СКОРО", 10, UiStyle.TITLE))
	upcoming_box = VBoxContainer.new()
	upcoming_box.add_theme_constant_override("separation", 3)
	side.add_child(upcoming_box)
	var legend := UiStyle.label("★ праздник   ⚑ ярмарка   ♥ день рождения", 7, UiStyle.MUTED)
	side.add_child(legend)
	detail = UiStyle.label("", 8, Color(0.88, 0.86, 0.8))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(590, 30)
	box.add_child(detail)
	visible = false

func populate(owner_calendar: GameCalendar) -> void:
	calendar = owner_calendar
	var today := calendar.today()
	var doy := GameCalendar.day_of_year(today)
	title.text = GameCalendar.date_text(today)
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	# Header row: the corner and the days of a season.
	grid.add_child(UiStyle.label("", 8))
	for d in Seasons.LENGTH:
		var head := UiStyle.label("%d-й день" % (d + 1), 8, UiStyle.MUTED)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.custom_minimum_size = Vector2(88, 0)
		grid.add_child(head)
	for s in Seasons.ORDER.size():
		var season := str(Seasons.ORDER[s])
		var season_label := UiStyle.label(str(Seasons.NAMES[season]), 10, SEASON_COLORS[season])
		season_label.custom_minimum_size = Vector2(46, 0)
		season_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(season_label)
		for d in Seasons.LENGTH:
			grid.add_child(_cell(s * Seasons.LENGTH + d, doy, season))
	for child in upcoming_box.get_children():
		upcoming_box.remove_child(child)
		child.queue_free()
	for event in calendar.upcoming(6):
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		var kind := str(event["kind"])
		row.add_child(UiStyle.label("%s %s" % [KIND_MARKS[kind], str(event["title"])], 8, KIND_COLORS[kind]))
		row.add_child(UiStyle.label("   " + GameCalendar.in_text(int(event["in"])), 7, Color(0.75, 0.85, 0.95) if int(event["in"]) > 0 else Color(0.6, 1.0, 0.65)))
		upcoming_box.add_child(row)
	_show_detail(doy if _selected < 0 else _selected)

func _cell(index: int, today_doy: int, season: String) -> Control:
	var events := calendar.events_on(index)
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(88, 54)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	var base: Color = SEASON_COLORS[season]
	var past := index < today_doy
	style.bg_color = Color(base.r * 0.22, base.g * 0.2, base.b * 0.2, 0.95) if not past else Color(0.1, 0.09, 0.1, 0.9)
	style.border_color = Color(1.0, 0.92, 0.55) if index == today_doy else (base.darkened(0.35) if index != _selected else base)
	style.set_border_width_all(2 if index == today_doy else 1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(3)
	cell.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(box)
	var number := UiStyle.label(("Сегодня" if index == today_doy else str(index % Seasons.LENGTH + 1)), 8, Color(1.0, 0.95, 0.7) if index == today_doy else (Color(0.5, 0.48, 0.5) if past else base.lightened(0.2)))
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(number)
	var shown := 0
	for event in events:
		if shown >= 3:
			break
		var kind := str(event["kind"])
		var short := str(event.get("short", event["title"]))
		var line := UiStyle.label("%s %s" % [KIND_MARKS[kind], short], 7, KIND_COLORS[kind].darkened(0.35) if past else KIND_COLORS[kind])
		line.clip_text = true
		line.custom_minimum_size = Vector2(82, 0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(line)
		shown += 1
	cell.tooltip_text = "\n".join(events.map(func(event: Dictionary) -> String: return str(event["title"])))
	cell.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_selected = index
			populate(calendar))
	return cell

func _show_detail(index: int) -> void:
	var season := GameCalendar.season_of_year_day(index)
	var lines: Array[String] = []
	for event in calendar.events_on(index):
		lines.append("%s %s — %s" % [KIND_MARKS[str(event["kind"])], str(event["title"]), str(event["text"])])
	var when := "%d-й день: %s" % [index % Seasons.LENGTH + 1, str(Seasons.NAMES[season])]
	detail.text = when + (": обычный день." if lines.is_empty() else "\n" + "\n".join(lines))
