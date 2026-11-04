extends ScrollContainer
class_name BagDropArea

## The bag: dropping a worn item here takes it off.

signal unequip_requested(slot: String)

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind", "") == "slot"

func _drop_data(_at: Vector2, data: Variant) -> void:
	unequip_requested.emit(str(data.get("slot", "")))
