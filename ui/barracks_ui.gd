extends Control
## 연병장(준비) 화면 오버레이. 뒤쪽에는 BattleView가 내 연병장과 병력을 비춘다.
## 할 수 있는 것: 내 배치판 확인, 중첩칸 판매, 적 정찰 힌트 확인 → [주사위 테이블로]

signal roll_requested

var session: GameSession

var _top_label: Label
var _board_box: VBoxContainer
var _hint_slot: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layout: Dictionary = UiKit.overlay_layout(self)

	var top: PanelContainer = UiKit.panel()
	_top_label = UiKit.label("", 18)
	top.add_child(_top_label)
	(layout["top_left"] as Container).add_child(top)

	var left: PanelContainer = UiKit.panel()
	_board_box = VBoxContainer.new()
	left.add_child(_board_box)
	(layout["top_left"] as Container).add_child(left)

	_hint_slot = layout["top_right"]

	var go: Button = UiKit.button("주사위 테이블로 ▶", 20)
	go.custom_minimum_size = Vector2(260, 52)
	go.pressed.connect(func() -> void: roll_requested.emit())
	(layout["bottom_center"] as Container).add_child(go)


func refresh() -> void:
	if session == null or _board_box == null:
		return
	var p: PlayerState = session.player
	var streak_text: String = ""
	if session.streak.win_streak >= 2:
		streak_text = "   %d연승" % session.streak.win_streak
	elif session.streak.loss_streak >= 2:
		streak_text = "   %d연패" % session.streak.loss_streak
	_top_label.text = "연병장 · 라운드 %d / %d    골드 %s    체력 %d / %d%s" % [
		session.get_round(), LevelTable.FINAL_ROUND, NumberFormatter.format_num(p.gold), p.hp, p.max_hp, streak_text]

	UiKit.clear(_hint_slot)
	_hint_slot.add_child(UiKit.enemy_hint(session))

	UiKit.clear(_board_box)
	_board_box.add_child(UiKit.label("내 배치판 (중첩칸은 준비 단계에 판매 가능)", 14, UiKit.COLOR_ACCENT))
	_board_box.add_child(UiKit.board_grid(session.board, Callable(), Callable()))
	var sell_row: HBoxContainer = HBoxContainer.new()
	for row: int in range(BoardState.SIZE):
		var idx: int = BoardState.index_of(row, BoardState.STACK_COLUMN)
		var price: int = session.board.get_stack_sell_price(idx)
		if price <= 0:
			continue
		var cell: CellState = session.board.cells[idx]
		var row_name: String = ["후열", "중열", "전열"][row]
		var b: Button = UiKit.button("%s %s 판매 +%s원" % [row_name, UnitCatalog.get_unit(cell.unit_id).display_name, NumberFormatter.format_num(price)], 12)
		b.pressed.connect(func() -> void:
			session.sell_stack_cell(idx)
			refresh.call_deferred())
		sell_row.add_child(b)
	if sell_row.get_child_count() == 0:
		sell_row.add_child(UiKit.label("판매할 중첩칸 없음", 12, UiKit.COLOR_TEXT_DIM))
	_board_box.add_child(sell_row)
