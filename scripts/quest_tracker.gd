extends PanelContainer
class_name QuestTracker

## Compact tracker under the vitals: the main quest and up to three side
## quests, each with a progress bar; ready-to-hand-in quests glow green.

const MAX_ROWS := 4
var rows: VBoxContainer
var entries: Array = []
## Extra lines (village contracts), set by the game.
var extra: Array = []

func _ready() -> void:
	position = Vector2(6, 66)
	custom_minimum_size = Vector2(196, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.07, 0.55)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", style)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rows)

func refresh(quests: QuestManager) -> void:
	var data := QuestJournalPanel.build_entries(quests)
	var active: Array = (data["active"] as Array).filter(func(e: Dictionary) -> bool: return e["tracked"])
	var main := active.filter(func(e: Dictionary) -> bool: return e["main"])
	var side := active.filter(func(e: Dictionary) -> bool: return not e["main"])
	var next: Array = (main + side + extra).slice(0, MAX_ROWS)
	if str(next) == str(entries) and is_inside_tree() and get_meta("filled", false):
		return
	set_meta("filled", true)
	entries = next
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	visible = not entries.is_empty()
	for entry in entries:
		var ready: bool = int(entry["progress"]) >= int(entry["target"])
		var color := Color(0.6, 1.0, 0.6) if ready else (Color(1.0, 0.86, 0.5) if entry["main"] else Color(0.78, 0.9, 1.0))
		var label := Label.new()
		var count := "" if int(entry["target"]) <= 1 else "  %d/%d" % [entry["progress"], entry["target"]]
		label.text = "%s %s%s%s" % ["★" if entry["main"] else ("•" if entry.get("contract", false) else "◆"), entry["title"], count, "  ✓ сдать" if ready else ""]
		label.add_theme_font_size_override("font_size", UiFont.px(9))
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("outline_size", 3)
		label.clip_text = true
		label.custom_minimum_size = Vector2(188, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.add_child(label)
		if int(entry["target"]) > 1:
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(188, 3)
			bar.show_percentage = false
			bar.max_value = int(entry["target"])
			bar.value = int(entry["progress"])
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var fill := StyleBoxFlat.new()
			fill.bg_color = color
			var back := StyleBoxFlat.new()
			back.bg_color = Color(0, 0, 0, 0.5)
			bar.add_theme_stylebox_override("fill", fill)
			bar.add_theme_stylebox_override("background", back)
			rows.add_child(bar)
