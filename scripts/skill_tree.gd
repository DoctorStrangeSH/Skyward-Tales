extends RefCounted
class_name SkillTree

## Elemental skill tree rules on top of data/talents.json.
## Ranks are stored in PlayerCharacter.talents (same as the old level-up
## talents, so old saves keep their choices). One point per level after the
## first; tier-3 skills also cost one "Печать Неба" (sky_seal) from bosses.

const BRANCHES := [
	{"id": "blade", "name": "Клинок", "group": "warrior", "color": Color(1.0, 0.82, 0.5)},
	{"id": "guard", "name": "Стойкость", "group": "warrior", "color": Color(0.85, 0.7, 0.6)},
	{"id": "wanderer", "name": "Странник", "group": "warrior", "color": Color(0.7, 0.95, 0.6)},
	{"id": "fire", "name": "Огонь", "group": "mage", "color": Color(1.0, 0.6, 0.3)},
	{"id": "ice", "name": "Лёд", "group": "mage", "color": Color(0.55, 0.85, 1.0)},
	{"id": "lightning", "name": "Молния", "group": "mage", "color": Color(0.8, 0.65, 1.0)},
]
const GROUPS := [{"id": "warrior", "name": "Воин"}, {"id": "mage", "name": "Маг"}]
const SEAL_ITEM := "sky_seal"

static func definitions() -> Dictionary:
	return GameCatalogs.shared().talents

static func spent_points(player: PlayerCharacter) -> int:
	var total := 0
	for skill_id in player.talents:
		total += int(player.talents[skill_id])
	return total

static func available_points(player: PlayerCharacter) -> int:
	return maxi(0, player.level - 1 + player.bonus_skill_points - spent_points(player))

static func seals(player: PlayerCharacter) -> int:
	return int(player.inventory.get(SEAL_ITEM, 0))

static func rank(player: PlayerCharacter, skill_id: String) -> int:
	return int(player.talents.get(skill_id, 0))

## Why a skill cannot be learned right now ("" means it can).
static func block_reason(player: PlayerCharacter, skill_id: String) -> String:
	var defs := definitions()
	if not defs.has(skill_id):
		return "Неизвестный навык."
	var definition: Dictionary = defs[skill_id]
	if rank(player, skill_id) >= int(definition.get("max_rank", 1)):
		return "Изучено полностью."
	var requires: Dictionary = definition.get("requires", {})
	for required_id in requires:
		if rank(player, str(required_id)) < int(requires[required_id]):
			return "Сначала изучите «%s»." % str(defs.get(required_id, {}).get("name", required_id))
	if available_points(player) <= 0:
		return "Нет очков навыков — получите новый уровень."
	if bool(definition.get("seal", false)) and seals(player) <= 0:
		return "Нужна Печать Неба — её дают боссы."
	return ""

static func can_learn(player: PlayerCharacter, skill_id: String) -> bool:
	return block_reason(player, skill_id).is_empty()

static func learn(player: PlayerCharacter, skill_id: String) -> bool:
	if not can_learn(player, skill_id):
		return false
	var definition: Dictionary = definitions()[skill_id]
	if bool(definition.get("seal", false)) and not player.remove_item(SEAL_ITEM, 1):
		return false
	return player.apply_talent(skill_id)

## Gold to unlearn everything (a mentor's lesson grows dearer with level).
static func reset_cost(player: PlayerCharacter) -> int:
	return 30 * maxi(1, player.level)

## Unlearns every skill: points come back, sky seals too.
static func reset(player: PlayerCharacter) -> bool:
	if (spent_points(player) <= 0 and player.keystones.is_empty()) or player.gold < reset_cost(player):
		return false
	player.add_gold(-reset_cost(player))
	var defs := definitions()
	var seals_back := 0
	for skill_id in player.talents.keys():
		var rank_now := int(player.talents[skill_id])
		if bool(defs.get(skill_id, {}).get("seal", false)):
			seals_back += rank_now
		match str(skill_id):
			"vitality":
				player.max_health = maxi(1, player.max_health - 15 * rank_now)
				player.health = mini(player.health, player.max_health)
			"mana_well":
				player.max_mana = maxi(1, player.max_mana - 12 * rank_now)
				player.mana = mini(player.mana, player.max_mana)
	player.talents.clear()
	# Key talents come back too: they are offered again.
	player.keystones.clear()
	player.keystone_offered.clear()
	if seals_back > 0:
		player.add_item(SEAL_ITEM, seals_back)
	player.stats_changed.emit()
	return true

static func branch_skills(branch_id: String) -> Array[String]:
	var result: Array[String] = []
	var defs := definitions()
	for skill_id in defs:
		if str(defs[skill_id].get("branch", "")) == branch_id:
			result.append(str(skill_id))
	result.sort_custom(func(a: String, b: String) -> bool: return int(defs[a].get("tier", 1)) < int(defs[b].get("tier", 1)))
	return result
