extends RefCounted
class_name InventoryComparisonFormatter

# One formatting policy for equipment comparison. No UI nodes or game state.
static func value_text(value: float, unit: String) -> String:
	if unit == " с":
		return "%.2f%s" % [value, unit]
	return "%d%s" % [roundi(value), unit]

static func delta_text(value: float, unit: String) -> String:
	var sign: String = "+" if value > 0.0 else ""
	if unit == " с":
		return "%s%.2f%s" % [sign, value, unit]
	return "%s%d%s" % [sign, roundi(value), unit]
