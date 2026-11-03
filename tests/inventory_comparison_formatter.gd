extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, reason: String) -> bool:
	if not condition:
		push_error("COMPARISON FORMAT FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	if not _require(InventoryComparisonFormatter.value_text(2.756, " с") == "2.76 с", "duration precision"):
		return
	if not _require(InventoryComparisonFormatter.value_text(4.6, "") == "5", "integer rounding"):
		return
	if not _require(InventoryComparisonFormatter.delta_text(2.0, "") == "+2", "positive delta"):
		return
	if not _require(InventoryComparisonFormatter.delta_text(-3.0, "") == "-3", "negative delta"):
		return
	if not _require(InventoryComparisonFormatter.delta_text(0.75, " с") == "+0.75 с", "duration delta"):
		return
	var hud: GameHud = GameHud.new()
	if not _require(hud._format_comparison_value(0.75, " с") == InventoryComparisonFormatter.value_text(0.75, " с"), "HUD value delegation"):
		return
	if not _require(hud._format_comparison_delta(-2.0, "") == InventoryComparisonFormatter.delta_text(-2.0, ""), "HUD delta delegation"):
		return
	print("COMPARISON FORMAT OK")
	quit(0)
