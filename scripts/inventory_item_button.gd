extends Button
class_name InventoryItemButton

signal use_requested(item_id: String)
signal compare_requested(item_id: String)

var item_id: String = ""

func configure(player: PlayerCharacter, id: String, fallback_names: Dictionary, fallback_descriptions: Dictionary, rarity_names: Dictionary, consumable_ids: Array) -> void:
	item_id = id
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var count: int = int(player.inventory.get(item_id, 0))
	var equipped: bool = item_id in player.equipment.values()
	var definition: Dictionary = player.get_item_definition(item_id)
	var item_name: String = InventoryItemOrder.display_name(player, item_id, fallback_names)
	var description: String = str(fallback_descriptions.get(item_id, player.get_item_description(item_id)))
	var rarity: String = str(definition.get("rarity", ""))
	var rarity_label: String = " • " + str(rarity_names.get(rarity, rarity)).to_lower() if not rarity.is_empty() else ""
	var can_equip: bool = not str(definition.get("slot", "")).is_empty()
	var can_consume: bool = consumable_ids.has(item_id)
	var action_hint: String = "Клик: экипировать" if can_equip else ("Клик: использовать" if can_consume else "Этот предмет нельзя использовать.")
	text = "%s ×%d — %s%s%s" % [item_name, count, description, rarity_label, " [НАДЕТО]" if equipped else ""]
	tooltip_text = (description + "\n" if not description.is_empty() else "") + action_hint
	if can_equip:
		tooltip_text += "\nНаведение: сравнить характеристики"
	disabled = count <= 0 or not (can_equip or can_consume)

func _ready() -> void:
	pressed.connect(_on_item_pressed)
	mouse_entered.connect(_on_item_hovered)

func _on_item_pressed() -> void:
	if not disabled:
		use_requested.emit(item_id)

func _on_item_hovered() -> void:
	if not disabled and tooltip_text.contains("Наведение: сравнить характеристики"):
		compare_requested.emit(item_id)
