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
const ItemIcon: GDScript = preload("res://ui/widgets/item_icon.gd")

var session: GameSession
var tooltip: Node
## 연병장을 그리는 BattleView (칸 클릭·표시용)
var view: Node2D

## 배치는 [패에서 주사위 선택 → 병과 선택 → 칸 클릭]을 한 번씩. 배치하면 선택이 풀린다 (연속 자동 배치 없음)
var selected_summon: int = -1
var selected_unit: StringName = &""

var _left_box: VBoxContainer
var _hint_slot: VBoxContainer
var _dice_bar: VBoxContainer
var _bar_panel: PanelContainer
## 배치 단계: 아직 배치하지 않은 주사위 패 (배치하면 사라진다)
var _hand_panel: PanelContainer
var _hand_row: HBoxContainer
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
	_bar_panel = bar_panel
	_hand_panel = UiKit.panel(Color(0.1, 0.11, 0.15, 0.92), UiConfig.COLOR_ACCENT)
	var hand_box: VBoxContainer = VBoxContainer.new()
	_hand_panel.add_child(hand_box)
	hand_box.add_child(UiKit.label("내 패 — 배치할 주사위를 고르세요", 13, UiConfig.COLOR_ACCENT))
	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 10)
	hand_box.add_child(_hand_row)
	bottom.add_child(_hand_panel)
	bottom.move_child(_hand_panel, 0)
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
	# 배치 단계에는 덱 바 대신 '내 패'(아직 배치 안 한 주사위)를 보여 준다
	_bar_panel.visible = not placing
	_hand_panel.visible = placing
	if placing:
		if selected_summon >= 0 and (selected_summon >= session.summons.size() or session.summons[selected_summon]["placed"]):
			selected_summon = -1
		_build_placement_panel()
		_build_hand()
	else:
		selected_summon = -1
		selected_unit = &""
		_build_prep_panel()
	_push_overlay()


## 내 패: 배치하지 않았고 지금 선택하지 않은 주사위들 (선택한 주사위는 왼쪽에 크게 표시)
func _build_hand() -> void:
	UiKit.clear(_hand_row)
	var shown: int = 0
	for i: int in range(session.summons.size()):
		var s: Dictionary = session.summons[i]
		if s["placed"] or i == selected_summon:
			continue
		shown += 1
		var box: VBoxContainer = VBoxContainer.new()
		var holder: PanelContainer = UiKit.panel(Color(0, 0, 0, 0))
		holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var icon: Control = ItemIcon.new()
		icon.custom_minimum_size = Vector2(58, 58)
		icon.call("setup", "dice", NumberFormatter.format_num(s["value"]), Color("f4f1e8"))
		holder.add_child(icon)
		var index: int = i
		holder.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_select_summon(index))
		if tooltip != null:
			tooltip.call("attach", holder, func() -> String: return _summon_tooltip(index))
		box.add_child(holder)
		var cap: Label = UiKit.label("%s명" % NumberFormatter.format_num(s["value"]), 12, Color.WHITE)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(cap)
		_hand_row.add_child(box)
	if shown == 0:
		_hand_row.add_child(UiKit.label("남은 주사위 없음" if selected_summon < 0 else "(선택한 주사위만 남음)", 13, UiConfig.COLOR_DIM))


func _select_summon(index: int) -> void:
	selected_summon = index
	selected_unit = &""
	_message.text = ""
	refresh.call_deferred()


func _summon_tooltip(index: int) -> String:
	var s: Dictionary = session.summons[index]
	var dice: DiceInstance = session.deck.active[s["dice_index"]]
	var text: String = "주사위%d · %s\n소환 %s명" % [index + 1, dice.data.display_name, NumberFormatter.format_num(s["value"])]
	if s["reason"] != "":
		text += "\n(%s명 → %s)" % [NumberFormatter.format_num(s["base"]), s["reason"]]
	return text + "\n클릭: 선택"


# --- 왼쪽 패널 ---------------------------------------------------------------

func _build_prep_panel() -> void:
	UiKit.clear(_left_box)
	var streak_text: String = ""
	if session.streak.win_streak >= 2:
		streak_text = "  ·  %d연승 중" % session.streak.win_streak
	elif session.streak.loss_streak >= 2:
		streak_text = "  ·  %d연패 중" % session.streak.loss_streak
	_left_box.add_child(UiKit.label("유닛배치%s" % streak_text, 16, UiConfig.COLOR_ACCENT))
	var help: Label = UiKit.label(
		"· 주사위 테이블에서 굴리고 얏츠판을 기록하면\n  이 유닛배치 칸을 눌러 유닛을 배치합니다.\n· 가운데 줄 = 중첩칸(누적), 양옆 = 소비칸\n· 중첩칸을 누르면 판매할 수 있습니다.", 13, Color.WHITE)
	_left_box.add_child(help)


func _build_placement_panel() -> void:
	UiKit.clear(_left_box)
	_left_box.add_child(UiKit.label("배치: 패에서 주사위 → 병과 → 칸 클릭", 15, UiConfig.COLOR_ACCENT))
	if selected_summon < 0:
		var left_count: int = 0
		for s: Dictionary in session.summons:
			if not s["placed"]:
				left_count += 1
		_left_box.add_child(UiKit.label("아래 '내 패'에서 배치할 주사위를 고르세요.\n(남은 주사위 %d개)" % left_count if left_count > 0 else "모든 주사위를 배치했습니다.\n[전투 시작]을 누르세요.", 14, Color.WHITE))
		_left_box.add_child(_placement_buttons())
		return

	# 선택한 주사위를 크게 보여 준다
	var s: Dictionary = session.summons[selected_summon]
	var dice: DiceInstance = session.deck.active[s["dice_index"]]
	var big_row: HBoxContainer = HBoxContainer.new()
	big_row.add_theme_constant_override("separation", 12)
	var big: Control = ItemIcon.new()
	big.custom_minimum_size = Vector2(96, 96)
	big.call("setup", "dice", NumberFormatter.format_num(s["value"]), Color("fff6d8"))
	big.pivot_offset = Vector2(48, 48)
	big_row.add_child(big)
	var info: VBoxContainer = VBoxContainer.new()
	info.add_child(UiKit.label("선택한 주사위", 12, UiConfig.COLOR_DIM))
	info.add_child(UiKit.label("%s명 소환" % NumberFormatter.format_num(s["value"]), 22, Color("ffe08a")))
	info.add_child(UiKit.label(dice.data.display_name, 12, UiConfig.COLOR_DIM))
	if s["reason"] != "":
		var reason: Label = UiKit.label("%s명 → %s" % [NumberFormatter.format_num(s["base"]), s["reason"]], 11, Color("ff9a9a"))
		info.add_child(reason)
	big_row.add_child(info)
	_left_box.add_child(big_row)
	# 패에서 왼쪽으로 옮겨 온 느낌: 살짝 커지며 나타남
	big.scale = Vector2(0.6, 0.6)
	big.create_tween().tween_property(big, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_left_box.add_child(UiKit.label("이 주사위로 배치할 병과" if selected_unit == &"" else "병과 선택됨 → 유닛배치 칸을 클릭하세요", 13, UiConfig.COLOR_ACCENT))
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
	var cancel: Button = UiKit.button("선택 취소 (패로 되돌리기)", 12)
	cancel.pressed.connect(func() -> void:
		selected_summon = -1
		selected_unit = &""
		refresh.call_deferred())
	_left_box.add_child(cancel)
	_left_box.add_child(_placement_buttons())


func _placement_buttons() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	var reset: Button = UiKit.button("배치 초기화", 14)
	reset.pressed.connect(func() -> void:
		session.reset_placement()
		selected_summon = -1
		selected_unit = &""
		refresh.call_deferred())
	row.add_child(reset)
	var start: Button = UiKit.button("전투 시작 ▶", 18)
	start.disabled = not session.all_placed()
	start.pressed.connect(func() -> void: battle_requested.emit())
	row.add_child(start)
	return row


# --- 연병장 칸 (BattleView) ---------------------------------------------------

## 칸 이름표와 강조 상태를 뷰에 넘긴다
func _push_overlay() -> void:
	if view == null:
		return
	var labels: Array[String] = []
	var marks: Array[int] = []
	# 주사위와 병과를 둘 다 골라야 칸을 강조한다
	var placing: bool = session.phase == GameSession.Phase.PLACEMENT and selected_summon >= 0 and selected_unit != &""
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
	if session.phase == GameSession.Phase.PLACEMENT and selected_unit != &"":
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
		_message.text = "먼저 아래 '내 패'에서 주사위를 고르세요." if session.next_unplaced_index() >= 0 else "모든 주사위를 배치했습니다. [전투 시작]을 누르세요."
		return
	if selected_unit == &"":
		_message.text = "이 주사위로 배치할 병과를 먼저 고르세요."
		return
	if session.can_place(selected_summon, selected_unit, cell_index):
		session.place(selected_summon, selected_unit, cell_index)
		# 한 번 배치하면 선택이 풀린다 (다음 주사위를 다시 골라야 함)
		selected_summon = -1
		selected_unit = &""
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
		if session.replace_and_place(summon, unit, cell_index):
			selected_summon = -1
			selected_unit = &""
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
