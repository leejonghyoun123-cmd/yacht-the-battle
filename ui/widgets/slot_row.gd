extends Control
## 주사위 아래 동그란 인첸트 슬롯 줄 (5칸). 작은 크기 / 확대 크기 공용.
## 칸 상태: 인첸트 있음(등급 색 + 아이콘 글자) / 빈 칸 / 잠김(미개방)

signal slot_pressed(slot: int)

var dice: DiceInstance
var radius: float = UiConfig.SLOT_RADIUS
var selected_slot: int = -1
## 구매 대상 고르기 중: 빈 칸 강조
var highlight_empty: bool = false
## 이번 라운드에 굴려 인첸트가 고정된 주사위
var locked: bool = false
var show_names: bool = false
var tooltip: Node = null

var _hover: int = -1


func setup(p_dice: DiceInstance, p_radius: float, p_tooltip: Node) -> Control:
	dice = p_dice
	radius = p_radius
	tooltip = p_tooltip
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(_slot_step() * DiceInstance.MAX_SLOTS, radius * 2.0 + 4.0 + (16.0 if show_names else 0.0))
	mouse_exited.connect(func() -> void:
		_hover = -1
		if tooltip != null:
			tooltip.hide_tip())
	return self


func _slot_step() -> float:
	return radius * 2.0 + (UiConfig.SLOT_GAP if radius < 15.0 else 14.0)


func _slot_center(i: int) -> Vector2:
	var total: float = _slot_step() * DiceInstance.MAX_SLOTS
	var start: float = (size.x - total) * 0.5 + _slot_step() * 0.5
	return Vector2(start + _slot_step() * float(i), radius + 2.0)


func _slot_at(p: Vector2) -> int:
	for i: int in range(DiceInstance.MAX_SLOTS):
		if p.distance_to(_slot_center(i)) <= radius + 2.0:
			return i
	return -1


func _draw() -> void:
	if dice == null:
		return
	var font: Font = ThemeDB.fallback_font
	for i: int in range(DiceInstance.MAX_SLOTS):
		var c: Vector2 = _slot_center(i)
		if i >= dice.unlocked_slots:
			draw_circle(c, radius, UiConfig.COLOR_LOCKED)
			draw_arc(c, radius, 0.0, TAU, 20, Color(0, 0, 0, 0.5), 1.5)
			continue
		var inst: EnchantInstance = dice.slots[i]
		if inst == null:
			draw_circle(c, radius, Color(0.12, 0.13, 0.16, 0.85))
			var ring: Color = UiConfig.COLOR_TARGET if (highlight_empty and not locked) else Color(1, 1, 1, 0.45)
			draw_arc(c, radius, 0.0, TAU, 24, ring, 2.0 if highlight_empty else 1.2)
		else:
			var col: Color = UiConfig.rarity_color(int(inst.data.rarity))
			draw_circle(c, radius, col)
			var label: String = inst.data.get_icon_text()
			var fs: int = int(radius * (0.9 if label.length() <= 2 else 0.7))
			var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, c + Vector2(-w * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.08, 0.08, 0.1))
			if show_names:
				var name_fs: int = 11
				var nw: float = font.get_string_size(inst.get_display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, name_fs).x
				draw_string(font, c + Vector2(-nw * 0.5, radius + 14.0), inst.get_display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, name_fs, Color.WHITE)
		if locked:
			draw_circle(c, radius, Color(0, 0, 0, 0.35))
		if i == selected_slot:
			draw_arc(c, radius + 3.0, 0.0, TAU, 24, UiConfig.COLOR_SELECTED, 3.0)
		elif i == _hover:
			draw_arc(c, radius + 2.0, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 1.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h: int = _slot_at((event as InputEventMouseMotion).position)
		if h != _hover:
			_hover = h
			queue_redraw()
			if tooltip != null:
				if h >= 0:
					tooltip.show_text(_slot_tooltip(h))
				else:
					tooltip.hide_tip()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var s: int = _slot_at(mb.position)
			if s >= 0:
				slot_pressed.emit(s)
				accept_event()


func _slot_tooltip(i: int) -> String:
	if i >= dice.unlocked_slots:
		return "잠긴 슬롯\n조각칼·핸드드릴로 개방"
	var inst: EnchantInstance = dice.slots[i]
	var lock_note: String = "\n(이번 라운드에 굴린 주사위 — 고정)" if locked else ""
	if inst == null:
		return "빈 슬롯 %d%s" % [i + 1, lock_note]
	var rarity_names: Array[String] = ["일반", "고급", "희귀", "전설"]
	return "%s  [%s]\n%s\n판매가 %d원%s" % [
		inst.get_display_name(), rarity_names[int(inst.data.rarity)], inst.data.description,
		ShopCatalog.sell_value(ShopCatalog.enchant_price(inst.data)), lock_note]
