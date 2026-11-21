extends Control
## 주사위 테이블 화면 (예시 이미지의 배치 구조 참고, 외형은 자체 제작)
##   왼쪽: 종이 기록지 (굴린 뒤 노란 칸을 눌러 기록·확정)
##   가운데 위: 주사위 쟁반 — 출전(굴리는) 주사위. 굴리면 컵에서 펠트로 쏟아지고, 누르면 고정되어 위 선반으로 이동
##   가운데 아래: 대기 주사위(가방) + [전체 교체]
##   주사위 위 [⇅ 교체]: 가방 주사위 중 하나를 골라 교체 / 주사위 아래 곡선 인첸트 슬롯
##   오른쪽: 보스 예고, 남은 재굴림, [굴리기], 계산 과정
## 굴림 연출은 화면 전용 RNG를 쓰므로 게임 결과(결정론)에 영향을 주지 않는다.

signal placement_requested

const DiceTray: GDScript = preload("res://ui/widgets/dice_tray.gd")
const DieToken: GDScript = preload("res://ui/widgets/die_token.gd")
const ScoreSheet: GDScript = preload("res://ui/widgets/score_sheet.gd")

const COLOR_WOOD: Color = Color("6e4b30")
const COLOR_WOOD_GRAIN: Color = Color("5e3f27")
const ROLL_ANIM_TIME: float = 0.55
const FLICKER_INTERVAL: float = 0.05

var session: GameSession
var tooltip: Node

var _sheet: PanelContainer
var _tray: Control
var _bag_row: HBoxContainer
var _boss_label: Label
var _rolls_label: Label
var _status_label: Label
var _calc_label: RichTextLabel
var _roll_button: Button
var _place_button: Button
var _popup: PanelContainer
var _popup_box: VBoxContainer

var _tokens: Array[Control] = []
## 굴린 주사위가 펠트에 놓인 위치 (화면 연출용)
var _felt_pos: Array[Vector2] = []
var _last_pos: Array[Vector2] = []
var _vis_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _anim_indices: Array[int] = []
var _flicker_time: float = 0.0
var _flicker_tick: float = 0.0
var _focus_index: int = 0

var _sel_dice: DiceInstance = null
var _sel_slot: int = -1
var _swap_mode: bool = false
var _swap_picks: Array[int] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vis_rng.randomize()
	var wood: Control = Control.new()
	wood.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wood.draw.connect(func() -> void:
		wood.draw_rect(Rect2(Vector2.ZERO, wood.size), COLOR_WOOD)
		for k: int in range(int(wood.size.y / 26.0) + 1):
			var y: float = float(k) * 26.0 + float(k % 3) * 4.0
			wood.draw_line(Vector2(0, y), Vector2(wood.size.x, y + 6.0), COLOR_WOOD_GRAIN, 2.0))
	add_child(wood)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.add_theme_constant_override("margin_top", UiConfig.TOP_BAR_HEIGHT + 8)
	add_child(margin)
	var main: HBoxContainer = HBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	margin.add_child(main)

	# 왼쪽: 기록지
	_sheet = ScoreSheet.new()
	_sheet.custom_minimum_size = Vector2(240, 0)
	_sheet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_sheet.connect("category_pressed", func(c: int) -> void: session.flow.record_yacht(c))
	main.add_child(_sheet)

	# 가운데: 쟁반(위) + 대기 주사위(아래)
	var center: VBoxContainer = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	main.add_child(center)
	_tray = DiceTray.new()
	_tray.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tray.custom_minimum_size = Vector2(0, 420)
	_tray.resized.connect(func() -> void: _layout_tokens(false))
	center.add_child(_tray)
	var bag_panel: PanelContainer = UiKit.panel(Color(0.18, 0.12, 0.08, 0.92))
	_bag_row = HBoxContainer.new()
	_bag_row.add_theme_constant_override("separation", 8)
	bag_panel.add_child(_bag_row)
	center.add_child(bag_panel)

	# 오른쪽: 진행
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(220, 0)
	right.add_theme_constant_override("separation", 8)
	main.add_child(right)
	var boss_panel: PanelContainer = UiKit.panel(Color("3a2630"))
	_boss_label = UiKit.label("", 12)
	_boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boss_label.custom_minimum_size = Vector2(200, 0)
	boss_panel.add_child(_boss_label)
	right.add_child(boss_panel)
	_rolls_label = UiKit.label("", 20, Color.WHITE)
	_rolls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_rolls_label)
	_roll_button = UiKit.button("굴리기", 22)
	_roll_button.custom_minimum_size = Vector2(0, 60)
	_roll_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_roll_button.pressed.connect(func() -> void: session.flow.roll())
	right.add_child(_roll_button)
	_place_button = UiKit.button("유닛배치로 가서 배치하기 ▶", 15)
	_place_button.custom_minimum_size = Vector2(0, 44)
	_place_button.pressed.connect(func() -> void: placement_requested.emit())
	right.add_child(_place_button)
	_status_label = UiKit.label("", 13, UiConfig.COLOR_ACCENT)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(200, 0)
	right.add_child(_status_label)
	var calc_panel: PanelContainer = UiKit.panel()
	calc_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_calc_label = RichTextLabel.new()
	_calc_label.bbcode_enabled = true
	_calc_label.fit_content = true
	_calc_label.scroll_active = false
	_calc_label.custom_minimum_size = Vector2(200, 0)
	_calc_label.add_theme_font_size_override("normal_font_size", 13)
	_calc_label.add_theme_font_size_override("bold_font_size", 13)
	calc_panel.add_child(_calc_label)
	right.add_child(calc_panel)

	_build_popup()
	session.flow.changed.connect(_queue_refresh)
	session.flow.rolled.connect(_on_rolled)
	session.deck.deck_changed.connect(_queue_refresh)


func _queue_refresh() -> void:
	if visible:
		refresh.call_deferred()


# =========================================================================
# 갱신
# =========================================================================

func refresh() -> void:
	if session == null or _tray == null:
		return
	var flow: RoundFlow = session.flow
	var deck: DeckManager = session.deck
	if flow.phase != RoundFlow.Phase.PREP:
		_swap_mode = false
		_popup.visible = false
	if flow.results.is_empty():
		_felt_pos.clear()
	_sync_hold_order()
	_sheet.call("update_sheet", flow, session.yacht)

	var info: Dictionary = LevelTable.get_upcoming_boss(flow.round_number)
	_boss_label.text = "보스 정보 없음" if info.is_empty() else "⚠ %dR 보스 [%s] (%s)\n%s" % [
		info["round"], info["name"], "이번 라운드!" if info["rounds_left"] == 0 else "%d라운드 후" % info["rounds_left"], info["gimmick"]]

	# 쟁반 위 출전 주사위
	for t: Control in _tokens:
		_tray.remove_child(t)
		t.queue_free()
	_tokens.clear()
	for i: int in range(deck.active.size()):
		var token: Control = _make_active_token(i)
		_tray.add_child(token)
		_tokens.append(token)
	_layout_tokens.call_deferred(true)
	_rebuild_bag_row()
	_update_calc()

	match flow.phase:
		RoundFlow.Phase.PREP:
			_rolls_label.text = "굴리기 전"
			_roll_button.text = "굴리기"
			_roll_button.disabled = _swap_mode
			_status_label.text = ("바꿀 출전 주사위를 %d개 고르세요 (%d/%d)" % [_swap_need(), _swap_picks.size(), _swap_need()]) if _swap_mode \
				else "[⇅ 교체]로 가방 주사위와 바꾸거나 인첸트를 옮긴 뒤 [굴리기]. 굴린 주사위는 이번 라운드 동안 인첸트가 고정됩니다."
		RoundFlow.Phase.ROLLING:
			_rolls_label.text = "재굴림 %d회 남음" % flow.rerolls_left
			_roll_button.text = "다시 굴리기"
			_roll_button.disabled = not flow.can_roll()
			_status_label.text = "남길 주사위를 눌러 고정(위 선반)하고 다시 굴리거나, 기록지의 노란 칸을 눌러 기록하세요."
		RoundFlow.Phase.RECORDED:
			_rolls_label.text = "기록 완료"
			_roll_button.text = "확정됨"
			_roll_button.disabled = true
			_status_label.text = "%s 기록 +%s원" % [YachtBoard.CATEGORY_NAMES[flow.recorded_category], NumberFormatter.format_num(flow.recorded_gold)]
	_place_button.visible = flow.phase == RoundFlow.Phase.RECORDED


func _make_active_token(index: int) -> Control:
	var flow: RoundFlow = session.flow
	var deck: DeckManager = session.deck
	var dice: DiceInstance = deck.active[index]
	var result: DiceRollResult = flow.results[index] if index < flow.results.size() else null
	var held: bool = flow.held[index]
	var border: Color = Color.TRANSPARENT
	if _swap_mode and _swap_picks.has(index):
		border = UiConfig.COLOR_SELECTED
	elif held:
		border = UiConfig.COLOR_TARGET
	var face: String = String(dice.data.id) if result == null else str(result.raw_roll)
	var value_text: String = "" if result == null else "→ %s명" % NumberFormatter.format_num(result.summon_value)
	var token: Control = DieToken.new()
	token.call("setup", dice, face, value_text, Color("ffe08a"),
		flow.phase == RoundFlow.Phase.PREP, deck.can_edit() and not deck.reserve_filled_indices().is_empty() and not _swap_mode,
		not deck.can_edit_dice(dice), border, _sel_slot if dice == _sel_dice else -1, false, tooltip)
	token.set_meta("tooltip_text", _dice_tooltip(dice, result))
	token.connect("pressed", func() -> void: _on_token_pressed(index))
	token.connect("swap_pressed", func() -> void: _open_swap_popup(index))
	token.connect("slot_pressed", func(slot: int) -> void: _on_slot_pressed(dice, slot))
	return token


## 토큰 위치: 굴리기 전 = 펠트에 한 줄 / 굴린 뒤 = 펠트에 흩어짐 / 고정 = 위 선반
func _layout_tokens(animate: bool) -> void:
	if _tokens.is_empty() or _tray.size.x <= 0.0:
		return
	var flow: RoundFlow = session.flow
	var land: Rect2 = _tray.call("landing_rect")
	var count: int = _tokens.size()
	if _last_pos.size() != count:
		_last_pos.resize(count)
		_last_pos.fill(Vector2(-1, -1))
	for i: int in range(count):
		var token: Control = _tokens[i]
		var target: Vector2
		if flow.has_rolled() and flow.held[i]:
			# 고정한 순서대로 선반 왼쪽부터 채운다
			var slot: Rect2 = _tray.call("shelf_slot_rect", maxi(0, _hold_order.find(i)), count)
			target = slot.get_center() - token.size * 0.5
		elif flow.has_rolled() and i < _felt_pos.size() and _felt_pos[i].x >= 0.0:
			target = _felt_pos[i]
		else:
			var step: float = land.size.x / float(count)
			target = Vector2(land.position.x + step * (float(i) + 0.5) - token.size.x * 0.5, land.get_center().y - token.size.y * 0.5)
		if animate and _anim_indices.has(i):
			# 굴림: 컵에서 튀어나와 펠트에 떨어진다
			token.position = (_tray.call("cup_center") as Vector2) - token.size * 0.5
			var tw: Tween = token.create_tween()
			tw.tween_property(token, "position", target, ROLL_ANIM_TIME + 0.05 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif animate and _last_pos[i].x >= 0.0 and _last_pos[i] != target:
			token.position = _last_pos[i]
			var tw2: Tween = token.create_tween()
			tw2.tween_property(token, "position", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			token.position = target
		_last_pos[i] = target
	if not _anim_indices.is_empty():
		_flicker_time = ROLL_ANIM_TIME
		_flicker_tick = 0.0


func _process(delta: float) -> void:
	if _flicker_time <= 0.0:
		return
	_flicker_time -= delta
	_flicker_tick -= delta
	if _flicker_time <= 0.0:
		# 연출 끝: 실제 결과 면 표시
		for i: int in _anim_indices:
			if i < _tokens.size() and i < session.flow.results.size():
				_tokens[i].call("set_face", str(session.flow.results[i].raw_roll))
		_anim_indices.clear()
		return
	if _flicker_tick <= 0.0:
		_flicker_tick = FLICKER_INTERVAL
		for i: int in _anim_indices:
			if i < _tokens.size():
				var faces: Array[int] = session.deck.active[i].data.faces
				_tokens[i].call("set_face", str(faces[_vis_rng.randi_range(0, faces.size() - 1)]))


## 굴림 직후: 고정 안 한 주사위들의 펠트 위치를 새로 정하고 연출 시작
func _on_rolled(_results: Array[DiceRollResult]) -> void:
	var flow: RoundFlow = session.flow
	var count: int = session.deck.active.size()
	if _felt_pos.size() != count:
		_felt_pos.resize(count)
		_felt_pos.fill(Vector2(-1, -1))
	_anim_indices.clear()
	var land: Rect2 = _tray.call("landing_rect")
	var token_size: Vector2 = DieToken.SIZE_NORMAL
	var columns: Array[int] = [0, 1, 2, 3, 4]
	columns.shuffle()
	var col_w: float = land.size.x / float(count)
	var k: int = 0
	for i: int in range(count):
		if flow.held[i]:
			continue
		var col: int = columns[k % columns.size()]
		k += 1
		var x: float = land.position.x + col_w * (float(col) + 0.5) - token_size.x * 0.5 + _vis_rng.randf_range(-10.0, 10.0)
		var y: float = land.position.y + _vis_rng.randf_range(0.0, maxf(0.0, land.size.y - token_size.y))
		_felt_pos[i] = Vector2(x, y)
		_anim_indices.append(i)
	_focus_index = _anim_indices[0] if not _anim_indices.is_empty() else _focus_index


# =========================================================================
# 조작
# =========================================================================

## 고정한 순서 (선반 왼쪽부터 배치). 화면 표시용이라 RoundFlow가 아닌 여기서 관리한다.
var _hold_order: Array[int] = []


## 실제 고정 상태(RoundFlow.held)와 맞춘다: 해제된 주사위는 빼고(뒤 주사위들이 왼쪽으로 당겨짐),
## 새로 고정된 주사위는 맨 뒤에 붙인다.
func _sync_hold_order() -> void:
	var held: Array[bool] = session.flow.held
	var kept: Array[int] = []
	for i: int in _hold_order:
		if i < held.size() and held[i] and not kept.has(i):
			kept.append(i)
	for i: int in range(held.size()):
		if held[i] and not kept.has(i):
			kept.append(i)
	_hold_order = kept


func _on_token_pressed(index: int) -> void:
	var flow: RoundFlow = session.flow
	_focus_index = index
	if _swap_mode:
		if _swap_picks.has(index):
			_swap_picks.erase(index)
		elif _swap_picks.size() < _swap_need():
			_swap_picks.append(index)
		refresh.call_deferred()
	elif flow.phase == RoundFlow.Phase.ROLLING:
		flow.toggle_hold(index)
	else:
		_update_calc()


func _on_slot_pressed(dice: DiceInstance, slot: int) -> void:
	var deck: DeckManager = session.deck
	if _sel_dice != null and _sel_slot >= 0 and not (_sel_dice == dice and _sel_slot == slot):
		if deck.transfer_enchant(_sel_dice, _sel_slot, dice, slot):
			_sel_dice = null
			_sel_slot = -1
			refresh.call_deferred()
			return
	if slot < dice.unlocked_slots and dice.slots[slot] != null and not (_sel_dice == dice and _sel_slot == slot):
		_sel_dice = dice
		_sel_slot = slot
	else:
		_sel_dice = null
		_sel_slot = -1
	refresh.call_deferred()


# --- [⇅ 교체] 팝업: 가방 주사위 중 하나 선택 ------------------------------------

func _build_popup() -> void:
	_popup = UiKit.panel(Color(0.08, 0.09, 0.12, 0.97), UiConfig.COLOR_ACCENT)
	_popup.set_anchors_preset(Control.PRESET_CENTER)
	_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	_popup.visible = false
	add_child(_popup)
	_popup_box = VBoxContainer.new()
	_popup_box.add_theme_constant_override("separation", 6)
	_popup.add_child(_popup_box)


func _open_swap_popup(active_index: int) -> void:
	var deck: DeckManager = session.deck
	UiKit.clear(_popup_box)
	_popup_box.add_child(UiKit.label("출전 %d (%s)와 바꿀 가방 주사위를 고르세요" % [active_index + 1, deck.active[active_index].data.display_name], 15, UiConfig.COLOR_ACCENT))
	for j: int in deck.reserve_filled_indices():
		var d: DiceInstance = deck.reserve[j]
		var b: Button = UiKit.button("%s   ·   인첸트: %s" % [d.data.display_name, _enchant_summary(d)], 14)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func() -> void:
			deck.swap_slots(active_index, j)
			_popup.visible = false)
		_popup_box.add_child(b)
	var cancel: Button = UiKit.button("취소", 14)
	cancel.pressed.connect(func() -> void: _popup.visible = false)
	_popup_box.add_child(cancel)
	_popup.reset_size()
	_popup.visible = true


# --- 대기 주사위(가방) 줄 · 전체 교체 ------------------------------------------

func _swap_need() -> int:
	return mini(session.deck.reserve_filled_indices().size(), session.deck.active.size())


func _rebuild_bag_row() -> void:
	var deck: DeckManager = session.deck
	UiKit.clear(_bag_row)
	_bag_row.add_child(UiKit.label("대기 주사위\n%s %d/%d칸" % [session.shop.get_bag_name(), deck.reserve_filled_indices().size(), deck.reserve_unlocked], 12, UiConfig.COLOR_ACCENT))
	for i: int in range(deck.reserve_unlocked):
		var d: DiceInstance = deck.reserve[i]
		if d == null:
			var empty: Label = UiKit.label("빈칸", 12, UiConfig.COLOR_DIM)
			empty.custom_minimum_size = DieToken.SIZE_SMALL
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_bag_row.add_child(empty)
			continue
		var token: Control = DieToken.new()
		token.call("setup", d, String(d.data.id), "", Color.WHITE, false, false,
			not deck.can_edit_dice(d), Color.TRANSPARENT, _sel_slot if d == _sel_dice else -1, true, tooltip)
		token.set_meta("tooltip_text", _dice_tooltip(d, null))
		token.connect("slot_pressed", func(slot: int) -> void: _on_slot_pressed(d, slot))
		_bag_row.add_child(token)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_row.add_child(spacer)
	var need: int = _swap_need()
	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_bag_row.add_child(buttons)
	if _swap_mode:
		var ok: Button = UiKit.button("교체 확정 (%d/%d)" % [_swap_picks.size(), need], 14)
		ok.disabled = _swap_picks.size() != need
		ok.pressed.connect(func() -> void:
			deck.swap_selected(_swap_picks)
			_swap_mode = false
			_swap_picks.clear()
			refresh.call_deferred())
		buttons.add_child(ok)
		var cancel: Button = UiKit.button("취소", 14)
		cancel.pressed.connect(func() -> void:
			_swap_mode = false
			_swap_picks.clear()
			refresh.call_deferred())
		buttons.add_child(cancel)
	else:
		var all: Button = UiKit.button("전체 교체", 15)
		all.custom_minimum_size = Vector2(110, 44)
		all.disabled = not deck.can_edit() or need == 0
		all.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		all.pressed.connect(func() -> void:
			if need >= deck.active.size():
				deck.swap_active_and_reserve()
			else:
				_swap_mode = true
				_swap_picks.clear()
			refresh.call_deferred())
		if tooltip != null:
			tooltip.call("attach", all, func() -> String:
				return "출전 주사위와 대기 주사위를 한 번에 교체\n대기 주사위가 5개보다 적으면 바꿀 출전 주사위를 그 수만큼 고릅니다")
		buttons.add_child(all)


# --- 표시 -----------------------------------------------------------------------

## 오른쪽 "계산 과정": 마지막으로 누른 주사위의 연산 단계 (메아리 발동·미발동 표기)
func _update_calc() -> void:
	var flow: RoundFlow = session.flow
	var i: int = clampi(_focus_index, 0, session.deck.active.size() - 1)
	var dice: DiceInstance = session.deck.active[i]
	var head: String = "[b]계산 과정 · 출전 %d (%s)[/b]\n" % [i + 1, dice.data.display_name]
	if i >= flow.results.size():
		_calc_label.text = head + "[color=#9aa0b4]굴린 뒤 표시됩니다.\n인첸트: %s[/color]" % _enchant_summary(dice)
		return
	_calc_label.text = head + _steps_bbcode(flow.results[i])


func _steps_bbcode(result: DiceRollResult) -> String:
	var lines: PackedStringArray = []
	for entry: Dictionary in result.logs:
		var source: String = entry["source"]
		var op: String = entry["op"]
		var value_text: String = NumberFormatter.format_fixed(entry["value"])
		if entry["skipped"]:
			lines.append("[color=#ff7b7b]✖ %s 미발동 (%s)[/color]" % [source, entry["reason"]])
		elif source == "원시 눈금":
			lines.append("눈금 [b]%s[/b]" % op)
		elif op.begins_with("면 "):
			lines.append("[color=#9aa0b4]%s %s[/color]" % [source, op])
		elif source.contains(" → "):
			lines.append("[color=#c9a0ff]↻ %s[/color] %s = %s" % [source.get_slice(" → ", 0), op, value_text])
		else:
			lines.append("%s %s = %s%s" % [source, op, value_text, " [color=#ffae57](1로 보정)[/color]" if entry["clamped"] else ""])
	if result.final_value % FixedNum.SCALE != 0:
		lines.append("[color=#9aa0b4]반올림[/color]")
	lines.append("[color=#ffe08a][b]→ 소환 %s명[/b][/color]" % NumberFormatter.format_num(result.summon_value))
	return "\n".join(lines)


func _dice_tooltip(dice: DiceInstance, result: DiceRollResult) -> String:
	var faces: String = str(dice.data.faces) if dice.data.faces.size() <= 8 else "1 ~ %d" % dice.data.faces.size()
	var text: String = "%s\n면: %s\n인첸트: %s" % [dice.data.display_name, faces, _enchant_summary(dice)]
	if result != null:
		text += "\n눈금 %d → 소환 %s명" % [result.raw_roll, NumberFormatter.format_num(result.summon_value)]
		if session.flow.phase == RoundFlow.Phase.ROLLING:
			text += "\n클릭: 고정 / 해제"
	return text


func _enchant_summary(dice: DiceInstance) -> String:
	var names: PackedStringArray = []
	for inst: EnchantInstance in dice.get_enchants():
		names.append(inst.get_display_name())
	return "없음" if names.is_empty() else " → ".join(names)
