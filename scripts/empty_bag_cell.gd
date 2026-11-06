extends Control
class_name EmptyBagCell

## An empty square in the bag grid (also a drop target for worn items).

func _init() -> void:
	custom_minimum_size = InventoryItemButton.CELL
	mouse_filter = Control.MOUSE_FILTER_PASS

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, InventoryItemButton.CELL)
	draw_rect(rect, Color(0.07, 0.05, 0.045, 0.75))
	draw_rect(rect, Color(0.3, 0.22, 0.16, 0.8), false, 1.0)

func _bag() -> BagDropArea:
	var node := get_parent()
	while node != null and not node is BagDropArea:
		node = node.get_parent()
	return node as BagDropArea

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	var bag := _bag()
	return bag != null and bag._can_drop_data(at, data)

func _drop_data(at: Vector2, data: Variant) -> void:
	_bag()._drop_data(at, data)
