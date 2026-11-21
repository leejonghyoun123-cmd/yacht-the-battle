extends PanelContainer
## 얏츠판 기록지 (종이에 적는 느낌). 굴린 뒤 기록 가능한 칸은 노란색, 누르면 기록·확정.
## 기록된 칸은 잉크색 숫자로 남는다.

signal category_pressed(category: int)

const PAPER: Color = Color("f3ead2")
const PAPER_LINE: Color = Color("c9b98f")
const INK: Color = Color("2b3a67")
const HEADER: Color = Color("3b3530")
const AVAILABLE: Color = Color("f5d75a")
const AVAILABLE_ZERO: Color = Color("efe3a8")

var _rows: VBoxContainer
var _title: Label
var _sub: Label
var _total: Label
var _style: StyleBoxFlat


## 기록을 재촉할 때: 그림자 대신 금빛 테두리·후광
func set_glow(on: bool) -> void:
	if _style == null:
		return
	_style.shadow_color = Color(1.0, 0.82, 0.25, 0.85) if on else Color(0, 0, 0, 0.35)
	_style.shadow_size = 16 if on else 6
	_style.shadow_offset = Vector2.ZERO if on else Vector2(3, 4)
	_style.border_color = Color("f2c14e")
	_style.set_border_width_all(3 if on else 0)


func _ready() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	_style = style
	style.bg_color = PAPER
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(3, 4)
	add_theme_stylebox_override("panel", style)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	_title = _label("", 20, HEADER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_sub = _label("", 12, Color("6b5f4b"))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_sub)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	box.add_child(_rows)
	_total = _label("", 14, HEADER)
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_total)


func update_sheet(flow: RoundFlow, board: YachtBoard) -> void:
	if _rows == null:
		return
	_title.text = "기록지 · %dR" % flow.round_number
	_sub.text = "프레스티지 %d · 보상 ×%d · %d/%d칸" % [board.prestige_level, board.get_reward_multiplier(), board.recorded.size(), YachtBoard.Category.size()]
	for c: Node in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	_rows.add_child(_section("상단 (1의 자리 합)"))
	var preview: Dictionary = flow.get_yacht_preview()
	var can_record: bool = flow.phase == RoundFlow.Phase.ROLLING
	var total: int = 0
	for category: int in YachtBoard.Category.values():
		if category == YachtBoard.Category.CHOICE:
			_rows.add_child(_section("초이스 (1의 자리 전부의 합)"))
		elif category == YachtBoard.Category.FOUR_OF_A_KIND:
			_rows.add_child(_section("하단 (족보)"))
		var recorded: bool = board.is_recorded(category)
		if recorded:
			total += int(board.recorded[category])
		_rows.add_child(_row(category, recorded, int(board.recorded.get(category, 0)), preview, can_record))
	_total.text = "이번 사이클 합계  %s원" % NumberFormatter.format_num(total)


func _row(category: int, recorded: bool, recorded_gold: int, preview: Dictionary, can_record: bool) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var name_box: PanelContainer = _cell(Color(0, 0, 0, 0), 150)
	name_box.add_child(_label(YachtBoard.CATEGORY_NAMES[category], 14, HEADER))
	row.add_child(name_box)

	var value_text: String = ""
	var fill: Color = Color(0, 0, 0, 0)
	var ink: Color = INK
	var clickable: bool = false
	if recorded:
		value_text = NumberFormatter.format_num(recorded_gold)
	elif can_record and preview.has(category):
		var gold: int = preview[category]
		value_text = NumberFormatter.format_num(gold)
		fill = AVAILABLE if gold > 0 else AVAILABLE_ZERO
		ink = Color("5b4b1e") if gold > 0 else Color("9a8f6e")
		clickable = true
	var value_box: PanelContainer = _cell(fill, 80)
	var v: Label = _label(value_text, 15 if recorded else 14, ink)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_box.add_child(v)
	row.add_child(value_box)
	if clickable:
		value_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		name_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for target: Control in [value_box, name_box]:
			target.gui_input.connect(func(e: InputEvent) -> void:
				if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
					category_pressed.emit(category))
	return row


func _cell(fill: Color, width: int) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 27)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = PAPER_LINE
	sb.set_border_width_all(0)
	sb.border_width_bottom = 1
	sb.border_width_left = 1 if width < 120 else 0
	sb.content_margin_left = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	return p


func _section(text: String) -> Control:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = HEADER
	sb.content_margin_left = 6
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(_label(text, 12, PAPER))
	return p


func _label(text: String, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
