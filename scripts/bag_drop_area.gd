extends ScrollContainer
class_name BagDropArea

## The bag: dropping a worn item here takes it off.

signal unequip_requested(slot: String)
## A bag item dropped on the empty part of the bag goes to the end.
signal reorder_requested(item_id: String, before_id: String)

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind", "") in ["slot", "item"]

func _drop_data(_at: Vector2, data: Variant) -> void:
	if data.get("kind", "") == "slot":
		unequip_requested.emit(str(data.get("slot", "")))
	else:
		reorder_requested.emit(str(data.get("item_id", "")), "")
