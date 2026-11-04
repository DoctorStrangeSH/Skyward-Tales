extends VBoxContainer
class_name ToastStack

## Up to three short notifications at the top of the screen. Identical
## messages refresh instead of stacking; old ones fade out.

const MAX_TOASTS := 3
const FADE_TIME := 0.35

const STYLES := {
	"info": [Color(0.08, 0.07, 0.13, 0.9), Color(0.93, 0.78, 0.47, 0.8), Color(1.0, 0.93, 0.75)],
	"tip": [Color(0.06, 0.1, 0.16, 0.9), Color(0.45, 0.8, 1.0, 0.85), Color(0.75, 0.92, 1.0)],
}

var _toasts: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 2)

func push(text: String, duration: float = 2.5, kind: String = "info") -> void:
	if text.is_empty():
		return
	for toast in _toasts:
		if toast["text"] == text:
			toast["time"] = maxf(float(toast["time"]), duration)
			(toast["panel"] as Control).modulate.a = 1.0
			return
	while _toasts.size() >= MAX_TOASTS:
		_remove(_toasts[0])
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var colors: Array = STYLES.get(kind, STYLES["info"])
	var style := StyleBoxFlat.new()
	style.bg_color = colors[0]
	style.border_color = colors[1]
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", UiFont.px(9))
	label.add_theme_color_override("font_color", colors[2])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Short messages size to their text; long ones wrap at a fixed width.
	if text.length() > 60:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(316, 0)
	panel.add_child(label)
	add_child(panel)
	_toasts.append({"text": text, "time": duration, "panel": panel})

func visible_texts() -> Array[String]:
	var result: Array[String] = []
	for toast in _toasts:
		result.append(str(toast["text"]))
	return result

func clear() -> void:
	for toast in _toasts.duplicate():
		_remove(toast)

func _remove(toast: Dictionary) -> void:
	_toasts.erase(toast)
	var panel: Node = toast["panel"]
	if is_instance_valid(panel):
		remove_child(panel)
		panel.queue_free()

func _process(delta: float) -> void:
	for toast in _toasts.duplicate():
		toast["time"] = float(toast["time"]) - delta
		var panel := toast["panel"] as Control
		if float(toast["time"]) <= 0.0:
			_remove(toast)
		elif float(toast["time"]) < FADE_TIME:
			panel.modulate.a = float(toast["time"]) / FADE_TIME
