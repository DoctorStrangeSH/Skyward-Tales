extends CanvasLayer
class_name GameHud

var status_label: Label
var quest_label: Label
var message_label: Label
var prompt_label: Label
var dialogue_panel: PanelContainer
var dialogue_label: Label
var message_time: float = 0.0
var dialogue_visible: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var status_panel := PanelContainer.new()
	status_panel.position = Vector2(10, 10)
	status_panel.custom_minimum_size = Vector2(270, 64)
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.075, 0.09, 0.92)))
	root.add_child(status_panel)

	var status_box := VBoxContainer.new()
	status_panel.add_child(status_box)
	status_label = _make_label("УР. 1   ЗДОРОВЬЕ 100/100   МАНА 60/60", 11, Color(0.91, 0.94, 0.87))
	status_box.add_child(status_label)
	quest_label = _make_label("ЗАДАНИЕ: Поговорите со старейшиной", 10, Color(0.83, 0.88, 0.72))
	status_box.add_child(quest_label)

	message_label = _make_label("", 12, Color(1.0, 0.91, 0.62))
	message_label.position = Vector2(180, 18)
	message_label.size = Vector2(450, 28)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(message_label)

	prompt_label = _make_label("", 10, Color(0.94, 0.94, 0.87))
	prompt_label.position = Vector2(12, 330)
	prompt_label.size = Vector2(500, 20)
	root.add_child(prompt_label)

	dialogue_panel = PanelContainer.new()
	dialogue_panel.position = Vector2(140, 246)
	dialogue_panel.custom_minimum_size = Vector2(360, 100)
	dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.06, 0.08, 0.97)))
	root.add_child(dialogue_panel)
	dialogue_label = _make_label("", 11, Color(0.95, 0.93, 0.84))
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_panel.add_child(dialogue_label)
	dialogue_panel.visible = false

func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var paused := not get_tree().paused
		get_tree().paused = paused
		show_message("ПАУЗА — Esc, чтобы продолжить" if paused else "Продолжаем приключение", 2.0)
		get_viewport().set_input_as_handled()

func update_status(player: PlayerCharacter, quests: QuestManager) -> void:
	status_label.text = "УР. %d   HP %d/%d   МАНА %d/%d   ЗОЛОТО %d" % [
		player.level, player.health, player.max_health, player.mana, player.max_mana, player.gold
	]
	quest_label.text = "ЗАДАНИЕ: " + quests.get_active_summary()

func show_message(message: String, duration: float = 3.0) -> void:
	message_label.text = message
	message_time = duration

func set_prompt(message: String) -> void:
	prompt_label.text = message

func show_dialogue(speaker: String, message: String) -> void:
	dialogue_label.text = speaker + "\n" + message + "\n\n[ E — закрыть ]"
	dialogue_panel.visible = true
	dialogue_visible = true

func close_dialogue() -> void:
	dialogue_panel.visible = false
	dialogue_visible = false

func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.35, 0.47, 0.45, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
