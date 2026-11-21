extends Control
## 쟁반·대기줄 위의 주사위 1개: [⇅ 교체] 버튼(선택) / 주사위 / 소환값 / 곡선 인첸트 슬롯
## 위치는 부모(roll_ui)가 직접 정하고 움직인다 (굴림 연출).

signal pressed
signal swap_pressed
signal slot_pressed(slot: int)

const ItemIcon: GDScript = preload("res://ui/widgets/item_icon.gd")
const SlotRow: GDScript = preload("res://ui/widgets/slot_row.gd")

const SIZE_NORMAL: Vector2 = Vector2(100, 156)
## 쟁반 위 주사위의 인첸트 슬롯 반지름 (이웃 주사위 슬롯과 붙어 보이지 않게 작게)
const SLOT_RADIUS_TRAY: float = 7.0
const SIZE_SMALL: Vector2 = Vector2(96, 112)

var dice: DiceInstance
var _icon: Control
var _value: Label


## face: 주사위 면에 표시할 글자 / value_text: 아래 소환값 표시 / border: 강조색(투명 = 없음)
func setup(p_dice: DiceInstance, face: String, value_text: String, value_color: Color,
		show_swap: bool, swap_enabled: bool, locked: bool, border: Color,
		selected_slot: int, small: bool, tooltip: Node) -> Control:
	dice = p_dice
	var token_size: Vector2 = SIZE_SMALL if small else SIZE_NORMAL
	custom_minimum_size = token_size
	size = token_size
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 1)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	if show_swap:
		var swap: Button = Button.new()
		swap.text = "⇅ 교체"
		swap.add_theme_font_size_override("font_size", 12)
		swap.focus_mode = Control.FOCUS_NONE
		swap.disabled = not swap_enabled
		swap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		swap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		swap.pressed.connect(func() -> void: swap_pressed.emit())
		if tooltip != null:
			tooltip.call("attach", swap, func() -> String: return "가방(대기) 주사위 중 하나를 골라 이 주사위와 교체\n첫 굴림 전에만 가능")
		box.add_child(swap)

	var holder: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(2)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(3)
	holder.add_theme_stylebox_override("panel", sb)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_icon = ItemIcon.new()
	var icon_size: float = 46.0 if small else 64.0
	_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon.call("setup", "dice", face, Color("f4f1e8") if not locked else Color("d6d0c2"))
	holder.add_child(_icon)
	holder.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			pressed.emit())
	if tooltip != null:
		tooltip.call("attach", holder, func() -> String: return String(get_meta("tooltip_text", "")))
	box.add_child(holder)

	_value = Label.new()
	_value.text = value_text
	_value.add_theme_font_size_override("font_size", 13 if small else 16)
	_value.add_theme_color_override("font_color", value_color)
	_value.add_theme_color_override("font_outline_color", Color.BLACK)
	_value.add_theme_constant_override("outline_size", 4)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_value)

	var row: Control = SlotRow.new()
	row.set("arc_depth", 6.0 if small else 9.0)
	row.call("setup", dice, SLOT_RADIUS_TRAY - (1.0 if small else 0.0), tooltip)
	row.set("locked", locked)
	row.set("selected_slot", selected_slot)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.connect("slot_pressed", func(slot: int) -> void: slot_pressed.emit(slot))
	box.add_child(row)
	return self


## 굴림 연출 중 면 글자 바꾸기
func set_face(text: String) -> void:
	if _icon != null:
		_icon.set("text", text)
		_icon.queue_redraw()


func set_value_text(text: String) -> void:
	if _value != null:
		_value.text = text
