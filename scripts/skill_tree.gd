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

static func branch_skills(branch_id: String) -> Array[String]:
	var result: Array[String] = []
	var defs := definitions()
	for skill_id in defs:
		if str(defs[skill_id].get("branch", "")) == branch_id:
			result.append(str(skill_id))
	result.sort_custom(func(a: String, b: String) -> bool: return int(defs[a].get("tier", 1)) < int(defs[b].get("tier", 1)))
	return result
