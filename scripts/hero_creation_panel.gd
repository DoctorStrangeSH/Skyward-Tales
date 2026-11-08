extends PanelContainer
class_name HeroCreationPanel

## Pick the hero's look (boy / girl) and name before a new adventure.

signal confirmed(hero_name: String, gender: String)
signal cancelled

var gender: String = "m"
var name_edit: LineEdit
var male_button: Button
var female_button: Button
var _name_touched: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.11, 0.95)
	style.border_color = Color(0.93, 0.78, 0.47, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", UiStyle.panel(true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = "Кто отправится в путь?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UiFont.px(14))
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.6))
	box.add_child(title)
	# Two hero cards with the living idle animation; the chosen one glows.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	male_button = _card(row, "Юноша", "m")
	female_button = _card(row, "Девушка", "f")
	var name_label := Label.new()
	name_label.text = "Имя"
	name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	box.add_child(name_label)
	name_edit = LineEdit.new()
	name_edit.max_length = 14
	# Typing replaces the default name instead of appending to it.
	name_edit.select_all_on_focus = true
	name_edit.focus_entered.connect(func() -> void:
		if not _name_touched:
			name_edit.select_all.call_deferred())
	name_edit.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed and not _name_touched:
			name_edit.select_all.call_deferred())
	name_edit.placeholder_text = "Введите имя"
	name_edit.text_changed.connect(func(_t: String) -> void: _name_touched = true)
	box.add_child(name_edit)
	var start := Button.new()
	start.text = "Начать приключение"
	start.custom_minimum_size = Vector2(0, 32)
	start.pressed.connect(confirm)
	box.add_child(start)
	var back := Button.new()
	back.text = "Назад"
	back.pressed.connect(func() -> void: cancelled.emit())
	box.add_child(back)
	select_gender("m")

var _cards: Dictionary = {}
var _frame_clock: float = 0.0
var _frame: int = 0

func _card(parent: HBoxContainer, label: String, value: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(118, 118)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: select_gender(value))
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(96, 96)
	art.position = Vector2(11, 4)
	art.size = Vector2(96, 96)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(art)
	var caption := Label.new()
	caption.text = label
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(0, 100)
	caption.size = Vector2(118, 14)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caption)
	parent.add_child(button)
	var atlas := AtlasTexture.new()
	var sheet := WorldArt.texture("sprites/chibi/%s/idle.png" % ("hero_f" if value == "f" else "hero_m"))
	if sheet != null:
		atlas.atlas = sheet
		atlas.region = Rect2(16, 12, 32, 32)
	art.texture = atlas
	_cards[value] = atlas
	return button

func _process(delta: float) -> void:
	_frame_clock += delta
	if _frame_clock < 0.16:
		return
	_frame_clock = 0.0
	_frame = (_frame + 1) % 6
	for value in _cards:
		var atlas: AtlasTexture = _cards[value]
		# The chosen hero breathes; the other stands still.
		atlas.region = Rect2(16 + 64 * (_frame if value == gender else 0), 12, 32, 32)

func select_gender(value: String) -> void:
	gender = "f" if value == "f" else "m"
	male_button.button_pressed = gender == "m"
	female_button.button_pressed = gender == "f"
	# The chosen card glows gold; the other one fades back.
	_style_card(male_button, gender == "m")
	_style_card(female_button, gender == "f")
	if not _name_touched or name_edit.text.strip_edges().is_empty():
		name_edit.text = StoryText.DEFAULT_NAMES[gender]
		_name_touched = false
	for card in _cards:
		(_cards[card] as AtlasTexture).region.position.x = 16

func _style_card(button: Button, chosen: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.set_border_width_all(3 if chosen else 1)
	style.border_color = Color(1.0, 0.82, 0.36) if chosen else Color(0.36, 0.3, 0.42)
	style.bg_color = Color(0.32, 0.22, 0.12, 0.95) if chosen else Color(0.1, 0.09, 0.14, 0.9)
	style.shadow_color = Color(1.0, 0.75, 0.3, 0.45) if chosen else Color(0, 0, 0, 0)
	style.shadow_size = 6 if chosen else 0
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var variant := style.duplicate() as StyleBoxFlat
		if state.begins_with("hover") and not chosen:
			variant.border_color = Color(0.7, 0.6, 0.45)
		button.add_theme_stylebox_override(state, variant)
	button.modulate = Color.WHITE if chosen else Color(0.7, 0.7, 0.75)
	var caption := button.get_child(1) as Label
	if caption != null:
		caption.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5) if chosen else Color(0.75, 0.75, 0.8))

func hero_data() -> Dictionary:
	var hero_name := name_edit.text.strip_edges()
	if hero_name.is_empty():
		hero_name = StoryText.DEFAULT_NAMES[gender]
	return {"name": hero_name, "gender": gender}

func confirm() -> void:
	var data := hero_data()
	confirmed.emit(data["name"], data["gender"])
