extends Button
class_name EquipSlot

## Equipment slot on the hero doll. Drop a fitting item from the bag to wear
## it, click or drag it back to the bag to take it off.

signal equip_requested(item_id: String)
signal unequip_requested(slot: String)
signal hovered(slot: String)

const SIZE := Vector2(36, 36)
const NAMES := {"blade": "Клинок", "weapon": "Посох", "armor": "Броня", "amulet": "Амулет", "relic": "Реликвия"}

var slot: String = ""
var item_id: String = ""
var _accepting: bool = false

func setup(player: PlayerCharacter, slot_id: String) -> void:
	slot = slot_id
	item_id = str(player.equipment.get(slot, ""))
	custom_minimum_size = SIZE
	size = SIZE
	focus_mode = Control.FOCUS_NONE
	expand_icon = false
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var definition := player.get_item_definition(item_id) if not item_id.is_empty() else {}
	var rarity := str(definition.get("rarity", "common"))
	var border: Color = InventoryItemButton.RARITY_COLORS.get(rarity, Color(0.6, 0.5, 0.4)) if not item_id.is_empty() else Color(0.42, 0.32, 0.24)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.09, 0.06, 0.05, 0.95) if state != "hover" else Color(0.2, 0.14, 0.1, 0.98)
		box.border_color = border
		box.set_border_width_all(2)
		box.set_corner_radius_all(4)
		add_theme_stylebox_override(state, box)
	var icon_id := str(definition.get("icon", item_id))
	icon = WorldArt.texture("icons/%s.png" % icon_id) if not item_id.is_empty() and ResourceLoader.exists("res://assets/icons/%s.png" % icon_id) else null
	disabled = item_id.is_empty()
	tooltip_text = "%s: %s" % [NAMES.get(slot, slot), player.get_item_name(item_id) if not item_id.is_empty() else "пусто — перетащите сюда предмет"]
	queue_redraw()

func _ready() -> void:
	pressed.connect(func() -> void: unequip_requested.emit(slot))
	mouse_entered.connect(func() -> void: hovered.emit(slot))

func _draw() -> void:
	# Slot name under the frame.
	var font := UiFont.font()
	var caption: String = NAMES.get(slot, slot)
	draw_string(font, Vector2(-10, SIZE.y + 9), caption, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x + 20, UiFont.px(8), Color(0.75, 0.66, 0.52) if not item_id.is_empty() else Color(0.55, 0.48, 0.4))
	if _accepting:
		draw_rect(Rect2(Vector2(1, 1), SIZE - Vector2(2, 2)), Color(0.5, 1.0, 0.5, 0.9), false, 2.0)

func _get_drag_data(_at: Vector2) -> Variant:
	if item_id.is_empty():
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
	return {"kind": "slot", "slot": slot}

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.get("kind", "") == "item" and str(data.get("slot", "")) == slot
	if ok != _accepting:
		_accepting = ok
		queue_redraw()
	return ok

func _drop_data(_at: Vector2, data: Variant) -> void:
	_accepting = false
	queue_redraw()
	equip_requested.emit(str(data.get("item_id", "")))

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		if _accepting:
			_accepting = false
			queue_redraw()
