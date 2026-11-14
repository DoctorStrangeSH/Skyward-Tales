extends Node
class_name StarfallIsle

## Этап 24: the Starfall Isle (region "starfall_isle", tools/starfall_layout.py)
## rises above the clouds only on the Night of Starfall — the calendar's
## festival (8th day of winter); the «Ветрокрыл» flies there that day only.
## Stars fall around the hero (a glowing circle warns: standing under one
## stings a little) and leave star fragments where they land — up to
## STARS a year. The Star Guardian (an elite sentinel) waits by the crater
## once a year: starlight essence and gold.

const REGION := "starfall_isle"
const STARS := 12
const CRATER := Vector2(640, 420)

var game: SkywardGame
var _clock: float = 3.0
## {"year": int, "caught": int, "guardian": bool}
var night: Dictionary = {}

func festival_day() -> int:
	return int(GameCalendar.FESTIVALS["starfall"]["day"])

func open_today() -> bool:
	return GameCalendar.day_of_year(game.day_night.day) == festival_day()

func _year() -> int:
	return GameCalendar.year_of(game.day_night.day)

func _night() -> Dictionary:
	if int(night.get("year", -1)) != _year():
		night = {"year": _year(), "caught": 0, "guardian": false}
	return night

func stars_left() -> int:
	return maxi(0, STARS - int(_night()["caught"]))

func populate() -> void:
	if game.current_region != REGION:
		return
	game.hud.show_title_card("Ночь Звездопада", 2.6)
	game.hud.show_message("Звёзды падают! Где упадёт звезда — останется осколок. Осталось в небе: %d." % stars_left(), 4.5)
	if not bool(_night()["guardian"]):
		var guardian := game.spawn_enemy("sentinel", CRATER, "fierce")
		if guardian != null:
			guardian.set_meta("star_guardian", true)
			guardian.tree_exiting.connect(func() -> void:
				if guardian.health <= 0:
					on_guardian_down(guardian.global_position))
	_clock = 2.0

func on_guardian_down(at: Vector2) -> void:
	if bool(_night()["guardian"]):
		return
	night["guardian"] = true
	game._spawn_loot(at + Vector2(-10, 6), "starlight_essence").amount = 3
	game._spawn_loot(at + Vector2(12, 6), "gold").amount = 220 + 15 * game.player.level
	game.hud.show_title_card("Звёздный страж повержен", 2.4)
	game.achievements.add("star_guardians")
	game.request_autosave()

func _process(delta: float) -> void:
	if game == null or game.current_region != REGION or game.get_tree().paused or stars_left() <= 0:
		return
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = randf_range(3.5, 6.0)
	fall(game.player.global_position + Vector2(randf_range(-110, 110), randf_range(-80, 80)))

## A star falls at `at`: a warning circle, then a fragment where it lands.
func fall(at: Vector2) -> void:
	var map := game.world.get_world_2d().navigation_map
	if NavigationServer2D.map_get_iteration_id(map) > 0:
		at = NavigationServer2D.map_get_closest_point(map, at)
	var star := CrystalStrike.new()
	star.damage = maxi(2, roundi(game.player.max_health * 0.04))
	game.add_child(star)
	star.global_position = at
	night["caught"] = int(_night()["caught"]) + 1
	get_tree().create_timer(CrystalStrike.WARN).timeout.connect(func() -> void:
		if game.current_region == REGION:
			game._spawn_loot(at, "star_fragment")
			Vfx.sparkle(game, at))

func make_snapshot() -> Dictionary:
	return {"night": night.duplicate()}

func restore_snapshot(value: Variant) -> void:
	var saved: Dictionary = value if value is Dictionary else {}
	night = (saved.get("night", {}) as Dictionary).duplicate() if saved.get("night", {}) is Dictionary else {}
