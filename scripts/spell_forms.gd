extends RefCounted
class_name SpellForms

## Stage 20: spells that are not bolts. A spell in data/spells.json with a
## "form" key is cast here instead of as a MagicBolt:
##   wave  — «Огненная волна»: a fan of fire in front of the hero, burns;
##   wall  — «Ледяная стена»: ice blocks across the aim that stop foes,
##           slow whoever touches them and shatter with a blow at the end;
##   orb   — «Шаровая молния»: a slow orb that zaps foes near it.
## Every hit goes through `hit()` — the same path as a bolt: elemental
## damage, reactions (by the base spell of the element), gear procs and
## the hero's target for the crew.

const WORLD_LAYER := 4
const BASE_SPELL := {"fire": "fireball", "ice": "frostbolt", "lightning": "chain_lightning"}

## Casts a form spell; returns false when it can't be cast here.
static func cast(game: SkywardGame, spell_id: String, spell: Dictionary, direction: Vector2, damage: int) -> bool:
	match str(spell.get("form", "")):
		"wave":
			fire_wave(game, spell, direction, damage)
		"wall":
			ice_wall(game, spell, direction, damage)
		"orb":
			ball_lightning(game, spell, direction, damage)
		_:
			return false
	return true

static func enemies(game: SkywardGame) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for node in game.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.has_method("take_damage"):
			if not ("health" in enemy) or int(enemy.get("health")) > 0:
				out.append(enemy)
	return out

## One hit of a form spell on one foe.
static func hit(game: SkywardGame, enemy: Node2D, damage: int, element: String) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return
	if enemy.has_method("take_elemental_damage"):
		enemy.take_elemental_damage(damage, element)
	else:
		enemy.take_damage(damage)
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return
	if enemy.has_method("react_to_spell"):
		enemy.react_to_spell(str(BASE_SPELL.get(element, "fireball")))
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		game.on_spell_hit(enemy)
		game.note_hero_target(enemy)

# --- Огненная волна -----------------------------------------------------

static func fire_wave(game: SkywardGame, spell: Dictionary, direction: Vector2, damage: int) -> Array[Node2D]:
	var origin := game.player.global_position
	var radius := float(spell.get("radius", 96.0))
	var half := deg_to_rad(float(spell.get("arc", 110.0)) * 0.5)
	var burn := int(spell.get("burn_damage", 3)) + game.player.get_burn_damage_bonus()
	var burn_time := float(spell.get("burn_duration", 2.5))
	var struck: Array[Node2D] = []
	for enemy in enemies(game):
		var to := enemy.global_position - origin
		if to.length() > radius or (to.length() > 10.0 and absf(direction.angle_to(to)) > half):
			continue
		struck.append(enemy)
	for enemy in struck:
		hit(game, enemy, damage, "fire")
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			if enemy.has_method("apply_burning"):
				enemy.apply_burning(burn, burn_time)
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback((enemy.global_position - origin).normalized(), 70.0)
	_wave_visual(game, origin, direction, radius, half)
	return struck

static func _wave_visual(game: SkywardGame, origin: Vector2, direction: Vector2, radius: float, half: float) -> void:
	var fan := Node2D.new()
	fan.z_index = 30
	game.add_child(fan)
	fan.global_position = origin
	var colors := [Color(1.0, 0.9, 0.45, 0.85), Color(1.0, 0.55, 0.2, 0.7), Color(0.85, 0.25, 0.15, 0.55)]
	for ring in 3:
		var poly := Polygon2D.new()
		var inner := radius * (0.18 + 0.27 * ring)
		var outer := radius * (0.42 + 0.29 * ring)
		var points := PackedVector2Array()
		var steps := 10
		for i in steps + 1:
			points.append(direction.rotated(-half + 2.0 * half * i / steps) * outer)
		for i in range(steps, -1, -1):
			points.append(direction.rotated(-half + 2.0 * half * i / steps) * inner)
		poly.polygon = points
		poly.color = colors[ring]
		poly.scale = Vector2(0.3, 0.3)
		fan.add_child(poly)
		var tween := poly.create_tween()
		tween.tween_interval(0.04 * ring)
		tween.tween_property(poly, "scale", Vector2.ONE, 0.18)
		tween.parallel().tween_property(poly, "modulate:a", 0.0, 0.45).set_delay(0.12)
	for i in 5:
		var at := origin + direction.rotated(-half + 2.0 * half * i / 4.0) * radius * 0.8
		Vfx.burst(game, at, Vfx.SPELL_COLORS["fireball"], 8, 50.0, 0.4)
	var cleanup := game.get_tree().create_timer(0.6)
	cleanup.timeout.connect(fan.queue_free)

# --- Ледяная стена ------------------------------------------------------

static func ice_wall(game: SkywardGame, spell: Dictionary, direction: Vector2, damage: int) -> Node2D:
	var blocks := int(spell.get("blocks", 5))
	var step := float(spell.get("block_size", 14.0))
	var center := game.player.global_position + direction * float(spell.get("distance", 50.0))
	var across := direction.orthogonal()
	var wall := IceWall.new()
	wall.game = game
	wall.damage = damage
	wall.lifetime = float(spell.get("duration", 6.0))
	wall.slow = float(spell.get("slow_multiplier", 0.45))
	wall.slow_time = float(spell.get("slow_duration", 1.5)) + game.player.get_slow_duration_bonus()
	game.add_child(wall)
	wall.global_position = center
	var foes := enemies(game)
	for i in blocks:
		var offset := across * step * (float(i) - float(blocks - 1) * 0.5)
		var at := center + offset
		# A foe standing on the spot is frozen in place instead of walled in.
		var trapped: Node2D = null
		for enemy in foes:
			if enemy.global_position.distance_to(at) < step * 0.8:
				trapped = enemy
				break
		if trapped != null:
			hit(game, trapped, damage, "ice")
			if is_instance_valid(trapped) and trapped.has_method("apply_slow"):
				trapped.apply_slow(0.1, 1.5)
			continue
		if game.player.global_position.distance_to(at) < step:
			continue
		wall.add_block(offset, step)
	Vfx.burst(game, center, Vfx.SPELL_COLORS["frostbolt"], 18, 60.0, 0.5)
	return wall

class IceWall extends Node2D:
	var game: SkywardGame
	var damage := 10
	var lifetime := 6.0
	var slow := 0.45
	var slow_time := 1.5
	var block_offsets: Array[Vector2] = []
	var _size := 14.0
	var _tick := 0.0

	func add_block(offset: Vector2, size: float) -> void:
		_size = size
		block_offsets.append(offset)
		var body := StaticBody2D.new()
		body.collision_layer = SpellForms.WORLD_LAYER
		body.collision_mask = 0
		body.position = offset
		body.add_to_group("ice_wall")
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(size, size)
		shape.shape = rect
		body.add_child(shape)
		var look := Polygon2D.new()
		var h := size * 0.5
		look.polygon = PackedVector2Array([Vector2(-h, h), Vector2(-h, -h + 3), Vector2(-h + 3, -h - 4), Vector2(h - 3, -h - 2), Vector2(h, -h + 2), Vector2(h, h)])
		look.color = Color(0.62, 0.86, 1.0, 0.92)
		body.add_child(look)
		var shine := Polygon2D.new()
		shine.polygon = PackedVector2Array([Vector2(-h + 2, h - 2), Vector2(-h + 2, -h + 3), Vector2(-h + 4, -h - 1), Vector2(-h + 4, h - 2)])
		shine.color = Color(0.95, 1.0, 1.0, 0.95)
		body.add_child(shine)
		var edge := Line2D.new()
		edge.points = look.polygon
		edge.closed = true
		edge.width = 1.0
		edge.default_color = Color(0.25, 0.5, 0.85)
		body.add_child(edge)
		body.scale = Vector2(1, 0.2)
		add_child(body)
		body.create_tween().tween_property(body, "scale", Vector2.ONE, 0.15)

	func _ready() -> void:
		z_index = 2
		y_sort_enabled = false

	func _physics_process(delta: float) -> void:
		lifetime -= delta
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.25
			for enemy in SpellForms.enemies(game):
				if touching(enemy.global_position) and enemy.has_method("apply_slow"):
					enemy.apply_slow(slow, slow_time)
		if lifetime <= 0.0:
			shatter()

	func touching(at: Vector2) -> bool:
		for offset in block_offsets:
			if at.distance_to(global_position + offset) < _size * 1.4:
				return true
		return false

	## The wall breaks into shards that hurt everyone next to it.
	func shatter() -> void:
		set_physics_process(false)
		for enemy in SpellForms.enemies(game):
			if touching(enemy.global_position):
				SpellForms.hit(game, enemy, maxi(1, damage / 2), "ice")
		for offset in block_offsets:
			Vfx.burst(game, global_position + offset, Vfx.SPELL_COLORS["frostbolt"], 10, 70.0, 0.45)
		queue_free()

# --- Шаровая молния -----------------------------------------------------

static func ball_lightning(game: SkywardGame, spell: Dictionary, direction: Vector2, damage: int) -> Node2D:
	var orb := LightningOrb.new()
	orb.game = game
	orb.damage = damage
	orb.velocity = direction * float(spell.get("projectile_speed", 70.0))
	orb.lifetime = float(spell.get("duration", 3.2))
	orb.radius = float(spell.get("zap_radius", 56.0))
	orb.targets = int(spell.get("zap_targets", 2)) + game.player.get_chain_targets_bonus()
	orb.interval = float(spell.get("zap_interval", 0.35))
	game.add_child(orb)
	orb.global_position = game.player.global_position + direction * 12.0
	return orb

class LightningOrb extends Node2D:
	var game: SkywardGame
	var damage := 6
	var velocity := Vector2.ZERO
	var lifetime := 3.2
	var radius := 56.0
	var targets := 2
	var interval := 0.35
	var zaps := 0
	var _tick := 0.1
	var _t := 0.0

	func _ready() -> void:
		z_index = 30
		var glow := Polygon2D.new()
		glow.polygon = _circle(9.0)
		glow.color = Color(0.55, 0.4, 1.0, 0.35)
		add_child(glow)
		var core := Polygon2D.new()
		core.polygon = _circle(5.0)
		core.color = Color(0.85, 0.75, 1.0)
		add_child(core)
		var heart := Polygon2D.new()
		heart.polygon = _circle(2.5)
		heart.color = Color.WHITE
		add_child(heart)

	static func _circle(r: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in 12:
			points.append(Vector2.RIGHT.rotated(TAU * i / 12.0) * r)
		return points

	func _physics_process(delta: float) -> void:
		_t += delta
		lifetime -= delta
		global_position += velocity * delta
		scale = Vector2.ONE * (1.0 + 0.12 * sin(_t * 18.0))
		_tick -= delta
		if _tick <= 0.0:
			_tick = interval
			zap()
		if lifetime <= 0.0:
			Vfx.burst(game, global_position, Vfx.SPELL_COLORS["chain_lightning"], 16, 70.0, 0.4)
			queue_free()

	## Strikes the nearest foes around the orb.
	func zap() -> int:
		var near: Array[Node2D] = []
		for enemy in SpellForms.enemies(game):
			if enemy.global_position.distance_to(global_position) <= radius:
				near.append(enemy)
		near.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
		var count := 0
		for enemy in near.slice(0, targets):
			var at: Vector2 = enemy.global_position
			SpellForms.hit(game, enemy, damage, "lightning")
			if is_instance_valid(enemy) and enemy.has_method("apply_shock"):
				enemy.apply_shock(1.0)
			_flash(at)
			count += 1
		zaps += count
		if count > 0:
			GameAudio.play("cast_lightning", -16.0)
		return count

	func _flash(to_point: Vector2) -> void:
		var line := Line2D.new()
		line.width = 1.5
		line.default_color = Color(0.9, 0.85, 1.0)
		line.z_index = 31
		var from_point := global_position
		var points := PackedVector2Array([from_point])
		for i in range(1, 4):
			points.append(from_point.lerp(to_point, i / 4.0) + Vector2(randf_range(-4, 4), randf_range(-4, 4)))
		points.append(to_point)
		line.points = points
		game.add_child(line)
		var tween := line.create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 0.18)
		tween.tween_callback(line.queue_free)
