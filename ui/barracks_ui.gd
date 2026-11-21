extends Control
## 연병장 화면 (= 배치 화면). 뒤쪽 BattleView의 연병장 칸을 직접 클릭해 유닛을 배치한다 (별도 배치 화면 없음).
##   준비 중: 중첩칸(가운데 줄)을 누르면 판매 확인 → 판매
##   배치 중(얏츠판 기록 후): 주사위 선택 → 병과 선택 → 연병장 칸 클릭
##     다른 병과가 있는 칸이면 "기존 유닛 자동 판매" 확인 후 덮어쓰기
## (라운드·골드·체력·타이머는 공통 상단 바, 위치·크기는 UiConfig)

signal roll_requested
signal shop_requested
signal battle_requested

const DiceBar: GDScript = preload("res://ui/widgets/dice_bar.gd")

var session: GameSession
var tooltip: Node
## 연병장을 그리는 BattleView (칸 클릭·표시용)
var view: Node2D

var selected_summon: int = 0
var selected_unit: StringName = &"sword"

var _left_box: VBoxContainer
var _hint_slot: VBoxContainer
var _dice_bar: VBoxContainer
var _message: Label
var _roll_button: Button
var _confirm: ConfirmationDialog
var _pending_action: Callable = Callable()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layout: Dictionary = UiKit.overlay_layout(self, 10, UiConfig.TOP_BAR_HEIGHT)

	var left: PanelContainer = UiKit.panel()
	_left_box = VBoxContainer.new()
	_left_box.add_theme_constant_override("separation", 6)
	left.add_child(_left_box)
	(layout["top_left"] as Container).add_child(left)
	_message = UiKit.label("", 14, UiConfig.COLOR_ACCENT)
	(layout["top_left"] as Container).add_child(_message)

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
	var shop: Button = _nav_button("상점", 44)
	shop.pressed.connect(func() -> void: shop_requested.emit())
	buttons.add_child(shop)
	_roll_button = _nav_button("주사위 테이블로 ▶", 52)
	_roll_button.pressed.connect(func() -> void: roll_requested.emit())
	buttons.add_child(_roll_button)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "확인"
	_confirm.ok_button_text = "확인"
	_confirm.cancel_button_text = "취소"
	_confirm.confirmed.connect(func() -> void:
		if _pending_action.is_valid():
			_pending_action.call()
		_pending_action = Callable())
	add_child(_confirm)

	if view != null:
		view.connect("barracks_cell_clicked", _on_cell_clicked)
		view.connect("barracks_cell_hovered", _on_cell_hovered)
	session.board.board_changed.connect(_queue_refresh)
	session.changed.connect(_queue_refresh)
	session.deck.deck_changed.connect(func() -> void:
		if visible:
			_dice_bar.call("refresh"))


func _queue_refresh() -> void:
	if visible:
		refresh.call_deferred()


func refresh() -> void:
	if session == null or _left_box == null:
		return
	UiKit.clear(_hint_slot)
	_hint_slot.add_child(UiKit.enemy_hint(session))
	_dice_bar.call("refresh")
	var placing: bool = session.phase == GameSession.Phase.PLACEMENT
	_roll_button.visible = not placing
	if placing:
		_build_placement_panel()
	else:
		_build_prep_panel()
	_push_overlay()


# --- 왼쪽 패널 ---------------------------------------------------------------

func _build_prep_panel() -> void:
	UiKit.clear(_left_box)
	var streak_text: String = ""
	if session.streak.win_streak >= 2:
		streak_text = "  ·  %d연승 중" % session.streak.win_streak
	elif session.streak.loss_streak >= 2:
		streak_text = "  ·  %d연패 중" % session.streak.loss_streak
	_left_box.add_child(UiKit.label("연병장%s" % streak_text, 16, UiConfig.COLOR_ACCENT))
	var help: Label = UiKit.label(
		"· 주사위 테이블에서 굴리고 얏츠판을 기록하면\n  이 연병장 칸을 눌러 유닛을 배치합니다.\n· 가운데 줄 = 중첩칸(누적), 양옆 = 소비칸\n· 중첩칸을 누르면 판매할 수 있습니다.", 13, Color.WHITE)
	_left_box.add_child(help)


func _build_placement_panel() -> void:
	UiKit.clear(_left_box)
	if selected_summon < 0 or selected_summon >= session.summons.size() or session.summons[selected_summon]["placed"]:
		selected_summon = session.next_unplaced_index()
	_left_box.add_child(UiKit.label("배치: 주사위 → 병과 → 연병장 칸 클릭", 15, UiConfig.COLOR_ACCENT))
	for i: int in range(session.summons.size()):
		var s: Dictionary = session.summons[i]
		var text: String = "주사위%d: %s명" % [i + 1, NumberFormatter.format_num(s["value"])]
		if s["reason"] != "":
			text += " (%s명, %s)" % [NumberFormatter.format_num(s["base"]), s["reason"]]
		if s["placed"]:
			text += "  ✔ %s" % UnitCatalog.get_unit(s["unit_id"]).display_name
		var b: Button = UiKit.button(("▶ " if i == selected_summon else "   ") + text, 13)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = s["placed"]
		b.pressed.connect(func() -> void:
			selected_summon = i
			refresh.call_deferred())
		_left_box.add_child(b)
	var units: HBoxContainer = HBoxContainer.new()
	for id: StringName in UnitCatalog.ALL_IDS:
		var data: UnitData = UnitCatalog.get_unit(id)
		var ub: Button = UiKit.button(data.display_name, 14)
		ub.toggle_mode = true
		ub.button_pressed = id == selected_unit
		ub.add_theme_color_override("font_color", data.color)
		ub.pressed.connect(func() -> void:
			selected_unit = id
			refresh.call_deferred())
		if tooltip != null:
			tooltip.call("attach", ub, func() -> String: return _unit_tooltip(data))
		units.add_child(ub)
	_left_box.add_child(units)
	var row: HBoxContainer = HBoxContainer.new()
	var reset: Button = UiKit.button("배치 초기화", 14)
	reset.pressed.connect(func() -> void:
		session.reset_placement()
		selected_summon = 0
		refresh.call_deferred())
	row.add_child(reset)
	var start: Button = UiKit.button("전투 시작 ▶", 18)
	start.disabled = not session.all_placed()
	start.pressed.connect(func() -> void: battle_requested.emit())
	row.add_child(start)
	_left_box.add_child(row)


# --- 연병장 칸 (BattleView) ---------------------------------------------------

## 칸 이름표와 강조 상태를 뷰에 넘긴다
func _push_overlay() -> void:
	if view == null:
		return
	var labels: Array[String] = []
	var marks: Array[int] = []
	var placing: bool = session.phase == GameSession.Phase.PLACEMENT and selected_summon >= 0
	for cell: CellState in session.board.cells:
		labels.append(_cell_label(cell))
		var mark: int = 0
		if placing:
			if session.can_place(selected_summon, selected_unit, cell.index):
				mark = 1
			elif not cell.is_empty():
				mark = 2
		marks.append(mark)
	view.call("set_barracks_overlay", labels, marks)


func _cell_label(cell: CellState) -> String:
	if cell.is_empty():
		return ""
	var data: UnitData = UnitCatalog.get_unit(cell.unit_id)
	var plan: Dictionary = BattleRules.get_spawn_plan(cell.count, data.is_giant)
	var extra: String = ""
	if not data.is_giant and plan["ratio"] > 1.0:
		extra = " ×%.1f" % plan["ratio"]
	return "%s\n%s명%s" % [data.display_name, NumberFormatter.format_num(cell.count), extra]


func _on_cell_hovered(cell_index: int) -> void:
	if not visible or tooltip == null:
		return
	if cell_index < 0:
		tooltip.call("hide_tip")
		return
	var cell: CellState = session.board.cells[cell_index]
	var row_name: String = ["후열", "중열", "전열"][BoardState.row_of(cell_index)]
	var kind: String = "중첩칸 (전투 후에도 유지)" if cell.is_stack else "소비칸 (승리 시 생존자 판매)"
	var body: String = "비어 있음" if cell.is_empty() else UiKit.cell_text(cell).replace("\n", " ")
	var extra: String = ""
	if session.phase == GameSession.Phase.PLACEMENT:
		var info: Dictionary = session.get_replace_info(cell_index, selected_unit)
		if info["needed"]:
			extra = "\n⚠ 배치하면 기존 유닛이 자동 판매됩니다"
	elif cell.is_stack and not cell.is_empty():
		extra = "\n클릭: 판매 +%d원" % session.board.get_stack_sell_price(cell_index)
	tooltip.call("show_text", "%s · %s\n%s%s" % [row_name, kind, body, extra])
	_push_overlay()


func _on_cell_clicked(cell_index: int) -> void:
	if not visible:
		return
	if session.phase == GameSession.Phase.PLACEMENT:
		_try_place(cell_index)
	else:
		_try_sell(cell_index)


func _try_place(cell_index: int) -> void:
	if selected_summon < 0:
		_message.text = "모든 주사위를 배치했습니다. [전투 시작]을 누르세요."
		return
	if session.can_place(selected_summon, selected_unit, cell_index):
		session.place(selected_summon, selected_unit, cell_index)
		_message.text = ""
		refresh.call_deferred()
		return
	var info: Dictionary = session.get_replace_info(cell_index, selected_unit)
	if not info["needed"]:
		return
	var old_name: String = UnitCatalog.get_unit(info["old_unit"]).display_name
	var detail: String = ""
	if info["sell_count"] > 0:
		detail += "\n기존 %s %d명 판매 +%d원" % [old_name, info["sell_count"], info["sell_gold"]]
	if not (info["returned"] as Array).is_empty():
		detail += "\n이번 라운드에 놓은 주사위 %d개는 다시 배치할 수 있게 되돌아옵니다." % (info["returned"] as Array).size()
	var summon: int = selected_summon
	var unit: StringName = selected_unit
	_ask("이곳에 배치할시 해당칸의 기존유닛이 자동으로 판매됩니다.\n괜찮으십니까?" + detail, func() -> void:
		session.replace_and_place(summon, unit, cell_index)
		refresh.call_deferred())


func _try_sell(cell_index: int) -> void:
	var cell: CellState = session.board.cells[cell_index]
	if not cell.is_stack or cell.is_empty():
		return
	if not session.can_sell_stack():
		_message.text = "지금은 판매할 수 없습니다."
		return
	var price: int = session.board.get_stack_sell_price(cell_index)
	var unit_name: String = UnitCatalog.get_unit(cell.unit_id).display_name
	_ask("중첩칸의 %s %s명을 판매하시겠습니까?\n(+%d원)" % [unit_name, NumberFormatter.format_num(cell.count), price], func() -> void:
		session.sell_stack_cell(cell_index)
		refresh.call_deferred())


func _ask(text: String, action: Callable) -> void:
	_pending_action = action
	_confirm.dialog_text = text
	_confirm.popup_centered()


func _unit_tooltip(data: UnitData) -> String:
	return "%s\n체력 %d · 공격 %d · 공격 간격 %.2f초 · 사거리 %d%s" % [
		data.display_name, int(data.max_hp), int(data.attack), data.attack_interval, int(data.attack_range),
		"\n소환 인원을 1~3명 거인으로 합체" if data.is_giant else ""]


func _nav_button(text: String, height: int) -> Button:
	var b: Button = UiKit.button(text, 18)
	b.custom_minimum_size = Vector2(220, height)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b
