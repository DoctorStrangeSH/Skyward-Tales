extends SceneTree

const RELATIONSHIPS_SCRIPT := preload("res://scripts/npc_relationships.gd")

func _initialize() -> void:
	var relationships := RELATIONSHIPS_SCRIPT.new()
	if not _verify(relationships.has_npc("mira"), "Mira relationship is registered"):
		return
	if not _verify(relationships.get_score("mira") == 0, "new NPC starts neutral"):
		return
	if not _verify(relationships.get_rank("mira") == "Незнакомец", "neutral rank is correct"):
		return
	if not _verify(relationships.adjust("mira", 25) == 25, "positive relationship change is applied"):
		return
	if not _verify(relationships.get_rank("mira") == "Знакомый", "acquaintance threshold is correct"):
		return
	if not _verify(relationships.adjust("mira", 30) == 30 and relationships.get_rank("mira") == "Друг", "friend threshold is correct"):
		return
	if not _verify(relationships.adjust("mira", 100) == 45 and relationships.get_score("mira") == 100, "positive score is clamped"):
		return
	if not _verify(relationships.adjust("mira", -200) == -200 and relationships.get_score("mira") == -100, "negative score is clamped"):
		return
	if not _verify(relationships.get_rank("mira") == "Враждебность", "hostile threshold is correct"):
		return
	if not _verify(relationships.adjust("unknown_npc", 10) == 0, "unknown NPC cannot gain relationship"):
		return
	relationships.adjust("elder", 34)
	var snapshot: Dictionary = relationships.make_snapshot()
	var restored := RELATIONSHIPS_SCRIPT.new()
	restored.restore_snapshot(snapshot)
	if not _verify(restored.get_score("elder") == 34, "relationship survives snapshot restore"):
		return
	var mira_before_malformed_restore: int = restored.get_score("mira")
	restored.restore_snapshot({"elder": 9999, "unknown_npc": 50, "mira": "bad"})
	if not _verify(restored.get_score("elder") == 100, "restored score is clamped"):
		return
	if not _verify(restored.get_score("mira") == mira_before_malformed_restore, "malformed relationship value is ignored"):
		return
	var old_save := RELATIONSHIPS_SCRIPT.new()
	old_save.restore_snapshot({})
	if not _verify(old_save.get_score("mira") == 0, "old saves without relationships keep defaults"):
		return
	print("NPC RELATIONSHIPS OK: ranks, bounds, unknown IDs and save compatibility")
	quit(0)

func _verify(condition: bool, message: String) -> bool:
	if not condition:
		push_error("NPC RELATIONSHIP TEST FAILED: " + message)
		quit(1)
		return false
	return true
