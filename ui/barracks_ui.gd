extends Control
## 유닛배치 화면 (코드상 barracks). 뒤쪽 BattleView의 유닛배치 칸을 직접 클릭해 배치한다. 배치 예시 이미지 기준:
##   위 가운데: [전투 시작 ▶] (준비 중에는 [주사위 테이블로 ▶])     위 오른쪽: [상점] + 적 정찰
##   왼쪽 가운데: 선택한 주사위를 크게 + [배치 초기화]
##   아래 가운데: 병과 선택 → 내 패(아직 배치 안 한 주사위)  — 마우스 동선을 아래쪽에 모은다
## 연출: 패에서 주사위를 고르면 왼쪽으로 미끄러지며 커지고, 칸에 놓으면 작아지며 칸으로 날아가 팡 터지며 유닛으로 흩어진다.
## 준비 중(배치 전): 중첩칸 클릭 → 판매 확인. 배치 중: 다른 병과 칸이면 "기존 유닛 자동 판매" 확인 후 덮어쓰기.

signal roll_requested
signal shop_requested
signal battle_requested

const DiceBar: GDScript = preload("res://ui/widgets/dice_bar.gd")
const ItemIcon: GDScript = preload("res://ui/widgets/item_icon.gd")

const SELECT_SLIDE_TIME: float = 0.28
const PLACE_FLY_TIME: float = 0.32
const BIG_DIE_SIZE: Vector2 = Vector2(130, 130)

var session: GameSession
var tooltip: Node
## 유닛배치장을 그리는 BattleView (칸 클릭·표시·소환 연출)
var view: Node2D

## 배치는 [패에서 주사위 선택 → 병과 선택 → 칸 클릭]을 한 번씩. 배치하면 선택이 풀린다.
var selected_summon: int = -1
var selected_unit: StringName = &""

var _action_button: Button
var _hint_slot: VBoxContainer
var _left_box: VBoxContainer
var _reset_button: Button
var _message: Label
var _units_box: VBoxContainer
var _units_row: HBoxContainer
var _hand_panel: PanelContainer
var _hand_row: HBoxContainer
var _bar_panel: PanelContainer
var _dice_bar: VBoxContainer
var _big_icon: Control = null
var _hand_icons: Dictionary = {}
var _animating: bool = false
var _confirm: ConfirmationDialog
var _pending_action: Callable = Callable()
## 타로·아이템 패널 (오른쪽)
var _gear_box: VBoxContainer
## 칸을 지정해야 하는 타로를 고른 상태
var _tarot_pending: TarotCardData = null
## 두 칸을 잇는 타로(더 러버)의 첫 번째 칸
var _tarot_first_cell: int = -1
var _choice_popup: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.add_theme_constant_override("margin_top", UiConfig.TOP_BAR_HEIGHT + 8)
	add_child(margin)
	var v: VBoxContainer = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)

	# 위: 가운데 행동 버튼 / 오른쪽 상점 + 적 정찰
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	top.add_child(_expander())
	_action_button = _big_button("전투 시작 ▶", 20, Vector2(200, 46))
	_action_button.pressed.connect(_on_action_pressed)
	top.add_child(_action_button)
	top.add_child(_expander())
	var right: HBoxContainer = HBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(right)
	var shop: Button = _big_button("상점", 18, Vector2(170, 46))
	shop.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	shop.pressed.connect(func() -> void: shop_requested.emit())
	right.add_child(shop)
	_hint_slot = VBoxContainer.new()
	_hint_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_hint_slot)

	# 가운데: 왼쪽에 선택한 주사위
	var middle: HBoxContainer = HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(middle)
	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(left_col)
	var left_panel: PanelContainer = UiKit.panel()
	left_panel.custom_minimum_size = Vector2(250, 0)
	_left_box = VBoxContainer.new()
	_left_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_left_box.add_theme_constant_override("separation", 6)
	left_panel.add_child(_left_box)
	left_col.add_child(left_panel)
	_reset_button = UiKit.button("배치 초기화", 15)
	_reset_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reset_button.pressed.connect(func() -> void:
		session.reset_placement()
		selected_summon = -1
		selected_unit = &""
		refresh.call_deferred())
	left_col.add_child(_reset_button)
	_message = UiKit.label("", 14, UiConfig.COLOR_ACCENT)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(250, 0)
	left_col.add_child(_message)
	middle.add_child(_expander())
	var gear_panel: PanelContainer = UiKit.panel(Color(0.1, 0.11, 0.15, 0.9))
	gear_panel.custom_minimum_size = Vector2(230, 0)
	gear_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gear_box = VBoxContainer.new()
	_gear_box.add_theme_constant_override("separation", 6)
	gear_panel.add_child(_gear_box)
	middle.add_child(gear_panel)

	# 아래: 병과 선택 → 내 패 (배치 중) / 내 주사위 바 (준비 중)
	var bottom: VBoxContainer = VBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_theme_constant_override("separation", 6)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bottom)
	_units_box = VBoxContainer.new()
	_units_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var units_title: Label = UiKit.label("이 주사위로 배치할 병과", 16, UiConfig.COLOR_ACCENT)
	units_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_units_box.add_child(units_title)
	_units_row = HBoxContainer.new()
	_units_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_units_row.add_theme_constant_override("separation", 6)
	_units_box.add_child(_units_row)
	bottom.add_child(_units_box)
	_hand_panel = UiKit.panel(Color(0.1, 0.11, 0.15, 0.92), UiConfig.COLOR_ACCENT)
	var hand_box: VBoxContainer = VBoxContainer.new()
	_hand_panel.add_child(hand_box)
	hand_box.add_child(UiKit.label("내 패 — 배치할 주사위를 고르세요", 13, UiConfig.COLOR_ACCENT))
	_hand_row = HBoxContainer.new()
	_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_row.add_theme_constant_override("separation", 14)
	hand_box.add_child(_hand_row)
	bottom.add_child(_hand_panel)
	_bar_panel = UiKit.panel(Color(UiConfig.COLOR_BAR_BG, 0.92))
	_dice_bar = DiceBar.new()
	_dice_bar.set("session", session)
	_dice_bar.set("tooltip", tooltip)
	_bar_panel.add_child(_dice_bar)
	bottom.add_child(_bar_panel)

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
	if visible and not _animating:
		refresh.call_deferred()


# =========================================================================
# 갱신
# =========================================================================

func refresh() -> void:
	if session == null or _left_box == null:
		return
	UiKit.clear(_hint_slot)
	_hint_slot.add_child(UiKit.enemy_hint(session))
	var placing: bool = session.phase == GameSession.Phase.PLACEMENT
	if placing:
		if selected_summon >= 0 and (selected_summon >= session.summons.size() or session.summons[selected_summon]["placed"]):
			selected_summon = -1
	else:
		selected_summon = -1
		selected_unit = &""
	_action_button.text = "전투 시작 ▶" if placing else "주사위 테이블로 ▶"
	_action_button.disabled = placing and not session.all_placed()
	_reset_button.visible = placing
	_hand_panel.visible = placing
	_bar_panel.visible = not placing
	_units_box.visible = placing and selected_summon >= 0
	if placing:
		_build_selected_panel()
		_build_units()
		_build_hand()
	else:
		_build_prep_panel()
		_dice_bar.call("refresh")
	_build_gear()
	# 확정·정산 때 생긴 알림 (성질·아이템 효과)
	if not session.messages.is_empty():
		_message.text = "\n".join(session.messages)
		session.messages.clear()
	_push_overlay()


func _on_action_pressed() -> void:
	if session.phase == GameSession.Phase.PLACEMENT:
		battle_requested.emit()
	else:
		roll_requested.emit()


func _build_prep_panel() -> void:
	UiKit.clear(_left_box)
	_big_icon = null
	var streak_text: String = ""
	if session.streak.win_streak >= 2:
		streak_text = "  ·  %d연승 중" % session.streak.win_streak
	elif session.streak.loss_streak >= 2:
		streak_text = "  ·  %d연패 중" % session.streak.loss_streak
	_left_box.add_child(UiKit.label("유닛배치%s" % streak_text, 17, UiConfig.COLOR_ACCENT))
	_left_box.add_child(UiKit.label(
		"· 주사위 테이블에서 굴리고 기록하면\n  이 칸에 유닛을 배치합니다.\n· 가운데 줄 = 중첩칸(누적)\n  양옆 = 소비칸\n· 중첩칸을 누르면 판매할 수 있습니다.", 13, Color.WHITE))


## 왼쪽: 선택한 주사위를 크게
func _build_selected_panel() -> void:
	UiKit.clear(_left_box)
	_big_icon = null
	var title: Label = UiKit.label("배치: 패에서 주사위 → 병과 → 칸 클릭", 14, UiConfig.COLOR_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_box.add_child(title)
	if selected_summon < 0:
		var left_count: int = 0
		for s: Dictionary in session.summons:
			if not s["placed"]:
				left_count += 1
		var hint: Label = UiKit.label(("아래 '내 패'에서\n배치할 주사위를 고르세요.\n(남은 주사위 %d개)" % left_count) if left_count > 0 else "모든 주사위를 배치했습니다.\n[전투 시작]을 누르세요.", 15, Color.WHITE)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_left_box.add_child(hint)
		return
	var s: Dictionary = session.summons[selected_summon]
	var dice: DiceInstance = session.get_summon_dice(selected_summon)
	_big_icon = ItemIcon.new()
	_big_icon.custom_minimum_size = BIG_DIE_SIZE
	_big_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_setup_summon_icon(_big_icon, selected_summon, Color("fff6d8"))
	_left_box.add_child(_big_icon)
	var amount_text: String = "%s명 소환" % NumberFormatter.format_num(s["value"])
	var sel_data: UnitData = UnitCatalog.get_unit(selected_unit) if selected_unit != &"" else null
	if sel_data != null and sel_data.is_unique:
		amount_text = "%s 1명 (누적 +1)" % sel_data.display_name
	var die_text: String = String(s.get("bonus_name", "추가 소환")) if dice == null else dice.data.display_name if dice.trait_data == null else "%s %s · 눈금 %s" % [dice.trait_data.display_name, dice.get_short_name(), dice.face_label(int(s["raw"]))]
	for line: Array in [["선택한 주사위", 12, UiConfig.COLOR_DIM], [amount_text, 22, Color("ffe08a")], [die_text, 12, UiConfig.COLOR_DIM]]:
		var l: Label = UiKit.label(line[0], line[1], line[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_left_box.add_child(l)
	if s["reason"] != "":
		var reason: Label = UiKit.label("%s명 → %s" % [NumberFormatter.format_num(s["base"]), s["reason"]], 11, Color("ff9a9a"))
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_left_box.add_child(reason)
	var cancel: Button = UiKit.button("선택 취소 (패로 되돌리기)", 12)
	cancel.pressed.connect(func() -> void:
		selected_summon = -1
		selected_unit = &""
		refresh.call_deferred())
	_left_box.add_child(cancel)


## 아래: 병과 선택 (일반 주사위는 거인·킹 불가 — 포커카드 전용)
func _build_units() -> void:
	UiKit.clear(_units_row)
	for id: StringName in UnitCatalog.ALL_IDS:
		if not session.can_use_unit(selected_summon, id):
			continue
		var data: UnitData = UnitCatalog.get_unit(id)
		var ub: Button = UiKit.button(data.display_name, 20)
		ub.toggle_mode = true
		ub.button_pressed = id == selected_unit
		ub.custom_minimum_size = Vector2(76, 44)
		ub.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ub.add_theme_color_override("font_color", data.color)
		ub.add_theme_color_override("font_pressed_color", Color.WHITE)
		ub.pressed.connect(func() -> void:
			selected_unit = id
			_message.text = "병과 선택됨 → 유닛배치 칸을 클릭하세요"
			refresh.call_deferred())
		if tooltip != null:
			tooltip.call("attach", ub, func() -> String: return _unit_tooltip(data))
		_units_row.add_child(ub)


## 내 패: 배치하지 않았고 지금 선택하지 않은 주사위
func _build_hand() -> void:
	UiKit.clear(_hand_row)
	_hand_icons.clear()
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
		icon.custom_minimum_size = Vector2(60, 60)
		_setup_summon_icon(icon, i, Color("f4f1e8"))
		holder.add_child(icon)
		var index: int = i
		holder.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_select_summon(index))
		if tooltip != null:
			tooltip.call("attach", holder, func() -> String: return _summon_tooltip(index))
		box.add_child(holder)
		var cap: Label = UiKit.label("%s명" % NumberFormatter.format_num(s["value"]), 13, Color.WHITE)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(cap)
		_hand_row.add_child(box)
		_hand_icons[i] = icon
	if shown == 0:
		_hand_row.add_child(UiKit.label("남은 주사위 없음" if selected_summon < 0 else "(선택한 주사위만 남음)", 13, UiConfig.COLOR_DIM))


# =========================================================================
# 연출: 패 → 왼쪽(커짐) / 왼쪽 → 칸(작아지며 날아가 팡)
# =========================================================================

func _select_summon(index: int) -> void:
	if _animating:
		return
	var from_rect: Rect2 = Rect2()
	if _hand_icons.has(index):
		from_rect = (_hand_icons[index] as Control).get_global_rect()
	selected_summon = index
	selected_unit = &""
	_message.text = ""
	refresh()
	if from_rect.size.x <= 0.0:
		return
	# 레이아웃이 잡힌 뒤 큰 주사위 자리로 미끄러지며 커진다
	await get_tree().process_frame
	await get_tree().process_frame
	if _big_icon == null:
		return
	var to_rect: Rect2 = _big_icon.get_global_rect()
	var value: int = session.summons[index]["value"]
	var ghost: Control = _ghost(NumberFormatter.format_num(value), from_rect)
	_big_icon.modulate.a = 0.0
	var big: Control = _big_icon
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(ghost, "position", to_rect.position - global_position, SELECT_SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "size", to_rect.size, SELECT_SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		ghost.queue_free()
		if is_instance_valid(big):
			big.modulate.a = 1.0)


## 큰 주사위가 작아지며 칸으로 날아간 뒤 실제 배치 → 칸에서 팡 터지며 유닛으로 흩어짐
func _fly_and_place(summon: int, unit: StringName, cell_index: int, replace: bool) -> void:
	if _big_icon == null or view == null:
		_do_place(summon, unit, cell_index, replace)
		return
	_animating = true
	var from_rect: Rect2 = _big_icon.get_global_rect()
	var target: Vector2 = view.call("cell_screen_position", cell_index)
	var ghost: Control = _ghost(NumberFormatter.format_num(session.summons[summon]["value"]), from_rect)
	_big_icon.modulate.a = 0.0
	var end_size: Vector2 = Vector2(26, 26)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(ghost, "position", target - global_position - end_size * 0.5, PLACE_FLY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ghost, "size", end_size, PLACE_FLY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		ghost.queue_free()
		_animating = false
		_do_place(summon, unit, cell_index, replace))


func _do_place(summon: int, unit: StringName, cell_index: int, replace: bool) -> void:
	var ok: bool = session.replace_and_place(summon, unit, cell_index) if replace else session.place(summon, unit, cell_index)
	if ok:
		if view != null:
			view.call("play_cell_spawn", cell_index)
		selected_summon = -1
		selected_unit = &""
		_message.text = ""
	refresh.call_deferred()


func _ghost(text: String, rect: Rect2) -> Control:
	var g: Control = ItemIcon.new()
	g.call("setup", "dice", text, Color("fff6d8"))
	g.position = rect.position - global_position
	g.size = rect.size
	g.z_index = 20
	add_child(g)
	return g


# =========================================================================
# 유닛배치 칸 (BattleView)
# =========================================================================

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
	var tarots: Array = session.inventory.cell_tarots.get(cell.index, [])
	var tarot_line: String = ("\n타로 %d" % tarots.size()) if not tarots.is_empty() else ""
	if cell.is_empty():
		return tarot_line.strip_edges()
	var data: UnitData = UnitCatalog.get_unit(cell.unit_id)
	var plan: Dictionary = BattleRules.get_spawn_plan(cell.get_total(), data.is_giant, data.is_unique)
	var extra: String = ""
	if not data.is_giant and plan["ratio"] > 1.0:
		extra = " ×%.1f" % plan["ratio"]
	return "%s\n%s명%s%s" % [data.display_name, NumberFormatter.format_num(cell.get_total()), extra, tarot_line]


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
	for m: StatModifier in cell.modifiers:
		body += "\n· " + m.display_name
	for card: TarotCardData in session.inventory.cell_tarots.get(cell_index, []):
		body += "\n✧ 타로 %s (칸 자리 영구)" % card.display_name
	if cell.temp_count > 0:
		body += "\n· 과부하 %s명 (이번 라운드 한정)" % NumberFormatter.format_num(cell.temp_count)
	if _tarot_pending != null:
		body += "\n▶ 클릭: %s 부여" % _tarot_pending.display_name
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
	if not visible or _animating:
		return
	if _tarot_pending != null:
		var card: TarotCardData = _tarot_pending
		if card.cells_required >= 2 and _tarot_first_cell < 0:
			_tarot_first_cell = cell_index
			_message.text = "[%s] 연결할 두 번째 칸을 클릭하세요" % card.display_name
			return
		_tarot_pending = null
		var first: int = _tarot_first_cell
		_tarot_first_cell = -1
		var reason: String = session.use_tarot(card, first, cell_index) if card.cells_required >= 2 else session.use_tarot(card, cell_index)
		_message.text = reason if reason != "" else "%s → %s 칸에 영구 부여!" % [card.display_name, ["후열", "중열", "전열"][BoardState.row_of(cell_index)]]
		if reason == "" and view != null:
			view.call("play_cell_spawn", cell_index)
		refresh.call_deferred()
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
	var summon: int = selected_summon
	var unit: StringName = selected_unit
	if session.can_place(summon, unit, cell_index):
		_fly_and_place(summon, unit, cell_index, false)
		return
	var info: Dictionary = session.get_replace_info(cell_index, unit)
	if not info["needed"]:
		return
	var old_name: String = UnitCatalog.get_unit(info["old_unit"]).display_name
	var detail: String = ""
	if info["sell_count"] > 0:
		detail += "\n기존 %s %d명 판매 +%d원" % [old_name, info["sell_count"], info["sell_gold"]]
	if not (info["returned"] as Array).is_empty():
		detail += "\n이번 라운드에 놓은 주사위 %d개는 다시 배치할 수 있게 되돌아옵니다." % (info["returned"] as Array).size()
	_ask("이곳에 배치할시 해당칸의 기존유닛이 자동으로 판매됩니다.\n괜찮으십니까?" + detail, func() -> void:
		_fly_and_place(summon, unit, cell_index, true))


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


func _summon_tooltip(index: int) -> String:
	var s: Dictionary = session.summons[index]
	var dice: DiceInstance = session.get_summon_dice(index)
	var die_name: String = String(s.get("bonus_name", "추가 소환")) if dice == null else dice.data.display_name
	if dice != null and dice.trait_data != null:
		die_name = "%s (%s)" % [dice.trait_data.display_name, dice.face_label(int(s["raw"]))]
	var text: String = "주사위%d · %s\n소환 %s명" % [index + 1, die_name, NumberFormatter.format_num(s["value"])]
	for m: StatModifier in s.get("mods", []):
		text += "\n· " + m.display_name
	if bool(s.get("temporary", false)):
		text += "\n· 과부하: 이번 라운드 한정"
	var unlocks: Array = s.get("unlocks", [])
	for u: StringName in unlocks:
		text += "\n★ %s 배치 가능" % UnitCatalog.get_unit(u).display_name
	if s["reason"] != "":
		text += "\n(%s명 → %s)" % [NumberFormatter.format_num(s["base"]), s["reason"]]
	return text + "\n클릭: 선택"


func _unit_tooltip(data: UnitData) -> String:
	var text: String = "%s\n체력 %d · 공격 %d · 공격 간격 %.2f초 · 사거리 %d" % [
		data.display_name, int(data.max_hp), int(data.attack), data.attack_interval, int(data.attack_range)]
	if data.is_unique:
		text += "\n왕의 장판: 범위 안 아군 공격력 ×%.1f, 받는 피해 ×%.1f\n킹이 받는 피해는 장판 안 아군이 나눠 받는다\n판에 한 칸만 (K를 같은 칸에 쌓으면 특수능력)" % [data.king_attack_mult, data.king_damage_taken_mult]
	var thresholds: Array[int] = [data.branch_thresholds.x, data.branch_thresholds.y]
	var branches: Array[UnitBranch] = [data.branch_1, data.branch_2]
	for i: int in range(2):
		if branches[i] != null:
			text += "\n[%d명 중첩] %s — %s" % [thresholds[i], branches[i].display_name, branches[i].description]
	return text


func _expander() -> Control:
	var c: Control = Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _big_button(text: String, font_size: int, min_size: Vector2) -> Button:
	var b: Button = UiKit.button(text, font_size)
	b.custom_minimum_size = min_size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## 소환 주사위 아이콘: 포커카드는 카드(눈금 A~K), 2면은 동전, 그 외는 소환 인원 숫자
func _setup_summon_icon(icon: Control, index: int, base: Color) -> void:
	var s: Dictionary = session.summons[index]
	var dice: DiceInstance = session.get_summon_dice(index)
	var value_text: String = NumberFormatter.format_num(s["value"])
	if dice == null:
		icon.call("setup", "dice", value_text, Color("d9f2ff"))
	elif dice.trait_data is PokerTrait:
		icon.call("setup_dice", dice, dice.face_label(int(s["raw"])), base)
	else:
		icon.call("setup_dice", dice, value_text, base)


# =========================================================================
# 타로카드 · 유저 아이템 (오른쪽 패널)
# =========================================================================

func _build_gear() -> void:
	UiKit.clear(_gear_box)
	var inv: Inventory = session.inventory
	_gear_box.add_child(UiKit.label("타로카드 (%d/%d)" % [inv.tarot_hand.size(), Inventory.MAX_TAROT_HAND], 15, UiConfig.COLOR_ACCENT))
	var hand: HBoxContainer = HBoxContainer.new()
	hand.add_theme_constant_override("separation", 4)
	_gear_box.add_child(hand)
	if inv.tarot_hand.is_empty():
		hand.add_child(UiKit.label("없음 — 상점에서 구매", 12, UiConfig.COLOR_DIM))
	for card: TarotCardData in inv.tarot_hand:
		hand.add_child(_tarot_icon(card, card == _tarot_pending, func() -> void: _on_tarot_pressed(card)))
	if not inv.tarot_reserved.is_empty():
		_gear_box.add_child(UiKit.label("전투 예약 (%d/%d) — 눌러서 취소" % [inv.tarot_reserved.size(), Inventory.MAX_RESERVED], 12, Color("c9b6ff")))
		var res: HBoxContainer = HBoxContainer.new()
		_gear_box.add_child(res)
		for card: TarotCardData in inv.tarot_reserved:
			res.add_child(_tarot_icon(card, false, func() -> void:
				if session.unreserve_tarot(card):
					_message.text = "%s 예약을 취소했습니다" % card.display_name
				refresh.call_deferred()))
	var installed: PackedStringArray = []
	if inv.towers > 0:
		installed.append("더 타워 ×%d" % inv.towers)
	if session.player.justice_shield_max > 0:
		installed.append("저스티스 실드 %d/%d" % [session.player.justice_shield, session.player.justice_shield_max])
	if not installed.is_empty():
		_gear_box.add_child(UiKit.label("설치: " + ", ".join(installed), 12, Color("c9b6ff")))

	_gear_box.add_child(UiKit.label("아이템 (%d/%d)" % [inv.items.size(), Inventory.MAX_ITEMS], 15, UiConfig.COLOR_ACCENT))
	if inv.items.is_empty():
		_gear_box.add_child(UiKit.label("없음 — 상점에서 구매", 12, UiConfig.COLOR_DIM))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	_gear_box.add_child(grid)
	for it: ItemInstance in inv.items:
		var box: VBoxContainer = VBoxContainer.new()
		var icon: Control = ItemIcon.new()
		icon.custom_minimum_size = Vector2(46, 46)
		icon.call("setup", "item", it.data.icon_text, UiConfig.rarity_color(int(it.data.rank)))
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		if tooltip != null:
			tooltip.call("attach", icon, func() -> String:
				var st: String = it.data.get_state_text(it)
				return "%s\n%s%s" % [it.get_label(), it.data.description, ("\n" + st) if st != "" else ""])
		box.add_child(icon)
		if it.data.can_activate(it):
			var use: Button = UiKit.button(it.data.get_activate_label(), 11)
			use.disabled = not session.can_activate_item(it)
			use.pressed.connect(func() -> void: _on_item_use(it))
			box.add_child(use)
		grid.add_child(box)


func _tarot_icon(card: TarotCardData, selected: bool, on_press: Callable) -> Control:
	var holder: PanelContainer = UiKit.panel(Color(0, 0, 0, 0), UiConfig.COLOR_SELECTED if selected else Color.TRANSPARENT)
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon: Control = ItemIcon.new()
	icon.custom_minimum_size = Vector2(54, 64)
	icon.set("sub_text", card.display_name)
	icon.call("setup", "tarot", TarotCardData.roman(card.numeral))
	holder.add_child(icon)
	holder.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			on_press.call())
	if tooltip != null:
		var kinds: Array[String] = ["전투 예약 (1회 소모)", "즉시 설치 (영구)", "칸 지정 (영구)", "상대 간섭"]
		tooltip.call("attach", holder, func() -> String: return "%s %s · %s\n%s" % [TarotCardData.roman(card.numeral), card.display_name, kinds[int(card.category)], card.description])
	return holder


func _on_tarot_pressed(card: TarotCardData) -> void:
	if card.category == TarotCardData.Category.CELL:
		if _tarot_pending == card:
			_tarot_pending = null
			_message.text = "타로 지정을 취소했습니다"
		else:
			_tarot_pending = card
			_message.text = ("[%s] 연결할 첫 번째 칸을 클릭하세요" if card.cells_required >= 2 else "[%s] 버프를 줄 내 배치 칸을 클릭하세요 (칸 자리에 영구 귀속)") % card.display_name
		_tarot_first_cell = -1
		refresh.call_deferred()
		return
	var verb: String = "전투에 예약" if card.category == TarotCardData.Category.RESERVE else "설치"
	_ask("%s을(를) %s하시겠습니까?\n%s" % [card.display_name, verb, card.description], func() -> void:
		var reason: String = session.use_tarot(card)
		_message.text = reason if reason != "" else "%s %s 완료" % [card.display_name, verb]
		refresh.call_deferred())


func _on_item_use(it: ItemInstance) -> void:
	var choices: Array[Dictionary] = it.data.get_choices(it, session)
	if choices.is_empty():
		if it.data is CorrectionTapeItem:
			_message.text = "지울 얏츠판 기록이 없습니다"
			return
		_message.text = session.activate_item(it)
		refresh.call_deferred()
		return
	if _choice_popup == null:
		_choice_popup = (load("res://ui/widgets/choice_popup.gd") as GDScript).new()
		add_child(_choice_popup)
	for c: Dictionary in _choice_popup.get_signal_connection_list("chosen"):
		_choice_popup.disconnect("chosen", c["callable"])
	_choice_popup.connect("chosen", func(v: Variant) -> void:
		_message.text = session.activate_item(it, v)
		refresh.call_deferred(), CONNECT_ONE_SHOT)
	_choice_popup.call("open", "[%s] 고르세요" % it.data.display_name, choices)
