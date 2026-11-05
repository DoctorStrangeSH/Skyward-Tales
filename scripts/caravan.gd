extends Node2D
class_name Caravan

## World event "caravan": a merchant wagon on the road, attacked by local
## monsters. Beat them all before the timer runs out and the caravan reaches
## the village — a trade route opens for three days (new goods and 10% off
## at Bran's). Too late, and the caravan is plundered: prices rise for a day.

signal finished(saved: bool)

const DEFEND_TIME := 60.0
const NPC_SCRIPT := preload("res://scripts/npc.gd")

var game: SkywardGame
var attackers: Array = []
var time_left: float = DEFEND_TIME
var state: String = "attacked"
var trader: WorldNpc
var _leave_in: float = 0.0

func _ready() -> void:
	z_index = 0
	trader = NPC_SCRIPT.new() as WorldNpc
	trader.npc_id = "caravaner"
	trader.display_name = "Нея, караванщица"
	trader.outfit_color = Color(0.7, 0.45, 0.25)
	add_child(trader)
	trader.position = Vector2(-30, 10)
	trader.interacted.connect(func(_source: Node2D) -> void: _talk())
	trader.say("Помогите! Твари напали на караван!", 4.0)

func setup(owner_game: SkywardGame, kinds: Array, count: int) -> void:
	game = owner_game
	for i in count:
		var at := global_position + Vector2.RIGHT.rotated(TAU * i / count + 0.3) * 60.0
		var enemy := game.spawn_enemy(str(kinds[i % kinds.size()]), at)
		if enemy == null:
			continue
		enemy.set_meta("event_foe", true)
		enemy.defeated.connect(func(_xp: int) -> void: _on_attacker_down(enemy))
		attackers.append(enemy)

func _alive() -> Array:
	return attackers.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as SlimeEnemy).is_queued_for_deletion() and (e as SlimeEnemy).health > 0)

func _on_attacker_down(enemy: SlimeEnemy) -> void:
	attackers.erase(enemy)
	if state == "attacked" and _alive().is_empty():
		_save()

func _process(delta: float) -> void:
	queue_redraw()
	match state:
		"attacked":
			if get_tree().paused:
				return
			time_left -= delta
			if time_left <= 0.0:
				_lose()
		"saved", "lost":
			_leave_in -= delta
			if _leave_in <= 0.0:
				var fade := create_tween()
				fade.tween_property(self, "modulate:a", 0.0, 1.0)
				fade.tween_callback(queue_free)
				state = "gone"

func _save() -> void:
	state = "saved"
	_leave_in = 25.0
	game.world_state.clear("caravan_lost")
	game.world_state.set_state("trade_route", 3.0)
	var level := maxi(1, RegionCatalog.level(game.current_region))
	var coins := game._spawn_loot(global_position + Vector2(0, 22), "gold")
	coins.amount = 30 * level
	game._spawn_loot(global_position + Vector2(16, 22), "health_potion").amount = 2
	game.hud.show_title_card("Караван спасён!", 2.5)
	game.hud.show_message("Торговый путь открыт на 3 дня: у Брана новые товары и скидка 10%.", 4.5)
	trader.say(StoryText.format("Спасибо, {hero}! Расскажу Брану — встретим тебя лучшими товарами!"), 5.0)
	GameAudio.play("quest", -4.0, 0.0)
	game.achievements.add("caravans")
	finished.emit(true)

func _lose() -> void:
	state = "lost"
	_leave_in = 3.0
	if not game.world_state.has("trade_route"):
		game.world_state.set_state("caravan_lost", 1.0)
	game.hud.show_message("Караван разграблен… В деревне подорожают товары.", 4.0)
	trader.say("Всё пропало…", 3.0)
	finished.emit(false)

func _talk() -> void:
	match state:
		"attacked":
			game._show_dialogue(trader.display_name, "Отбейте нас, прошу! Ещё немного — и твари растащат весь товар!")
		"saved":
			game._show_dialogue(trader.display_name, "Ты {спас|спасла} наш караван, {hero}. Загляни к Брану — мы везём ему заморские диковинки.")
		_:
			game._show_dialogue(trader.display_name, "Ничего не осталось… Может, в другой раз дорога будет добрее.")

func _draw() -> void:
	# The wagon.
	WorldArt.draw_prop(self, "world/decor_wagon.png")
	if state != "attacked":
		return
	# How long the caravan holds out.
	var width := 54.0
	var top := Vector2(-width * 0.5, 14)
	draw_rect(Rect2(top - Vector2(1, 1), Vector2(width + 2, 6)), Color(0.08, 0.05, 0.03, 0.9))
	var share := clampf(time_left / DEFEND_TIME, 0.0, 1.0)
	draw_rect(Rect2(top, Vector2(width * share, 4)), Color(1.0, 0.75, 0.25).lerp(Color(0.95, 0.3, 0.2), 1.0 - share))
	var font := UiFont.font()
	var label := "Караван: %d с" % ceili(time_left)
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8)).x
	draw_string_outline(font, Vector2(-label_width * 0.5, 30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), 3, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(-label_width * 0.5, 30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), Color(1.0, 0.92, 0.7))
