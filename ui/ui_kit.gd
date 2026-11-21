class_name UiKit
extends RefCounted
## 프로토타입 UI 공용 위젯 (라벨·패널·버튼·배치판 격자·적 힌트)

const COLOR_PANEL: Color = Color(0.1, 0.11, 0.15, 0.88)
const COLOR_TEXT_DIM: Color = Color("9aa0b4")
const COLOR_ACCENT: Color = Color("f2c14e")
const COLOR_STACK: Color = Color("6b5a2a")
const COLOR_CONSUME: Color = Color("2c4766")
const TIER_NAMES: Array[String] = ["", "은색", "금색", "붉은색"]


static func label(text: String, font_size: int = 14, color: Color = Color.WHITE) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, font_size: int = 14) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	return b


static func panel(bg: Color = COLOR_PANEL, border: Color = Color.TRANSPARENT) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", style)
	return p


## 화면 전체를 덮는 여백 레이아웃. 반환: { "top_left", "top_right", "bottom_center" } 컨테이너.
## (앵커 + position 조합은 화면 밖으로 밀려나기 쉬워 컨테이너로 배치한다)
static func overlay_layout(parent: Control, margin: int = 10, top_extra: int = 0) -> Dictionary:
	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, margin)
	# 공통 상단 바 아래부터 배치
	m.add_theme_constant_override("margin_top", margin + top_extra)
	parent.add_child(m)
	var v: VBoxContainer = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(top)
	var top_left: VBoxContainer = VBoxContainer.new()
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left.add_theme_constant_override("separation", 8)
	top.add_child(top_left)
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var top_right: VBoxContainer = VBoxContainer.new()
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(top_right)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bottom)
	return { "top_left": top_left, "top_right": top_right, "bottom_center": bottom }


static func clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


## 칸 내용 요약 문자열 ("소드 300명\n×6 금색")
static func cell_text(cell: CellState) -> String:
	var kind: String = "중첩" if cell.is_stack else "소비"
	if cell.is_empty():
		return "[%s]\n(비어 있음)" % kind
	var data: UnitData = UnitCatalog.get_unit(cell.unit_id)
	var plan: Dictionary = BattleRules.get_spawn_plan(cell.count, data.is_giant)
	var extra: String = ""
	if data.is_giant:
		extra = "거인 %d명 합체" % plan["spawn"]
	elif plan["ratio"] > 1.0:
		var tier: int = BattleRules.get_tier(plan["ratio"])
		extra = "×%.1f %s" % [plan["ratio"], TIER_NAMES[tier - 1] if tier > 1 else "압축"]
	return "[%s] %s\n%s명%s" % [kind, data.display_name, NumberFormatter.format_num(cell.count), ("\n" + extra) if extra != "" else ""]


## 3x3 배치판 격자. 위쪽 = 후열, 아래쪽 = 전열(적 방향). 가운데 열 = 중첩칸.
## on_cell(cell_index)가 null이 아니면 칸을 누를 수 있다. cell_enabled(cell_index) -> bool로 활성 여부 결정.
static func board_grid(board: BoardState, on_cell: Callable, cell_enabled: Callable, cell_size: Vector2 = Vector2(118, 70)) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var head: HBoxContainer = HBoxContainer.new()
	for t: String in ["소비칸", "중첩칸", "소비칸"]:
		var l: Label = label(t, 12, COLOR_TEXT_DIM)
		l.custom_minimum_size = Vector2(cell_size.x, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(l)
	box.add_child(head)
	var grid: GridContainer = GridContainer.new()
	grid.columns = BoardState.SIZE
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for idx: int in range(BoardState.CELL_COUNT):
		var cell: CellState = board.cells[idx]
		var b: Button = button(cell_text(cell), 12)
		b.custom_minimum_size = cell_size
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = COLOR_STACK if cell.is_stack else COLOR_CONSUME
		style.set_corner_radius_all(6)
		style.set_content_margin_all(4)
		b.add_theme_stylebox_override("normal", style)
		var hover: StyleBoxFlat = style.duplicate()
		hover.bg_color = style.bg_color.lightened(0.2)
		b.add_theme_stylebox_override("hover", hover)
		var dis: StyleBoxFlat = style.duplicate()
		dis.bg_color = style.bg_color.darkened(0.35)
		b.add_theme_stylebox_override("disabled", dis)
		b.disabled = on_cell.is_null() or (cell_enabled.is_valid() and not bool(cell_enabled.call(idx)))
		if not on_cell.is_null():
			b.pressed.connect(on_cell.bind(idx))
		grid.add_child(b)
	box.add_child(label("▼ 전열 (적 방향)", 12, COLOR_TEXT_DIM))
	return box


## 솔로 적 정보 힌트 패널 (우측 상단용)
static func enemy_hint(session: GameSession) -> Control:
	var hint: Dictionary = session.get_enemy_hint()
	var p: PanelContainer = panel(Color(0.22, 0.1, 0.12, 0.9), Color("ff5e5e"))
	var box: VBoxContainer = VBoxContainer.new()
	p.add_child(box)
	box.add_child(label("적 정찰 (%dR)" % hint["round"], 15, Color("ff9a9a")))
	box.add_child(label("규모: 약 %s명" % NumberFormatter.format_num(hint["approx_total"]), 13))
	box.add_child(label("병과: " + " · ".join(hint["units"]), 13))
	var boss: Dictionary = hint["boss"]
	if not boss.is_empty():
		var b: Label = label("⚠ 보스 [%s]\n%s" % [boss["name"], boss["gimmick"]], 12, COLOR_ACCENT)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(230, 0)
		box.add_child(b)
	return p
