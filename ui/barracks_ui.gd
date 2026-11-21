extends Control
## 연병장(준비) 화면 오버레이. 뒤쪽에는 BattleView가 내 연병장과 병력을 비춘다.
## 할 수 있는 것: 내 배치판 확인, 중첩칸 판매, 적 정찰 힌트, 내 주사위·인첸트 정리 → [상점] / [주사위 테이블로]
## (라운드·골드·체력·타이머는 공통 상단 바에 표시)

signal roll_requested
signal shop_requested

const DiceBar: GDScript = preload("res://ui/widgets/dice_bar.gd")

var session: GameSession
var tooltip: Node

var _board_box: VBoxContainer
var _hint_slot: VBoxContainer
var _dice_bar: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layout: Dictionary = UiKit.overlay_layout(self, 10, UiConfig.TOP_BAR_HEIGHT)

	var left: PanelContainer = UiKit.panel()
	_board_box = VBoxContainer.new()
	left.add_child(_board_box)
	(layout["top_left"] as Container).add_child(left)

	_hint_slot = layout["top_right"]

	var bottom: Container = layout["bottom_center"]
	var bar_panel: PanelContainer = UiKit.panel(Color(UiConfig.COLOR_BAR_BG, 0.92))
	_dice_bar = DiceBar.new()
	_dice_bar.set("session", session)
	_dice_bar.set("tooltip", tooltip)
	bar_panel.add_child(_dice_bar)
	bottom.add_child(bar_panel)

	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_child(buttons)
	var shop: Button = UiKit.button("상점", 18)
	shop.custom_minimum_size = Vector2(220, 44)
	shop.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	shop.pressed.connect(func() -> void: shop_requested.emit())
	buttons.add_child(shop)
	var go: Button = UiKit.button("주사위 테이블로 ▶", 18)
	go.custom_minimum_size = Vector2(220, 52)
	go.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	go.pressed.connect(func() -> void: roll_requested.emit())
	buttons.add_child(go)

	session.deck.deck_changed.connect(func() -> void:
		if visible:
			_dice_bar.call("refresh"))


func refresh() -> void:
	if session == null or _board_box == null:
		return
	UiKit.clear(_hint_slot)
	_hint_slot.add_child(UiKit.enemy_hint(session))
	_dice_bar.call("refresh")

	UiKit.clear(_board_box)
	var streak_text: String = ""
	if session.streak.win_streak >= 2:
		streak_text = "  ·  %d연승 중" % session.streak.win_streak
	elif session.streak.loss_streak >= 2:
		streak_text = "  ·  %d연패 중" % session.streak.loss_streak
	_board_box.add_child(UiKit.label("내 배치판%s" % streak_text, 14, UiKit.COLOR_ACCENT))
	_board_box.add_child(UiKit.board_grid(session.board, Callable(), Callable()))
	var sell_row: HBoxContainer = HBoxContainer.new()
	var can_sell: bool = session.can_sell_stack()
	for row: int in range(BoardState.SIZE):
		var idx: int = BoardState.index_of(row, BoardState.STACK_COLUMN)
		var price: int = session.board.get_stack_sell_price(idx)
		if price <= 0:
			continue
		var cell: CellState = session.board.cells[idx]
		var row_name: String = ["후열", "중열", "전열"][row]
		var b: Button = UiKit.button("%s %s 판매 +%s원" % [row_name, UnitCatalog.get_unit(cell.unit_id).display_name, NumberFormatter.format_num(price)], 12)
		b.disabled = not can_sell
		b.pressed.connect(func() -> void:
			session.sell_stack_cell(idx)
			refresh.call_deferred())
		sell_row.add_child(b)
	if sell_row.get_child_count() == 0:
		sell_row.add_child(UiKit.label("판매할 중첩칸 없음", 12, UiKit.COLOR_TEXT_DIM))
	elif not can_sell:
		sell_row.add_child(UiKit.label("(배치 중에는 판매 불가)", 12, UiKit.COLOR_TEXT_DIM))
	_board_box.add_child(sell_row)
