extends Control
class_name TitleMenu

const GAME_SCENE: String = "res://scenes/main.tscn"

var continue_button: Button
var menu_column: VBoxContainer
var creation: HeroCreationPanel
var _menu_frame: PanelContainer

static var _display_applied := false

func _ready() -> void:
	get_tree().paused = false
	GameAudio.music("title")
	if not _display_applied:
		_display_applied = true
		GameSettings.apply_display()
	# CI smoke test of exported builds: `SkywardTales -- --smoke` opens the world.
	if "--smoke" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
	_set_menu_background()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var side := MarginContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	side.offset_left = 28
	side.offset_right = 268
	side.add_theme_constant_override("margin_top", 54)
	# The left column only holds the menu frame; its empty area must let
	# clicks through to the hero creation cards underneath.
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(side)
	var version := Label.new()
	version.text = "v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	version.add_theme_font_size_override("font_size", UiFont.px(8))
	version.modulate = Color(1, 1, 1, 0.55)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -60
	version.offset_top = -16
	version.offset_right = -6
	version.offset_bottom = -4
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiStyle.panel(true))
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side.add_child(frame)
	menu_column = VBoxContainer.new()
	menu_column.custom_minimum_size = Vector2(220, 0)
	menu_column.add_theme_constant_override("separation", 7)
	frame.add_child(menu_column)
	_menu_frame = frame
	var heading := Label.new()
	heading.text = "SKYWARD TALES"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", UiFont.px(24))
	heading.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	heading.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.16))
	heading.add_theme_constant_override("outline_size", 8)
	menu_column.add_child(heading)
	var caption := Label.new()
	caption.text = "Угасающее небо"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	caption.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.16))
	caption.add_theme_constant_override("outline_size", 5)
	menu_column.add_child(caption)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	menu_column.add_child(spacer)
	continue_button = _add_button(menu_column, "Продолжить", _continue_game)
	var latest := SaveSystem.latest_slot()
	continue_button.disabled = latest == 0
	if latest > 0:
		var summary := SaveSystem.slot_summary(latest)
		continue_button.tooltip_text = "Слот %d: %s, ур. %d" % [latest, summary["name"], summary["level"]]
	_add_button(menu_column, "Новая игра", func() -> void: _show_slots("new"))
	_add_button(menu_column, "Сохранения", func() -> void: _show_slots("load"))
	var ng := ng_plus_seed(SaveSystem.load_latest(SaveSystem.slot_path(maxi(1, latest))))
	if not ng.is_empty():
		_add_button(menu_column, "Новая игра+ (круг %d)" % (int(ng["ng"]) + 1), _start_ng_plus)
	_add_button(menu_column, "Настройки", _show_settings)
	_add_button(menu_column, "Выход", _exit_game)
	_build_slots(center)
	_build_settings(center)
	creation = HeroCreationPanel.new()
	creation.visible = false
	creation.confirmed.connect(_begin_adventure)
	creation.cancelled.connect(func() -> void:
		creation.visible = false
		_back_to_menu())
	center.add_child(creation)

func _set_menu_background() -> void:
	# Sky gradient, far clouds, the whole first island floating and bobbing,
	# near clouds drifting in front of its cliffs.
	var sky := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.55, 0.74, 0.93))
	gradient.set_color(1, Color(0.84, 0.92, 0.99))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 8
	texture.height = 128
	sky.texture = texture
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Decoration only: it must never swallow clicks meant for the menu (the
	# boy card of the hero creation used to be unclickable — owner's list №34).
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	var holder := SubViewportContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var view := SubViewport.new()
	view.size = Vector2i(640, 360)
	view.transparent_bg = true
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	holder.add_child(view)
	view.add_child(_cloud_layer(Rect2(-120, 20, 880, 340), 12, 0.5, 4.0))
	# Islands: two small ones far away, the big one with the village.
	_floating(view, "ui/title_islet_1.png", Vector2(604, 318), 5.0, 2.6)
	_floating(view, "ui/title_islet_0.png", Vector2(250, 300), 6.0, 3.6)
	_floating(view, "ui/title_island.png", Vector2(440, 170), 7.0, 3.2)
	view.add_child(_cloud_layer(Rect2(-120, 260, 880, 140), 8, 1.0, 9.0))
	var tint := ColorRect.new()
	tint.color = Color(0.06, 0.04, 0.14, 0.12)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

func _floating(view: SubViewport, art: String, at: Vector2, lift: float, period: float) -> void:
	var sprite := Sprite2D.new()
	var hd := art.replace(".png", "_hd.png")
	if ResourceLoader.exists("res://assets/" + hd):
		sprite.texture = WorldArt.texture(hd)
		sprite.scale = Vector2(0.5, 0.5)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		sprite.texture = WorldArt.texture(art)
	sprite.position = at
	view.add_child(sprite)
	var bob := sprite.create_tween().set_loops()
	bob.set_trans(Tween.TRANS_SINE)
	bob.tween_property(sprite, "position:y", at.y + lift, period)
	bob.tween_property(sprite, "position:y", at.y, period)

func _cloud_layer(area: Rect2, count: int, scale_value: float, speed: float) -> Node2D:
	var layer := Node2D.new()
	layer.set_script(preload("res://scripts/sky_clouds.gd"))
	layer.set("area", area)
	layer.set("count", count)
	layer.set("speed_scale", speed / 7.0)
	layer.scale = Vector2(scale_value, scale_value)
	if scale_value != 1.0:
		layer.set("area", Rect2(area.position / scale_value, area.size / scale_value))
	return layer

func _add_button(parent: VBoxContainer, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(220, 30)
	button.add_theme_font_size_override("font_size", UiFont.px(15))
	UiStyle.style_button(button)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _start_new() -> void:
	_menu_frame.visible = false
	menu_column.visible = false
	slots_frame.visible = false
	creation.visible = true

func _back_to_menu() -> void:
	slots_frame.visible = false
	settings_frame.visible = false
	menu_column.visible = true
	_menu_frame.visible = true

# --- Save slots (owner's list №35) --------------------------------------------

var slots_frame: PanelContainer
var slots_box: VBoxContainer
var _slot_mode: String = "load"
var _confirm: String = ""

func _build_slots(center: CenterContainer) -> void:
	slots_frame = PanelContainer.new()
	slots_frame.add_theme_stylebox_override("panel", UiStyle.panel(true))
	slots_frame.visible = false
	center.add_child(slots_frame)
	slots_box = VBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 6)
	slots_box.custom_minimum_size = Vector2(380, 0)
	slots_frame.add_child(slots_box)

func _show_slots(mode: String) -> void:
	_slot_mode = mode
	_confirm = ""
	_menu_frame.visible = false
	slots_frame.visible = true
	_fill_slots()

func _fill_slots() -> void:
	for child in slots_box.get_children():
		slots_box.remove_child(child)
		child.queue_free()
	slots_box.add_child(UiStyle.label("НОВАЯ ИГРА — выберите слот" if _slot_mode == "new" else "СОХРАНЕНИЯ", 14, UiStyle.TITLE))
	for slot in range(1, SaveSystem.SLOTS + 1):
		var summary := SaveSystem.slot_summary(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		slots_box.add_child(row)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(220, 0)
		info.add_theme_constant_override("separation", 0)
		row.add_child(info)
		if summary.is_empty():
			info.add_child(UiStyle.label("Слот %d — пусто" % slot, 11, UiStyle.MUTED))
		else:
			info.add_child(UiStyle.label("Слот %d — %s, ур. %d%s" % [slot, summary["name"], summary["level"], ("  · круг %d" % (int(summary["ng"]) + 1)) if int(summary["ng"]) > 0 else ""], 11, UiStyle.TEXT))
			var when := Time.get_datetime_string_from_unix_time(int(float(summary["saved_at"])) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60, true)
			info.add_child(UiStyle.label("%s · %s" % [RegionCatalog.display_name(str(summary["region"])), when.substr(0, 16)], 8, UiStyle.MUTED))
		var main := Button.new()
		main.custom_minimum_size = Vector2(96, 24)
		main.add_theme_font_size_override("font_size", UiFont.px(10))
		UiStyle.style_button(main)
		var key := "%s:%d" % [_slot_mode, slot]
		if _slot_mode == "new":
			main.text = "Начать здесь" if summary.is_empty() else ("Точно?" if _confirm == key else "Перезаписать")
			main.pressed.connect(func() -> void:
				if not summary.is_empty() and _confirm != key:
					_confirm = key
					_fill_slots()
					return
				SaveSystem.delete_slot(slot)
				get_tree().set_meta("skyward_slot", slot)
				_start_new())
		else:
			main.text = "Играть" if not summary.is_empty() else "—"
			main.disabled = summary.is_empty()
			main.pressed.connect(func() -> void: _continue_slot(slot))
		row.add_child(main)
		if not summary.is_empty():
			var drop := Button.new()
			drop.text = "Удалить?" if _confirm == "del:%d" % slot else "✕"
			drop.tooltip_text = "Удалить сохранение (нужно нажать дважды)"
			drop.custom_minimum_size = Vector2(28, 24)
			drop.add_theme_font_size_override("font_size", UiFont.px(9))
			UiStyle.style_button(drop)
			drop.pressed.connect(func() -> void:
				if _confirm != "del:%d" % slot:
					_confirm = "del:%d" % slot
				else:
					SaveSystem.delete_slot(slot)
					_confirm = ""
				_fill_slots())
			row.add_child(drop)
	var back := Button.new()
	back.text = "Назад"
	back.add_theme_font_size_override("font_size", UiFont.px(11))
	UiStyle.style_button(back)
	back.pressed.connect(_back_to_menu)
	slots_box.add_child(back)

func _continue_slot(slot: int) -> void:
	if SaveSystem.slot_summary(slot).is_empty():
		return
	get_tree().set_meta("skyward_slot", slot)
	get_tree().set_meta("skyward_continue", true)
	get_tree().change_scene_to_file(GAME_SCENE)

# --- Settings in the title menu (owner's list №36) -----------------------------

var settings_frame: PanelContainer

func _build_settings(center: CenterContainer) -> void:
	settings_frame = PanelContainer.new()
	settings_frame.add_theme_stylebox_override("panel", UiStyle.panel(true))
	settings_frame.visible = false
	center.add_child(settings_frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	settings_frame.add_child(box)
	box.add_child(UiStyle.label("НАСТРОЙКИ", 14, UiStyle.TITLE))
	box.add_child(SettingsPanel.new())
	var back := Button.new()
	back.text = "Назад"
	back.add_theme_font_size_override("font_size", UiFont.px(11))
	UiStyle.style_button(back)
	back.pressed.connect(_back_to_menu)
	box.add_child(back)

func _show_settings() -> void:
	_menu_frame.visible = false
	settings_frame.visible = true

func _begin_adventure(hero_name: String, gender: String) -> void:
	get_tree().set_meta("skyward_continue", false)
	get_tree().set_meta("skyward_new_hero", {"name": hero_name, "gender": gender})
	get_tree().change_scene_to_file(GAME_SCENE)

## Этап 18 «Новая игра+»: after either ending the hero starts the story anew
## keeping level, skills, gear, gold and achievements; the world is tougher
## and pays more. Empty when the save has not reached an ending.
static func ng_plus_seed(save: Dictionary) -> Dictionary:
	if save.is_empty() or not save.get("world", {}) is Dictionary:
		return {}
	var world: Dictionary = save["world"]
	var flags: Variant = world.get("story_flags", {})
	if not flags is Dictionary or not ((flags as Dictionary).has("ending_restore") or (flags as Dictionary).has("ending_lower")):
		return {}
	return {"player": save.get("player", {}), "ng": int(world.get("ng_plus", 0)), "achievements": world.get("achievements", {}),
		"lore": world.get("lore", {}), "discovered": world.get("discovered", {})}

func _start_ng_plus() -> void:
	var slot := maxi(1, SaveSystem.latest_slot())
	var seed := ng_plus_seed(SaveSystem.load_latest(SaveSystem.slot_path(slot)))
	if seed.is_empty():
		return
	get_tree().set_meta("skyward_slot", slot)
	get_tree().set_meta("skyward_continue", false)
	get_tree().set_meta("skyward_ng_plus", seed)
	get_tree().change_scene_to_file(GAME_SCENE)

func _continue_game() -> void:
	var slot := SaveSystem.latest_slot()
	if slot > 0:
		_continue_slot(slot)

func _exit_game() -> void:
	get_tree().quit()
