extends VBoxContainer
class_name PartyPage

## «Отряд» tab of the hero window (owner's list №19): the companions who
## travel with the hero — level and experience, their own skills (a point a
## level), three gear slots filled from the hero's bag, tactics.

signal changed

var crew: Crew
var _slot_open: String = ""

func populate(owner_crew: Crew) -> void:
	crew = owner_crew
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 4)
	var ids := crew.active_ids()
	if ids.is_empty():
		var empty := UiStyle.label("В отряде пока никого. Мира пойдёт с вами по сюжету, Торен — после охоты на легенду, Рейна — после истории Миры.", 9, UiStyle.MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(590, 0)
		add_child(empty)
		return
	if not ids.has(crew.selected):
		crew.selected = ids[0]
	var pick := HBoxContainer.new()
	pick.add_theme_constant_override("separation", 4)
	add_child(pick)
	for id in ids:
		var button := Button.new()
		button.text = "%s · ур. %d" % [str(Crew.info(id).get("name", id)), int(crew.state(id)["level"])]
		button.toggle_mode = true
		button.button_pressed = id == crew.selected
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(110, 18)
		button.add_theme_font_size_override("font_size", UiFont.px(9))
		UiStyle.small_toggle(button)
		var target: String = id
		button.pressed.connect(func() -> void:
			crew.selected = target
			_slot_open = ""
			populate(crew))
		pick.add_child(button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	row.add_child(_info_column(crew.selected))
	row.add_child(_gear_column(crew.selected))
	row.add_child(_skills_column(crew.selected))

func _column(width: float, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.add_theme_constant_override("separation", 2)
	box.add_child(UiStyle.section(title))
	return box

func _info_column(id: String) -> Control:
	var box := _column(180, str(Crew.info(id).get("role", "")))
	var s := crew.state(id)
	var st := crew.stats(id)
	var need := PlayerCharacter.xp_for_level(int(s["level"]))
	box.add_child(UiStyle.label("%s — уровень %d" % [str(Crew.info(id).get("name", id)), int(s["level"])], 10, UiStyle.TITLE))
	var bar := ProgressBar.new()
	bar.max_value = need
	bar.value = int(s["xp"])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(170, 5)
	box.add_child(bar)
	box.add_child(UiStyle.label("Опыт %d/%d · половина опыта героя" % [int(s["xp"]), need], 7, UiStyle.MUTED))
	var node := crew.node_for(id)
	var hp := "%d/%d" % [node.health, node.max_health] if node != null else str(st["max_health"])
	if node != null and node.is_down():
		hp += " — без сил"
	for line in [
		["Здоровье", hp], ["Урон", "×%.2f, +%d от оружия" % [float(st["damage_mult"]), int(st["damage_bonus"])]],
		["Крит", "%d%%" % roundi(float(st["crit"]) * 100.0)], ["Броня", str(st["armor"])],
		["Скорость атак", "%d%%" % roundi(100.0 / maxf(0.6, float(st["haste"])))],
	]:
		box.add_child(UiStyle.label("%s: %s" % line, 8, UiStyle.TEXT))
	box.add_child(UiStyle.section("Тактика"))
	var stances := HBoxContainer.new()
	stances.add_theme_constant_override("separation", 2)
	box.add_child(stances)
	for stance in Crew.STANCES:
		var button := Button.new()
		button.text = str(Crew.STANCES[stance])
		button.toggle_mode = true
		button.button_pressed = str(s.get("stance", "defend")) == stance
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", UiFont.px(8))
		UiStyle.small_toggle(button)
		var target: String = stance
		button.pressed.connect(func() -> void:
			crew.set_stance(id, target)
			populate(crew))
		stances.add_child(button)
	var hint := UiStyle.label({"defend": "Бьёт тех, с кем дерётся герой, и тех, кто нападает.", "attack": "Бьёт любого врага рядом.", "passive": "Не вступает в бой, только помогает."}.get(str(s.get("stance", "defend")), ""), 7, UiStyle.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(176, 0)
	box.add_child(hint)
	return box

func _gear_column(id: String) -> Control:
	var box := _column(196, "Снаряжение")
	var gear: Dictionary = crew.state(id)["gear"]
	var accepts: Array = Crew.info(id).get("accepts", [])
	var kinds := {"staff": "посох", "dagger": "кинжал", "bow": "лук", "spear": "копьё", "sword": "меч", "hammer": "молот"}
	var names: Array[String] = []
	for kind in accepts:
		names.append(str(kinds.get(kind, kind)))
	for slot in Crew.GEAR_SLOTS:
		var item_id := str(gear.get(slot, ""))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 3)
		box.add_child(line)
		var caption := UiStyle.label(str(Crew.SLOT_NAMES[slot]), 8, UiStyle.MUTED)
		caption.custom_minimum_size = Vector2(44, 0)
		line.add_child(caption)
		var button := Button.new()
		button.text = crew.game.player.get_item_name(item_id) if not item_id.is_empty() else "— пусто —"
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(146, 18)
		button.clip_text = true
		button.add_theme_font_size_override("font_size", UiFont.px(8))
		button.tooltip_text = "Клик — выбрать из сумки" + (" или снять" if not item_id.is_empty() else "")
		UiStyle.small_toggle(button)
		button.toggle_mode = true
		button.button_pressed = _slot_open == slot
		var target: String = slot
		button.pressed.connect(func() -> void:
			_slot_open = "" if _slot_open == target else target
			populate(crew))
		line.add_child(button)
		if _slot_open == slot:
			if not item_id.is_empty():
				box.add_child(_small_button("↩ Снять в сумку", func() -> void:
					crew.unequip(id, target)
					_slot_open = ""
					_refresh()))
			var options := crew.candidates(id, slot)
			if options.is_empty():
				box.add_child(UiStyle.label("  в сумке нет подходящего" + ((" (%s)" % ", ".join(names)) if slot == "weapon" else ""), 7, UiStyle.MUTED))
			for option in options.slice(0, 6):
				var item: String = option
				box.add_child(_small_button("  ＋ " + crew.game.player.get_item_name(item), func() -> void:
					crew.equip(id, item)
					_slot_open = ""
					_refresh()))
	var note := UiStyle.label("Оружие: %s. Доспех — броня или плащ. Оберег — амулет, кольцо, серьги." % ", ".join(names), 7, UiStyle.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(192, 0)
	box.add_child(note)
	return box

func _skills_column(id: String) -> Control:
	var s := crew.state(id)
	var box := _column(210, "Навыки · очков: %d" % int(s["points"]))
	var skills: Dictionary = Crew.info(id).get("skills", {})
	for skill_id in skills:
		var skill: Dictionary = skills[skill_id]
		var rank := crew.rank(id, str(skill_id))
		var reason := crew.can_learn(id, str(skill_id))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 3)
		box.add_child(line)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)
		text.add_child(UiStyle.label("%s  %d/%d%s" % [str(skill.get("name", skill_id)), rank, int(skill.get("max", 1)), "" if int(s["level"]) >= int(skill.get("level", 1)) else "  · ур. %d" % int(skill.get("level", 1))], 8, Color(0.7, 1.0, 0.7) if rank > 0 else UiStyle.TEXT))
		var description := UiStyle.label(str(skill.get("description", "")), 7, Color(0.75, 0.78, 0.85))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size = Vector2(176, 0)
		text.add_child(description)
		var plus := Button.new()
		plus.text = "+"
		plus.disabled = not reason.is_empty()
		plus.tooltip_text = "Изучить" if reason.is_empty() else reason
		plus.focus_mode = Control.FOCUS_NONE
		plus.custom_minimum_size = Vector2(18, 18)
		UiStyle.small_toggle(plus)
		var target: String = str(skill_id)
		plus.pressed.connect(func() -> void:
			crew.learn(id, target)
			_refresh())
		line.add_child(plus)
	return box

func _small_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(192, 16)
	button.clip_text = true
	button.add_theme_font_size_override("font_size", UiFont.px(8))
	UiStyle.small_toggle(button)
	button.pressed.connect(action)
	return button

func _refresh() -> void:
	populate(crew)
	changed.emit()
