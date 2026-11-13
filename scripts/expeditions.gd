extends Node
class_name Expeditions

## Expeditions into the Pattern Vault (Этап 15). Ragna of the guild sends
## the hero into the vault ("pattern_vault": a 3×3 grid of halls). Every run
## rolls its own foes, traps and chests, a modifier, and a rune puzzle that
## seals the treasure hall; the Vault Warden waits in the far hall.
##   Modifiers: «Тёмная экспедиция» (dark, foes hit harder), «Хрустальный
##   шторм» (crystals fall around the hero), «Проклятие Хранителя» (elite
##   foes everywhere); each pays more. «Спокойное хранилище» — none.
## A run lives until the hero leaves; leaving or reloading starts afresh.
## Этап 24 — the descent: after the warden a dark stair leads deeper (up to
## 3 depths below). Each depth is harder (+25% to foes) with a new modifier;
## its warden fills the descent chest instead of the floor. At the stair the
## chest can be taken (and the hero goes home richer) — or risked on the next
## depth: falling there loses the whole chest (it does not survive a reload),
## walking out by the vault's exit stair takes it along.

const REGION := "pattern_vault"
const EXIT := Vector2(480, 1150)
const START := Vector2(208, 800)
const HALL := Vector2(288, 208)
const COLS := [64, 480, 896]
const ROWS := [64, 368, 672]
const PUZZLE_HALL := Vector2i(0, 1)
const TREASURE_HALL := Vector2i(0, 0)
const BOSS_HALL := Vector2i(2, 0)
const START_HALL := Vector2i(0, 2)
const SEAL := "vault_runes"
const SEAL_POSITION := Vector2(208, 334)
const RUNES := [["fire", "Огонь", Color(1.0, 0.5, 0.2)], ["ice", "Лёд", Color(0.5, 0.85, 1.0)], ["storm", "Буря", Color(0.75, 0.55, 1.0)], ["earth", "Земля", Color(0.55, 0.9, 0.4)]]
const MODIFIERS := {
	"calm": {"name": "Спокойное хранилище", "text": "Тишина и пыль. Ничего необычного.", "reward": 1.0},
	"dark": {"name": "Тёмная экспедиция", "text": "Факелы погасли: в темноте твари бьют на 25% сильнее. Награда ×1,5.", "reward": 1.5},
	"storm": {"name": "Хрустальный шторм", "text": "С потолка срываются кристаллы — уходите из светящихся кругов! Награда ×1,5.", "reward": 1.5},
	"curse": {"name": "Проклятие Хранителя", "text": "Стражи хранилища закалены проклятием: почти все — элита. Награда ×1,6.", "reward": 1.6},
}
const TIERS := [
	[1, ["skeleton", "slime", "bat"], "golem"],
	[5, ["skeleton", "golem", "bat", "wisp"], "golem"],
	[9, ["golem", "sentinel", "ember_hound", "shade"], "sentinel"],
	[13, ["magma_golem", "sentinel", "shade", "ash_cultist"], "magma_golem"],
]

var game: SkywardGame
var active: bool = false
var run: int = 0
var modifier: String = "calm"
var level: int = 1
var order: Array = []
var progress: int = 0
var solved: bool = false
var warden_spawned: bool = false
var warden_down: bool = false
var completed: int = 0
## Этап 18: difficulty — 0 обычная, 1 героическая (after 3 runs), 2 легендарная
## (after 3 heroic runs; the warden becomes the Keeper of the Abyss).
const DIFFICULTY := [
	{"name": "Обычная", "power": 1.0, "reward": 1.0},
	{"name": "Героическая", "power": 1.5, "reward": 2.0},
	{"name": "Легендарная", "power": 2.2, "reward": 3.0},
]
var difficulty: int = 0
var heroic_done: int = 0
var legendary_done: int = 0
var rng := RandomNumberGenerator.new()
const MAX_DEPTH := 3
const STAIR_OFFSET := Vector2(0, 50)
## The descent: 0 — the first hall, 1..3 — depths below.
var depth: int = 0
var deepest: int = 0
var bank_gold: int = 0
## Rarities of the finds in the descent chest.
var bank_items: Array = []
var _storm_clock: float = 0.0
var _dark: ColorRect

func _ready() -> void:
	rng.randomize()

static func hall_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(COLS[cell.x], ROWS[cell.y]), HALL)

func unlocked_difficulty() -> int:
	if heroic_done >= 3:
		return 2
	return 1 if completed >= 3 else 0

func reward_mult() -> float:
	return float(MODIFIERS[modifier]["reward"]) * float(DIFFICULTY[difficulty]["reward"]) * (1.0 + 0.5 * float(depth))

## Ragna's offer: a new run into the vault.
func start(tier: int = 0) -> void:
	difficulty = clampi(tier, 0, unlocked_difficulty())
	depth = 0
	bank_gold = 0
	bank_items.clear()
	run += 1
	active = true
	level = maxi(1, game.player.level)
	var keys := MODIFIERS.keys()
	modifier = "calm" if run == 1 else str(keys[rng.randi_range(0, keys.size() - 1)])
	order = [0, 1, 2, 3]
	order.shuffle()
	progress = 0
	solved = false
	warden_spawned = false
	warden_down = false
	# Forget the previous run's chests and seal.
	for key in game.opened_chests.keys():
		if str(key).begins_with("vault_"):
			game.opened_chests.erase(key)
	game.opened_doors.erase(SEAL)
	game._travel(REGION, START)
	var info: Dictionary = MODIFIERS[modifier]
	game.hud.show_title_card("Хранилище Узора · %s%s" % [str(info["name"]), "" if difficulty == 0 else " · " + str(DIFFICULTY[difficulty]["name"])], 3.0)
	game.hud.show_message(str(info["text"]), 5.0)

func leave() -> void:
	# Walked out with the chest still on the back: it comes along.
	if active and (bank_gold > 0 or not bank_items.is_empty()):
		cash_out()
	active = false
	depth = 0
	if _dark != null and is_instance_valid(_dark):
		_dark.queue_free()

func power() -> float:
	return (0.7 + 0.07 * float(level)) * float(DIFFICULTY[difficulty]["power"]) * (1.0 + 0.25 * float(depth))

func _tier() -> Array:
	var pick: Array = TIERS[0]
	for tier in TIERS:
		if level >= int(tier[0]):
			pick = tier
	return pick

func _random_spot(cell: Vector2i, margin: float = 40.0) -> Vector2:
	var rect := hall_rect(cell).grow(-margin)
	return Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y + 20.0, rect.end.y))

## Fills the vault for the current run (called when the region is built).
func populate() -> void:
	if _dark != null and is_instance_valid(_dark):
		_dark.queue_free()
	if not active:
		start_silently()
	var tier := _tier()
	var kinds: Array = tier[1]
	var fight_halls: Array = []
	for row in 3:
		for col in 3:
			var cell := Vector2i(col, row)
			if cell in [START_HALL, BOSS_HALL, TREASURE_HALL]:
				continue
			fight_halls.append(cell)
	var chest_serial := 0
	for cell in fight_halls:
		var count := rng.randi_range(3, 5) if cell != PUZZLE_HALL else 2
		for i in count:
			_spawn_foe(str(kinds[rng.randi_range(0, kinds.size() - 1)]), _random_spot(cell))
		if rng.randf() < 0.45:
			for i in rng.randi_range(2, 4):
				var trap: Node2D = SpikeTrap.new() if rng.randf() < 0.6 else FlameVent.new()
				game.add_child(trap)
				trap.global_position = _random_spot(cell, 60.0)
		if rng.randf() < 0.4:
			chest_serial += 1
			_chest(chest_serial, _random_spot(cell, 50.0), "iron" if rng.randf() < 0.5 else "wood")
	# The treasure hall behind the rune seal.
	var treasure := hall_rect(TREASURE_HALL)
	_chest(90, treasure.get_center() + Vector2(-50, 10), "gold")
	_chest(91, treasure.get_center() + Vector2(50, 10), "iron")
	# The seal and the rune puzzle.
	var door := DungeonDoor.new()
	door.door_id = SEAL
	door.levers.append(SEAL)
	door.is_open = solved
	game.add_child(door)
	door.global_position = SEAL_POSITION
	door.used.connect(func(_d: DungeonDoor) -> void:
		game.hud.show_message("Печать рун. Наступите на руны в верном порядке — его хранит рунная скрижаль.", 3.5))
	var puzzle := hall_rect(PUZZLE_HALL)
	var tablet := RuneTablet.new()
	game.add_child(tablet)
	tablet.global_position = puzzle.position + Vector2(puzzle.size.x * 0.5, 54)
	tablet.used.connect(_read_tablet)
	var spots := [Vector2(-80, 0), Vector2(80, 0), Vector2(-80, 70), Vector2(80, 70)]
	for index in 4:
		var plate := RunePlate.new()
		plate.rune = index
		plate.color = RUNES[index][2]
		plate.lit = solved
		game.add_child(plate)
		plate.global_position = puzzle.get_center() + spots[index] + Vector2(0, -10)
		plate.stepped.connect(_on_plate)
	if modifier == "dark":
		_dark = ColorRect.new()
		_dark.color = Color(0.0, 0.0, 0.04, 0.42)
		_dark.size = Vector2(1400, 1100)
		_dark.position = Vector2(-80, -80)
		_dark.z_index = 55
		_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game.world.add_child(_dark)

func start_silently() -> void:
	# Loaded inside the vault without a run: roll a fresh one in place.
	run += 1
	active = true
	level = maxi(1, game.player.level)
	modifier = "calm"
	order = [0, 1, 2, 3]
	order.shuffle()
	progress = 0
	solved = false
	warden_spawned = false
	warden_down = false
	for key in game.opened_chests.keys():
		if str(key).begins_with("vault_"):
			game.opened_chests.erase(key)
	game.opened_doors.erase(SEAL)

func _spawn_foe(kind: String, at: Vector2, boss: bool = false) -> SlimeEnemy:
	var elite := ""
	if modifier == "curse" and not boss and EliteModifiers.can_be_elite(kind) and rng.randf() < 0.7:
		elite = EliteModifiers.roll(rng)
	var enemy := game.spawn_enemy(kind, at, elite)
	if enemy == null:
		return null
	enemy.set_meta("vault", true)
	# The region already scaled the foe; swap that for the run's own power.
	var mult := power() / maxf(0.1, RegionCatalog.enemy_power(REGION)) * (1.25 if boss else 1.0)
	enemy.max_health = roundi(enemy.max_health * mult * (4.0 if boss else 1.0))
	enemy.health = enemy.max_health
	enemy.attack_damage = roundi(enemy.attack_damage * mult * (1.25 if modifier == "dark" else 1.0))
	enemy.xp_reward = roundi(enemy.xp_reward * mult)
	enemy.combat_feedback.set_health(enemy.health, enemy.max_health)
	return enemy

func _chest(serial: int, at: Vector2, tier: String) -> void:
	var gold := roundi((30 + 12 * level) * (3 if tier == "gold" else 1) * reward_mult())
	var item := "health_potion" if tier != "gold" else "starlight_essence"
	game._spawn_chest("vault_%d_%d" % [run, serial], at, gold, item, 1 if tier == "gold" else 2, tier)

func _read_tablet() -> void:
	var names: Array[String] = []
	for index in order:
		names.append(str(RUNES[int(index)][1]))
	game._show_dialogue("Рунная скрижаль", "«Печать откроет тот, кто пройдёт путь стихий: %s». Наступите на руны по порядку." % " → ".join(names))

func _on_plate(plate: RunePlate) -> void:
	if solved or plate.lit:
		return
	if int(order[progress]) == plate.rune:
		progress += 1
		plate.lit = true
		plate.queue_redraw()
		GameAudio.play("pickup", -4.0, 0.1 * progress)
		if progress >= order.size():
			solved = true
			game.opened_doors[SEAL] = true
			for node in game.get_children():
				if node is DungeonDoor and node.door_id == SEAL:
					node.set_open(true)
			game.shake(3.0, 0.3)
			game.hud.show_title_card("Печать рун открыта", 2.0)
			game.achievements.add("rune_puzzles")
		return
	# A wrong rune: the plates go dark and the vault wakes its guards.
	progress = 0
	for node in game.get_children():
		if node is RunePlate:
			node.lit = false
			node.queue_redraw()
	game.hud.show_message("Руны гаснут… стражи хранилища пробуждаются!", 2.5)
	GameAudio.play("boss_roar", -10.0, 0.2)
	var kinds: Array = _tier()[1]
	for i in 2:
		_spawn_foe(str(kinds[0]), plate.global_position + Vector2(rng.randf_range(-60, 60), rng.randf_range(-40, 40)))

func _process(delta: float) -> void:
	if game == null or not active:
		return
	if game.current_region != REGION:
		leave()
		return
	if game.get_tree().paused:
		return
	var hero := game.player.global_position
	if not warden_spawned and hall_rect(BOSS_HALL).grow(-20).has_point(hero):
		_spawn_warden()
	if modifier == "storm":
		_storm_clock -= delta
		if _storm_clock <= 0.0:
			_storm_clock = rng.randf_range(4.0, 6.0)
			for i in 3:
				var strike := CrystalStrike.new()
				strike.damage = maxi(4, roundi(game.player.max_health * 0.1))
				game.add_child(strike)
				strike.global_position = hero + Vector2(rng.randf_range(-70, 70), rng.randf_range(-50, 50))

func _spawn_warden() -> void:
	warden_spawned = true
	var kind := str(_tier()[2])
	var hall := hall_rect(BOSS_HALL)
	var enemy := _spawn_foe(kind, hall.get_center() + Vector2(0, -20), true)
	if enemy == null:
		return
	enemy.knockback_resist = maxf(enemy.knockback_resist, 0.8)
	enemy.visual.scale *= 1.6
	enemy.combat_feedback.elite = true
	enemy.combat_feedback.elite_name = "♦ Страж хранилища"
	enemy.combat_feedback.elite_color = Color(0.6, 0.8, 1.0)
	enemy.combat_feedback.bar_y *= 1.6
	enemy.base_visual_tint = Color(0.75, 0.85, 1.0)
	enemy.visual.modulate = enemy.base_visual_tint
	enemy.defeated.connect(func(_xp: int) -> void: _on_warden_down(enemy.global_position))
	if difficulty == 2:
		# Legendary: the Keeper of the Abyss.
		enemy.max_health = roundi(enemy.max_health * 1.5)
		enemy.health = enemy.max_health
		enemy.combat_feedback.elite_name = "♦ Хранитель Бездны"
		enemy.combat_feedback.elite_color = Color(0.55, 0.6, 1.0)
		enemy.base_visual_tint = Color(0.8, 0.85, 1.35)
		enemy.visual.modulate = enemy.base_visual_tint
		enemy.combat_feedback.set_health(enemy.health, enemy.max_health)
		BossMechanics.attach(enemy, game, "abyss")
		game.hud.show_title_card("Хранитель Бездны", 2.5)
		GameAudio.play("boss_roar", -2.0, 0.0)
		return
	game.hud.show_title_card("Страж хранилища", 2.5)
	GameAudio.play("boss_roar", -4.0, 0.0)

func _on_warden_down(at: Vector2) -> void:
	if warden_down:
		return
	warden_down = true
	completed += 1
	if difficulty == 1:
		heroic_done += 1
	elif difficulty == 2:
		legendary_done += 1
		game.achievements.add("abyss")
		game._spawn_loot(at + Vector2(20, -16), SkillTree.RESET_TOME)
		game.spawn_generated_loot(at + Vector2(-20, -16), "legendary")
	var mult := reward_mult()
	if depth > 0:
		_fill_bank(mult)
		_spawn_stair()
		game.request_autosave()
		return
	game._spawn_loot(at + Vector2(-16, 8), "gold").amount = roundi((150 + 30 * level) * mult)
	game.spawn_generated_loot(at + Vector2(16, 8), "epic" if rng.randf() < 0.25 * mult else "rare")
	if mult > 1.0:
		game.spawn_generated_loot(at + Vector2(0, 20), "rare")
	var missing: Array = SkywardGame.KEEPER_SET.filter(func(id: String) -> bool: return not game.player.inventory.has(id) and not game.player.wears_base(id))
	if not missing.is_empty() and rng.randf() < 0.35:
		game._spawn_loot(at + Vector2(0, -14), str(missing[rng.randi_range(0, missing.size() - 1)]))
	game.achievements.add("expeditions")
	game.hud.show_title_card("Хранилище пройдено!", 3.0)
	game.hud.show_message("Экспедиций пройдено: %d. Выход — лестница у входа в хранилище. В зале стража открылся тёмный спуск вниз…" % completed, 5.0)
	_spawn_stair()
	game.request_autosave()

# --- The descent -------------------------------------------------------------------

func _fill_bank(mult: float) -> void:
	bank_gold += roundi((150 + 30 * level) * mult)
	bank_items.append("epic" if depth >= 2 else "rare")
	if depth >= MAX_DEPTH:
		bank_items.append("legendary")
	deepest = maxi(deepest, depth)
	game.achievements.set_max("depth", depth)
	game.hud.show_title_card("Глубина %d пройдена" % depth, 2.6)
	game.hud.show_message("Сундук спуска: %d золота, находок: %d. Заберите его у тёмной лестницы — или рискните глубже." % [bank_gold, bank_items.size()], 5.0)

func _spawn_stair() -> void:
	var stair := TowerObject.new()
	stair.art = "gate_stairs_down"
	stair.label = "E — тёмная лестница вниз"
	stair.glow = Color(0.5, 0.4, 1.0, 0.7)
	stair.add_to_group("vault_stair")
	game.add_child(stair)
	stair.global_position = hall_rect(BOSS_HALL).get_center() + STAIR_OFFSET
	stair.used.connect(func(_object: TowerObject) -> void: offer_descent())

func offer_descent() -> void:
	var choices: Array[Dictionary] = []
	var text := ""
	if depth >= MAX_DEPTH:
		text = "Ниже — только камень. Глубже дороги нет."
	else:
		text = "Из темноты тянет холодом. Глубина %d: враги сильнее на %d%%, другое испытание, награда ×%s за всё, что найдёте ниже." % [depth + 1, roundi(25.0 * float(depth + 1)), ("%.1f" % (1.0 + 0.5 * float(depth + 1))).trim_suffix(".0").replace(".", ",")]
		choices.append({"id": "vault_deeper", "label": "Спуститься на глубину %d (риск)" % (depth + 1)})
	if bank_gold > 0 or not bank_items.is_empty():
		text += "\n\nСундук спуска: %d золота, находок: %d. Падёте ниже — он пропадёт." % [bank_gold, bank_items.size()]
		choices.append({"id": "vault_cash", "label": "Забрать сундук (%d золота, находок: %d)" % [bank_gold, bank_items.size()]})
	choices.append({"id": "vault_stay", "label": "Не сейчас"})
	game._show_dialogue_choices("Тёмная лестница", text, choices)

func handle_choice(choice_id: String) -> bool:
	if not choice_id.begins_with("vault_"):
		return false
	game.dialogues._close()
	if choice_id == "vault_deeper":
		descend()
	elif choice_id == "vault_cash":
		cash_out()
	return true

func descend() -> bool:
	if not active or not warden_down or depth >= MAX_DEPTH:
		return false
	depth += 1
	var keys := MODIFIERS.keys().filter(func(key: String) -> bool: return key != "calm" and key != modifier)
	modifier = str(keys[rng.randi_range(0, keys.size() - 1)])
	order = [0, 1, 2, 3]
	order.shuffle()
	progress = 0
	solved = false
	warden_spawned = false
	warden_down = false
	run += 1
	game.opened_doors.erase(SEAL)
	game._travel(REGION, START)
	var info: Dictionary = MODIFIERS[modifier]
	game.hud.show_title_card("Глубина %d · %s" % [depth, str(info["name"])], 3.0)
	game.hud.show_message("%s Враги сильнее на %d%%. Сундук спуска пропадёт, если падёте." % [str(info["text"]), roundi(25.0 * float(depth))], 5.0)
	GameAudio.play("boss_roar", -10.0, 0.1)
	return true

## Takes the descent chest: gold and rolled finds straight into the bag.
func cash_out() -> void:
	if bank_gold <= 0 and bank_items.is_empty():
		return
	var hero := game.player
	hero.add_gold(bank_gold)
	var names: Array[String] = []
	for rarity in bank_items:
		var definition := LootGenerator.generate(game.loot_rng, hero.level, str(rarity))
		if definition.is_empty():
			continue
		var item_id := hero.register_generated_item(definition)
		hero.add_item(item_id, 1)
		names.append(hero.get_item_name(item_id))
	game.hud.show_title_card("Сундук спуска", 2.4)
	game.hud.show_message("+%d золота%s" % [bank_gold, (": " + ", ".join(names)) if not names.is_empty() else ""], 5.0)
	GameAudio.play("chest", -2.0, 0.0)
	game.achievements.add("descents")
	bank_gold = 0
	bank_items.clear()
	game.request_autosave()

## Map pins inside the vault: the warden's hall and the rune seal.
func targets() -> Array:
	if not active:
		return []
	var result: Array = []
	if not warden_down:
		result.append({"region": REGION, "position": hall_rect(BOSS_HALL).get_center(), "kind": "side", "title": "Страж хранилища"})
	if warden_down and depth < MAX_DEPTH:
		result.append({"region": REGION, "position": hall_rect(BOSS_HALL).get_center() + STAIR_OFFSET, "kind": "side", "title": "Тёмная лестница вниз"})
	if not solved:
		result.append({"region": REGION, "position": hall_rect(PUZZLE_HALL).get_center(), "kind": "side", "title": "Печать рун"})
	return result

func make_snapshot() -> Dictionary:
	# The descent chest is not saved: a fall (and a reload) loses it.
	return {"completed": completed, "run": run, "heroic": heroic_done, "legendary": legendary_done, "deepest": deepest}

func restore_snapshot(value: Variant) -> void:
	if value is Dictionary:
		completed = int(value.get("completed", 0))
		run = int(value.get("run", 0))
		heroic_done = int(value.get("heroic", 0))
		legendary_done = int(value.get("legendary", 0))
		deepest = int(value.get("deepest", 0))
	depth = 0
	bank_gold = 0
	bank_items.clear()
