extends PanelContainer
class_name HeroCreationPanel

## Pick the hero's look (boy / girl) and name before a new adventure.

signal confirmed(hero_name: String, gender: String)
signal cancelled

var gender: String = "m"
var name_edit: LineEdit
var preview: TextureRect
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
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = "Кто отправится в путь?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.6))
	box.add_child(title)
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(96, 96)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(preview)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	male_button = _choice(row, "Юноша", "m")
	female_button = _choice(row, "Девушка", "f")
	var name_label := Label.new()
	name_label.text = "Имя"
	name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	box.add_child(name_label)
	name_edit = LineEdit.new()
	name_edit.max_length = 14
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

func _choice(parent: HBoxContainer, label: String, value: String) -> Button:
	var button := Button.new()
	button.text = label
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(110, 28)
	button.pressed.connect(func() -> void: select_gender(value))
	parent.add_child(button)
	return button

func select_gender(value: String) -> void:
	gender = "f" if value == "f" else "m"
	male_button.button_pressed = gender == "m"
	female_button.button_pressed = gender == "f"
	if not _name_touched or name_edit.text.strip_edges().is_empty():
		name_edit.text = StoryText.DEFAULT_NAMES[gender]
		_name_touched = false
	var sheet := WorldArt.texture("sprites/characters/%s.png" % ("hero_f_8dir_walk" if gender == "f" else "hero_8dir_walk"))
	if sheet != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(0, 0, 32, 32)
		preview.texture = atlas

func hero_data() -> Dictionary:
	var hero_name := name_edit.text.strip_edges()
	if hero_name.is_empty():
		hero_name = StoryText.DEFAULT_NAMES[gender]
	return {"name": hero_name, "gender": gender}

func confirm() -> void:
	var data := hero_data()
	confirmed.emit(data["name"], data["gender"])
