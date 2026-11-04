extends Button
class_name InventoryItemButton

## One cell of the bag grid: the item's icon framed in its rarity colour and
## the stack size. Left click — equip / use; right click — the same; drag it
## onto an equipment slot to equip; drop a slot here to take it off.
## `summary` keeps the full text line (name ×count — description …).

signal use_requested(item_id: String)
signal compare_requested(item_id: String)
signal hovered(item_id: String)
signal unhovered
signal unequip_requested(slot: String)

const CELL := Vector2(34, 34)
const RARITY_COLORS := {
	"common": Color(0.95, 0.93, 0.86),
	"uncommon": Color(0.55, 0.95, 0.55),
	"rare": Color(0.45, 0.72, 1.0),
	"epic": Color(0.82, 0.52, 1.0),
	"legendary": Color(1.0, 0.66, 0.22)
}

var item_id: String = ""
var summary: String = ""
var slot: String = ""
var can_use: bool = false
var equipped: bool = false
var rarity_color := Color(0.6, 0.5, 0.4)

func configure(player: PlayerCharacter, id: String, fallback_names: Dictionary, fallback_descriptions: Dictionary, rarity_names: Dictionary, consumable_ids: Array) -> void:
	item_id = id
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = CELL
	var count: int = int(player.inventory.get(item_id, 0))
	equipped = item_id in player.equipment.values()
	var definition: Dictionary = player.get_item_definition(item_id)
	var item_name: String = InventoryItemOrder.display_name(player, item_id, fallback_names)
	var description: String = str(fallback_descriptions.get(item_id, player.get_item_description(item_id)))
	var rarity: String = str(definition.get("rarity", ""))
	var rarity_label: String = " • " + str(rarity_names.get(rarity, rarity)).to_lower() if not rarity.is_empty() else ""
	slot = str(definition.get("slot", ""))
	var can_equip: bool = not slot.is_empty()
	var can_consume: bool = consumable_ids.has(item_id)
	can_use = count > 0 and (can_equip or can_consume)
	var action_hint: String = "Клик или перетащите в слот героя — надеть" if can_equip else ("Клик — использовать" if can_consume else "Материал: для ремесла или продажи.")
	summary = "%s ×%d — %s%s%s" % [item_name, count, description, rarity_label, " [НАДЕТО]" if equipped else ""]
	text = str(count) if count > 1 else ""
	tooltip_text = (description + "\n" if not description.is_empty() else "") + action_hint
	if can_equip:
		tooltip_text += "\nНаведение: сравнить характеристики"
	rarity_color = RARITY_COLORS.get(rarity, Color(0.6, 0.5, 0.4)) if not rarity.is_empty() else Color(0.55, 0.45, 0.35)
	add_theme_font_size_override("font_size", UiFont.px(8))
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	add_theme_constant_override("outline_size", 3)
	alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expand_icon = false
	var icon_id: String = str(definition.get("icon", item_id))
	if ResourceLoader.exists("res://assets/icons/%s.png" % icon_id):
		icon = WorldArt.texture("icons/%s.png" % icon_id)
	_apply_style()

func _apply_style() -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.11, 0.08, 0.07, 0.95) if state != "hover" else Color(0.22, 0.16, 0.12, 0.98)
		box.border_color = rarity_color if state != "hover" else rarity_color.lightened(0.3)
		box.set_border_width_all(1 if state != "hover" else 2)
		box.set_corner_radius_all(3)
		box.content_margin_right = 3
		box.content_margin_bottom = 1
		box.content_margin_top = 18
		add_theme_stylebox_override(state, box)

func _ready() -> void:
	pressed.connect(_on_item_pressed)
	mouse_entered.connect(_on_item_hovered)
	mouse_exited.connect(func() -> void: unhovered.emit())

func _draw() -> void:
	if equipped:
		draw_rect(Rect2(Vector2(2, 2), Vector2(6, 6)), Color(0.5, 1.0, 0.5))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_on_item_pressed()
		accept_event()

func _on_item_pressed() -> void:
	if can_use:
		use_requested.emit(item_id)

func _on_item_hovered() -> void:
	hovered.emit(item_id)
	if not slot.is_empty():
		compare_requested.emit(item_id)

# --- Drag and drop -------------------------------------------------------------

func _get_drag_data(_at: Vector2) -> Variant:
	if not can_use:
		return null
	var preview := TextureRect.new()
	preview.texture = icon
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.size = Vector2(32, 32)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.position = Vector2(-16, -16)
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return {"kind": "item", "item_id": item_id, "slot": slot}

## A worn item dragged back onto the bag comes off.
func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind", "") == "slot"

func _drop_data(_at: Vector2, data: Variant) -> void:
	unequip_requested.emit(str(data.get("slot", "")))
