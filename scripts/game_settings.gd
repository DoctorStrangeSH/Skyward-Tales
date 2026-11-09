extends RefCounted
class_name GameSettings

## Player preferences and one-time tips, stored in user://settings.cfg
## (separate from save games so they survive a new adventure).

const PATH := "user://settings.cfg"
const DEFAULTS := {"hints": true, "damage_numbers": true, "screen_shake": true, "master_volume": 1.0, "music_volume": 0.6, "sfx_volume": 0.8,
	"ui_volume": 0.6, "ambience_volume": 0.5, "nature_volume": 0.35, "mute_unfocused": true}

static var _config: ConfigFile

static func _cfg() -> ConfigFile:
	if _config == null:
		_config = ConfigFile.new()
		_config.load(PATH)  # a missing file simply means defaults
	return _config

static func get_bool(key: String) -> bool:
	return bool(_cfg().get_value("options", key, DEFAULTS.get(key, false)))

static func set_bool(key: String, value: bool) -> void:
	_cfg().set_value("options", key, value)
	_cfg().save(PATH)

static func get_float(key: String) -> float:
	return float(_cfg().get_value("options", key, DEFAULTS.get(key, 1.0)))

static func set_float(key: String, value: float) -> void:
	_cfg().set_value("options", key, value)
	_cfg().save(PATH)

static func hints_enabled() -> bool:
	return get_bool("hints")

static func damage_numbers_enabled() -> bool:
	return get_bool("damage_numbers")

## Returns true the first time a tip is requested (and hints are on).
static func consume_tip(tip_id: String) -> bool:
	if not hints_enabled() or bool(_cfg().get_value("tips_seen", tip_id, false)):
		return false
	_cfg().set_value("tips_seen", tip_id, true)
	_cfg().save(PATH)
	return true

static func reset_tips() -> void:
	if _cfg().has_section("tips_seen"):
		_cfg().erase_section("tips_seen")
	_cfg().save(PATH)

# --- Display ---------------------------------------------------------------

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const WINDOW_MODES := ["Окно", "Полный экран", "Без рамки"]

static func resolution_index() -> int:
	return clampi(int(_cfg().get_value("display", "resolution", 0)), 0, RESOLUTIONS.size() - 1)

static func window_mode_index() -> int:
	return clampi(int(_cfg().get_value("display", "window_mode", 0)), 0, WINDOW_MODES.size() - 1)

static func set_display(resolution: int, window_mode: int) -> void:
	_cfg().set_value("display", "resolution", resolution)
	_cfg().set_value("display", "window_mode", window_mode)
	_cfg().save(PATH)
	apply_display()

static func resolution_label(index: int) -> String:
	var size: Vector2i = RESOLUTIONS[index]
	return "%d × %d" % [size.x, size.y]

## Applies the stored resolution and window mode (no-op when headless).
static func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := window_mode_index()
	match mode:
		1:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen := DisplayServer.window_get_current_screen()
			DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
			DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			# A maximized window ignores resizing: restore it first.
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size: Vector2i = RESOLUTIONS[resolution_index()]
			var screen := DisplayServer.window_get_current_screen()
			var usable := DisplayServer.screen_get_usable_rect(screen)
			size = Vector2i(mini(size.x, usable.size.x), mini(size.y, usable.size.y))
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)

## Forget cached values (tests use this after changing the file).
static func reload() -> void:
	_config = null
