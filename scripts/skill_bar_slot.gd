extends Control
class_name SkillBarSlot

## One of the four bar slots in the "Навыки" tab: accepts a dragged skill,
## can itself be dragged to another slot (swap) or out (clear).

signal dropped(slot_index: int, skill_id: String)
signal cleared(slot_index: int)

const SIZE := Vector2(30, 30)

var slot_index: int = 0
var skill_id: String = ""
var _hover := false
var _dragging := false

func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.has("skill_id")
	if ok != _hover:
		_hover = ok
		queue_redraw()
	return ok

func _drop_data(_at: Vector2, data: Variant) -> void:
	_hover = false
	dropped.emit(slot_index, str(data["skill_id"]))

func _get_drag_data(_at: Vector2) -> Variant:
	if skill_id.is_empty():
		return null
	set_drag_preview(UiStyle.drag_preview(CombatSkills.icon_path(skill_id)))
	_dragging = true
	return {"skill_id": skill_id, "from_slot": slot_index}

func _notification(what: int) -> void:
	# Dragged out and dropped nowhere: the slot is cleared.
	if what == NOTIFICATION_DRAG_END and _dragging:
		_dragging = false
		if not get_viewport().gui_is_drag_successful() and not skill_id.is_empty():
			cleared.emit(slot_index)

func _draw() -> void:
	UiStyle.draw_slot(self, Rect2(Vector2.ZERO, SIZE), _hover)
	var path := CombatSkills.icon_path(skill_id) if not skill_id.is_empty() else ""
	if not path.is_empty() and ResourceLoader.exists("res://assets/" + path):
		draw_texture_rect(WorldArt.texture(path), Rect2(Vector2(5, 5), Vector2(20, 20)), false)
	UiStyle.draw_key(self, Vector2(2, 8), str(slot_index + 1))
