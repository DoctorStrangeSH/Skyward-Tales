extends Node2D
class_name SpikeTrap

## Floor spikes: up for 1.2 s, down for 1.6 s; standing on raised spikes
## hurts (dodging through is safe — the hero is untouchable mid-roll).

const UP_TIME := 1.2
const DOWN_TIME := 1.6
const DAMAGE := 10

var clock: float = 0.0
var raised: bool = false
var _hit_cooldown: float = 0.0

func _ready() -> void:
	z_index = -40
	clock = fmod(global_position.x * 0.013, UP_TIME + DOWN_TIME)
	queue_redraw()

func _process(delta: float) -> void:
	clock = fmod(clock + delta, UP_TIME + DOWN_TIME)
	var now_up := clock < UP_TIME
	if now_up != raised:
		raised = now_up
		queue_redraw()
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	if raised and _hit_cooldown <= 0.0:
		var hero := get_tree().get_first_node_in_group("player") as PlayerCharacter
		if hero != null and absf(hero.global_position.x - global_position.x) < 10.0 and absf(hero.global_position.y - global_position.y) < 8.0:
			hero.take_damage(DAMAGE)
			_hit_cooldown = 0.8

func _draw() -> void:
	WorldArt.draw_prop(self, "world/crypt_spikes_up.png" if raised else "world/crypt_spikes_down.png")
