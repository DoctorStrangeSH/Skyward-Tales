extends PanelContainer
class_name CalendarPanel

## «Календарь» tab (N), like the calendar board in Stardew Valley: one
## season at a time — four weeks of seven days under the names of the
## weekdays; ◀ ▶ turn the seasons. Most days are empty; festivals, the
## Saturday fair and birthdays are marked. Today is framed, past days fade.
## On the right — what comes next; clicking a day tells all about it below.

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
	"party": Color(0.75, 0.7, 1.0),
}
const KIND_MARKS := {"festival": "★", "fair": "⚑", "birthday": "♥", "party": "♪"}
const CELL := Vector2(62, 44)

var calendar: GameCalendar
var title: Label
var season_label: Label
var grid: GridContainer
var upcoming_box: VBoxContainer
var detail: Label
## The season shown (0..3) and the selected day of the year.
var page: int = 0
var _selected: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.panel(false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	var name_label := UiStyle.label("КАЛЕНДАРЬ", 13, UiStyle.TITLE)
	head.add_child(name_label)
	var back := _arrow("◀", -1)
	head.add_child(back)
	season_label = UiStyle.label("", 12, Color.WHITE)
	season_label.custom_minimum_size = Vector2(70, 0)
	season_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(season_label)
	head.add_child(_arrow("▶", 1))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	title = UiStyle.label("", 8, Color(1.0, 0.9, 0.65))
	head.add_child(title)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	box.add_child(body)
	grid = GridContainer.new()
	grid.columns = Seasons.WEEK
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	body.add_child(grid)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 2)
	side.custom_minimum_size = Vector2(128, 0)
	body.add_child(side)
	side.add_child(UiStyle.label("СКОРО", 10, UiStyle.TITLE))
	upcoming_box = VBoxContainer.new()
	upcoming_box.add_theme_constant_override("separation", 2)
	side.add_child(upcoming_box)
	side.add_child(UiStyle.label("★ праздник\n⚑ ярмарка (по субботам)\n♪ таверна (по пятницам)\n♥ день рождения", 7, UiStyle.MUTED))
	detail = UiStyle.label("", 8, Color(0.88, 0.86, 0.8))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(590, 26)
	box.add_child(detail)
	visible = false

func _arrow(text: String, step: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(22, 16)
	button.add_theme_font_size_override("font_size", UiFont.px(8))
	button.pressed.connect(func() -> void: turn(step))
	return button

## Shows the season of today (when opened).
func open(owner_calendar: GameCalendar) -> void:
	calendar = owner_calendar
	page = GameCalendar.day_of_year(calendar.today()) / Seasons.LENGTH
	_selected = -1
	populate(calendar)

func turn(step: int) -> void:
	page = posmod(page + step, Seasons.ORDER.size())
	_selected = -1
	populate(calendar)

func populate(owner_calendar: GameCalendar) -> void:
	calendar = owner_calendar
	var today := calendar.today()
	var doy := GameCalendar.day_of_year(today)
	var season := str(Seasons.ORDER[page])
	title.text = GameCalendar.date_text(today)
	season_label.text = str(Seasons.NAMES[season])
	season_label.add_theme_color_override("font_color", SEASON_COLORS[season])
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for name in Seasons.WEEKDAYS_SHORT:
		var head := UiStyle.label(str(name), 8, UiStyle.MUTED if name != "Сб" else KIND_COLORS["fair"])
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.custom_minimum_size = Vector2(CELL.x, 0)
		grid.add_child(head)
	# The year starts on a Monday and a season is four whole weeks.
	for date in Seasons.LENGTH:
		grid.add_child(_cell(page * Seasons.LENGTH + date, doy, season))
	for child in upcoming_box.get_children():
		upcoming_box.remove_child(child)
		child.queue_free()
	for event in calendar.upcoming(6):
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", -1)
		var kind := str(event["kind"])
		var line := UiStyle.label("%s %s" % [KIND_MARKS[kind], str(event["title"])], 8, KIND_COLORS[kind])
		line.clip_text = true
		line.custom_minimum_size = Vector2(126, 0)
		row.add_child(line)
		row.add_child(UiStyle.label("   %s · %s" % [GameCalendar.in_text(int(event["in"])), GameCalendar.short_date(GameCalendar.day_of_year(int(event["day"])))], 7, Color(0.75, 0.85, 0.95) if int(event["in"]) > 0 else Color(0.6, 1.0, 0.65)))
		upcoming_box.add_child(row)
	var shown_today := doy / Seasons.LENGTH == page
	_show_detail(_selected if _selected >= 0 else (doy if shown_today else page * Seasons.LENGTH))

func _cell(index: int, today_doy: int, season: String) -> Control:
	var events := calendar.events_on(index)
	var cell := PanelContainer.new()
	cell.custom_minimum_size = CELL
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	var base: Color = SEASON_COLORS[season]
	var past := index < today_doy
	var is_today := index == today_doy
	var marked := not events.is_empty()
	style.bg_color = Color(base.r * 0.2, base.g * 0.18, base.b * 0.18, 0.95) if not past else Color(0.09, 0.08, 0.09, 0.9)
	if marked and not past:
		style.bg_color = style.bg_color.lightened(0.08)
	style.border_color = Color(1.0, 0.92, 0.55) if is_today else (base if index == _selected else base.darkened(0.55))
	style.set_border_width_all(2 if is_today or index == _selected else 1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(2)
	cell.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(box)
	var number := UiStyle.label(str(index % Seasons.LENGTH + 1), 9 if not is_today else 10, Color(1.0, 0.95, 0.7) if is_today else (Color(0.45, 0.43, 0.45) if past else base.lightened(0.15)))
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(number)
	var shown := 0
	for event in events:
		if shown >= 2:
			break
		var kind := str(event["kind"])
		var line := UiStyle.label("%s %s" % [KIND_MARKS[kind], str(event.get("short", event["title"]))], 7, KIND_COLORS[kind].darkened(0.4) if past else KIND_COLORS[kind])
		line.clip_text = true
		line.custom_minimum_size = Vector2(CELL.x - 6, 0)
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
	var lines: Array[String] = []
	for event in calendar.events_on(index):
		lines.append("%s %s — %s" % [KIND_MARKS[str(event["kind"])], str(event["title"]), str(event["text"])])
	var when := "%s, %s" % [GameCalendar.short_date(index), str(Seasons.WEEKDAYS[Seasons.weekday_of(index)])]
	detail.text = when + (": обычный день." if lines.is_empty() else "\n" + "\n".join(lines))
