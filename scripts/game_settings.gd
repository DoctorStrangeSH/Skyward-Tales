extends RefCounted
class_name GameSettings

## Player preferences and one-time tips, stored in user://settings.cfg
## (separate from save games so they survive a new adventure).

const PATH := "user://settings.cfg"
const DEFAULTS := {"hints": true, "damage_numbers": true, "screen_shake": true}

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

## Forget cached values (tests use this after changing the file).
static func reload() -> void:
	_config = null
