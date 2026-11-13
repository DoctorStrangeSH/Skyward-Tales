extends WorldNpc
class_name EscortWalker

## The one being escorted: walks on, can be hurt (foes are taunted by it),
## its health bar hangs over the head.

var max_health: int = 120
var health: int = 120
var _flash: float = 0.0

func take_damage(amount: int, _source: Node = null) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	_flash = 0.15
	if health > 0 and randf() < 0.3:
		say(["Ай!", "Помоги!", "Они меня достанут!"].pick_random(), 1.2)
	queue_redraw()

func is_down() -> bool:
	return health <= 0

func _process(delta: float) -> void:
	super._process(delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		if visual != null:
			visual.modulate = Color(1, 0.6, 0.6) if _flash > 0.0 else Color.WHITE
	queue_redraw()

func _draw() -> void:
	super._draw()
	var width := 30.0
	var top := Vector2(-width / 2.0, -34.0)
	draw_rect(Rect2(top - Vector2(1, 1), Vector2(width + 2, 5)), Color(0, 0, 0, 0.75))
	var share := float(health) / float(maxi(1, max_health))
	var color := Color(0.45, 0.85, 0.4) if share > 0.5 else (Color(0.95, 0.75, 0.3) if share > 0.25 else Color(0.95, 0.3, 0.25))
	draw_rect(Rect2(top, Vector2(width * share, 3)), color)
