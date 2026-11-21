extends Control
## 주사위 테이블 화면 (예시 이미지의 배치 구조 참고, 외형은 자체 제작)
##   왼쪽: 종이 기록지 (굴린 뒤 노란 칸을 눌러 기록·확정)
##   가운데 위: 주사위 쟁반 — 출전(굴리는) 주사위. 누르면 고정되어 위 선반으로 (고정한 순서대로 왼쪽부터)
##   주사위통: 누른 채 흔들고(커서를 따라다님) 놓으면 주사위가 펠트로 쏟아져 튕기며 구른 뒤 결과가 나온다 (굴리기 버튼 없음)
##   가운데 아래: 대기 주사위(가방) + [전체 교체]
##   주사위 위 [⇅ 교체] → 아래 대기 주사위를 클릭하면 두 주사위가 서로 자리를 맞바꾸며 교체
##   오른쪽: 보스 예고, 남은 굴리기 횟수, 계산 과정
## 연출은 화면 전용 RNG를 쓰므로 게임 결과(결정론)에 영향을 주지 않는다.

signal placement_requested
signal shop_requested


func _colored_button(text: String, color: Color, font_size: int) -> Button:
	var b: Button = UiKit.button(text, font_size)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = color.lightened(0.15) if state == "hover" else (color.darkened(0.2) if state == "pressed" else color)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, sb)
	return b

const DiceTray: GDScript = preload("res://ui/widgets/dice_tray.gd")
const DieToken: GDScript = preload("res://ui/widgets/die_token.gd")
const ScoreSheet: GDScript = preload("res://ui/widgets/score_sheet.gd")
const DiceCup: GDScript = preload("res://ui/widgets/dice_cup.gd")
const ItemIcon: GDScript = preload("res://ui/widgets/item_icon.gd")

const COLOR_WOOD: Color = Color("6e4b30")
const COLOR_WOOD_GRAIN: Color = Color("5e3f27")
## 쏟아진 뒤 튕기며 구르는 시간
const POUR_TIME: float = 0.5
const FLICKER_INTERVAL: float = 0.05
const SWIPE_TIME: float = 0.4

var session: GameSession
var tooltip: Node

var _sheet: PanelContainer
var _tray: Control
var _cup: Control
var _bag_row: HBoxContainer
var _boss_label: Label
var _rolls_label: Label
var _status_label: Label
var _calc_label: RichTextLabel
var _place_button: Button
var _side_panel: PanelContainer
var _side_label: Label

var _tokens: Array[Control] = []
var _bag_tokens: Dictionary = {}
## 굴린 주사위가 펠트에 놓인 위치 (화면 연출용)
var _felt_pos: Array[Vector2] = []
var _last_pos: Array[Vector2] = []
var _vis_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _anim_indices: Array[int] = []
var _pour_from: Vector2 = Vector2(-1, -1)
var _flicker_time: float = 0.0
var _flicker_tick: float = 0.0
var _focus_index: int = 0
## 고정한 순서 (선반 왼쪽부터)
var _hold_order: Array[int] = []

var _sel_dice: DiceInstance = null
var _sel_slot: int = -1
var _swap_mode: bool = false
var _swap_picks: Array[int] = []
## [⇅ 교체]를 누른 출전 주사위 (-1 = 없음) → 아래 대기 주사위 클릭 대기
var _pick_swap_index: int = -1
var _swiping: bool = false


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
	var rolls_panel: PanelContainer = UiKit.panel(Color(0.08, 0.09, 0.12, 0.9), UiConfig.COLOR_ACCENT)
	_rolls_label = UiKit.label("", 22, Color.WHITE)
	_rolls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rolls_panel.add_child(_rolls_label)
	right.add_child(rolls_panel)
	# 기록 후: 눈에 확 띄는 배치 버튼 (초록 + 큰 글씨 + 깜빡임)
	_place_button = _colored_button("유닛배치로 가서\n배치하기 ▶", Color("2fae6b"), 20)
	_place_button.custom_minimum_size = Vector2(0, 84)
	_place_button.pressed.connect(func() -> void: placement_requested.emit())
	right.add_child(_place_button)
	var pulse: Tween = _place_button.create_tween().set_loops()
	pulse.tween_property(_place_button, "modulate", Color(1.25, 1.25, 1.25), 0.55)
	pulse.tween_property(_place_button, "modulate", Color.WHITE, 0.55)
	_status_label = UiKit.label("", 13, UiConfig.COLOR_ACCENT)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(200, 0)
	right.add_child(_status_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	# 화면 이동 버튼 (오른쪽 아래, 크게)
	var to_placement: Button = _colored_button("유닛배치", Color("3a5a8c"), 20)
	to_placement.custom_minimum_size = Vector2(0, 56)
	to_placement.pressed.connect(func() -> void: placement_requested.emit())
	right.add_child(to_placement)
	var to_shop: Button = _colored_button("상점", Color("8c5a2b"), 20)
	to_shop.custom_minimum_size = Vector2(0, 56)
	to_shop.pressed.connect(func() -> void: shop_requested.emit())
	right.add_child(to_shop)

	# [⇅ 교체] 안내 (누른 주사위 옆에 뜬다)
	_side_panel = UiKit.panel(Color(0.08, 0.09, 0.12, 0.95), UiConfig.COLOR_SELECTED)
	_side_panel.visible = false
	var side_box: VBoxContainer = VBoxContainer.new()
	_side_panel.add_child(side_box)
	_side_label = UiKit.label("", 13, Color.WHITE)
	side_box.add_child(_side_label)
	var cancel: Button = UiKit.button("취소", 13)
	cancel.pressed.connect(func() -> void:
		_pick_swap_index = -1
		refresh.call_deferred())
	side_box.add_child(cancel)
	add_child(_side_panel)

	# 주사위통 (맨 위에 그려지도록 마지막에 추가)
	_cup = DiceCup.new()
	_cup.connect("grabbed", _on_cup_grabbed)
	_cup.connect("released", _on_cup_released)
	add_child(_cup)

	session.flow.changed.connect(_queue_refresh)
	session.flow.rolled.connect(_on_rolled)
	session.deck.deck_changed.connect(_queue_refresh)


func _queue_refresh() -> void:
	if visible and not _swiping:
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
		_pick_swap_index = -1
	if flow.results.is_empty():
		_felt_pos.clear()
	_sync_hold_order()
	_sheet.call("update_sheet", flow, session.yacht)

	var info: Dictionary = LevelTable.get_upcoming_boss(flow.round_number)
	_boss_label.text = "보스 정보 없음" if info.is_empty() else "⚠ %dR 보스 [%s] (%s)\n%s" % [
		info["round"], info["name"], "이번 라운드!" if info["rounds_left"] == 0 else "%d라운드 후" % info["rounds_left"], info["gimmick"]]

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

	_rolls_label.add_theme_font_size_override("font_size", 22)
	_rolls_label.add_theme_color_override("font_color", Color.WHITE)
	# 남은 굴리기 횟수 (굴리기 버튼 없음 — 주사위통을 흔들어 굴린다)
	match flow.phase:
		RoundFlow.Phase.PREP:
			_rolls_label.text = "남은 굴리기 %d회" % (flow.get_reroll_limit() + 1)
			_status_label.text = ("바꿀 출전 주사위를 %d개 고르세요 (%d/%d)" % [_swap_need(), _swap_picks.size(), _swap_need()]) if _swap_mode \
				else "주사위통을 누른 채 흔들다가 놓으면 굴립니다.\n굴리기 전: [⇅ 교체]·인첸트 이동 가능 (굴린 주사위는 기록지에 기록할 때까지 인첸트 고정)"
		RoundFlow.Phase.ROLLING:
			_rolls_label.text = "남은 굴리기 %d회" % flow.rerolls_left
			_status_label.text = "남길 주사위를 눌러 고정(위 선반)하고 다시 흔들어 굴리거나, 기록지의 노란 칸을 눌러 기록하세요."
		RoundFlow.Phase.RECORDED:
			# 기록 완료는 작게, 배치 버튼이 눈에 띄도록
			_rolls_label.text = "기록 완료"
			_rolls_label.add_theme_font_size_override("font_size", 15)
			_rolls_label.add_theme_color_override("font_color", UiConfig.COLOR_DIM)
			_status_label.text = "%s 기록 +%s원" % [YachtBoard.CATEGORY_NAMES[flow.recorded_category], NumberFormatter.format_num(flow.recorded_gold)]
	_place_button.visible = flow.phase == RoundFlow.Phase.RECORDED

	var can: bool = flow.can_roll() and not _swap_mode and _pick_swap_index < 0
	_cup.set("enabled", can)
	_update_side_panel.call_deferred()


func _make_active_token(index: int) -> Control:
	var flow: RoundFlow = session.flow
	var deck: DeckManager = session.deck
	var dice: DiceInstance = deck.active[index]
	var result: DiceRollResult = flow.results[index] if index < flow.results.size() else null
	var held: bool = flow.held[index]
	var border: Color = Color.TRANSPARENT
	if _pick_swap_index == index or (_swap_mode and _swap_picks.has(index)):
		border = UiConfig.COLOR_SELECTED
	elif held:
		border = UiConfig.COLOR_TARGET
	var face: String = dice.get_short_name() if result == null else dice.face_label(result.raw_roll)
	var value_text: String = "" if result == null else "→ %s명" % NumberFormatter.format_num(result.summon_value)
	var token: Control = DieToken.new()
	token.call("setup", dice, face, value_text, Color("ffe08a"),
		flow.phase == RoundFlow.Phase.PREP or session.can_trespass_swap(),
		(deck.can_edit() and not deck.reserve_filled_indices().is_empty() and not _swap_mode) or session.can_trespass_swap(),
		not deck.can_edit_enchants(dice), border, _sel_slot if dice == _sel_dice else -1, false, tooltip)
	token.set_meta("tooltip_text", _dice_tooltip(dice, result))
	token.connect("pressed", func() -> void: _on_token_pressed(index))
	token.connect("swap_pressed", func() -> void:
		_pick_swap_index = -1 if _pick_swap_index == index else index
		refresh.call_deferred())
	token.connect("slot_pressed", func(slot: int) -> void: _on_slot_pressed(dice, slot))
	return token


## 고정 상태와 고정 순서를 맞춘다 (해제된 주사위는 빼고 새로 고정된 주사위는 뒤에)
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


## 토큰 위치: 굴리기 전 = 펠트에 한 줄 / 굴린 뒤 = 펠트에 흩어짐 / 고정 = 위 선반(고정한 순서)
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
			var slot: Rect2 = _tray.call("shelf_slot_rect", maxi(0, _hold_order.find(i)), count)
			target = slot.get_center() - token.size * 0.5
		elif flow.has_rolled() and i < _felt_pos.size() and _felt_pos[i].x >= 0.0:
			target = _felt_pos[i]
		else:
			var step: float = land.size.x / float(count)
			target = Vector2(land.position.x + step * (float(i) + 0.5) - token.size.x * 0.5, land.get_center().y - token.size.y * 0.5)
		if animate and _anim_indices.has(i):
			_animate_pour(token, i, target)
		elif animate and _last_pos[i].x >= 0.0 and _last_pos[i] != target:
			token.position = _last_pos[i]
			var tw: Tween = token.create_tween()
			tw.tween_property(token, "position", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			token.position = target
		_last_pos[i] = target
	if not _anim_indices.is_empty():
		_flicker_time = POUR_TIME
		_flicker_tick = 0.0
	_place_cup_home()


## 쏟아짐: 놓은 컵 위치에서 튀어나와 → 크게 한 번 튕기고 → 작게 튕긴 뒤 멈춤, 그동안 굴러가며 회전
func _animate_pour(token: Control, index: int, target: Vector2) -> void:
	var start: Vector2 = _pour_from - _tray.global_position - token.size * 0.5 if _pour_from.x >= 0.0 \
		else (_tray.call("cup_center") as Vector2) - token.size * 0.5
	token.position = start
	token.call("set_value_text", "")
	var bounce1: Vector2 = target + Vector2(_vis_rng.randf_range(-70, 70), _vis_rng.randf_range(-45, 45))
	var bounce2: Vector2 = target + Vector2(_vis_rng.randf_range(-14, 14), _vis_rng.randf_range(-10, 10))
	var delay: float = 0.03 * float(index)
	var tw: Tween = token.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(token, "position", bounce1, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(token, "position", bounce2, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(token, "position", target, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var spin: Tween = token.create_tween()
	spin.tween_interval(delay)
	spin.tween_method(func(a: float) -> void: token.call("set_spin", a), _vis_rng.randf_range(-9.0, 9.0), 0.0, POUR_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _flicker_time <= 0.0:
		return
	_flicker_time -= delta
	_flicker_tick -= delta
	if _flicker_time <= 0.0:
		# 연출 끝: 실제 결과 표시
		for i: int in _anim_indices:
			if i < _tokens.size() and i < session.flow.results.size():
				var r: DiceRollResult = session.flow.results[i]
				_tokens[i].call("set_face", session.deck.active[i].face_label(r.raw_roll))
				_tokens[i].call("set_value_text", "→ %s명" % NumberFormatter.format_num(r.summon_value))
		_anim_indices.clear()
		_pour_from = Vector2(-1, -1)
		return
	if _flicker_tick <= 0.0:
		_flicker_tick = FLICKER_INTERVAL
		for i: int in _anim_indices:
			if i < _tokens.size():
				var faces: Array[int] = session.deck.active[i].data.faces
				_tokens[i].call("set_face", str(faces[_vis_rng.randi_range(0, faces.size() - 1)]))


# =========================================================================
# 주사위통
# =========================================================================

func _place_cup_home() -> void:
	if _cup.call("is_dragging"):
		return
	var home: Vector2 = _tray.global_position - global_position + (_tray.call("cup_center") as Vector2) - _cup.size * 0.5
	_cup.set("home_position", home)
	if _cup.position == Vector2.ZERO or _anim_indices.is_empty():
		_cup.call("go_home", false)


## 잡으면: 굴릴 주사위(고정 안 한 것)들이 컵 안으로 들어간다
func _on_cup_grabbed() -> void:
	var flow: RoundFlow = session.flow
	var texts: Array[String] = []
	for i: int in range(_tokens.size()):
		if flow.has_rolled() and flow.held[i]:
			continue
		_tokens[i].visible = false
		texts.append(session.deck.active[i].get_short_name())
	_cup.call("set_inner", texts)


## 놓으면: 실제 굴림 → 그 자리에서 쏟아지는 연출 → 컵은 제자리로
func _on_cup_released(global_center: Vector2) -> void:
	_cup.call("set_inner", [] as Array[String])
	if session.flow.can_roll():
		_pour_from = global_center
		session.flow.roll()
	else:
		for t: Control in _tokens:
			t.visible = true
	_cup.call("go_home", true)


## 굴림 직후: 고정 안 한 주사위들의 펠트 위치를 새로 정하고 연출 대상으로 지정
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

func _on_token_pressed(index: int) -> void:
	var flow: RoundFlow = session.flow
	_focus_index = index
	if _swap_mode:
		if _swap_picks.has(index):
			_swap_picks.erase(index)
		elif _swap_picks.size() < _swap_need():
			_swap_picks.append(index)
		refresh.call_deferred()
	elif flow.phase == RoundFlow.Phase.ROLLING and _anim_indices.is_empty():
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


# --- [⇅ 교체]: 아래 대기 주사위를 클릭 → 서로 자리를 맞바꾸는 스와이프 -----------------

func _update_side_panel() -> void:
	if _pick_swap_index < 0 or _pick_swap_index >= _tokens.size():
		_side_panel.visible = false
		return
	var token: Control = _tokens[_pick_swap_index]
	_side_label.text = "출전 %d (%s)과 바꿀\n대기 주사위를 아래에서 클릭하세요" % [
		_pick_swap_index + 1, session.deck.active[_pick_swap_index].data.display_name]
	_side_panel.reset_size()
	var rect: Rect2 = token.get_global_rect()
	var pos: Vector2 = rect.position - global_position + Vector2(rect.size.x + 6.0, 10.0)
	if pos.x + _side_panel.size.x > size.x - 10.0:
		pos.x = rect.position.x - global_position.x - _side_panel.size.x - 6.0
	_side_panel.position = pos
	_side_panel.visible = true


func _start_swipe(active_index: int, reserve_index: int) -> void:
	if _swiping or not _bag_tokens.has(reserve_index) or active_index >= _tokens.size():
		return
	_swiping = true
	_side_panel.visible = false
	var a_token: Control = _tokens[active_index]
	var b_token: Control = _bag_tokens[reserve_index]
	var a_rect: Rect2 = a_token.call("get_icon_global_rect")
	var b_rect: Rect2 = b_token.call("get_icon_global_rect")
	var deck: DeckManager = session.deck
	var ghost_a: Control = _ghost(deck.active[active_index], a_rect)
	var ghost_b: Control = _ghost(deck.reserve[reserve_index], b_rect)
	a_token.call("set_icon_visible", false)
	b_token.call("set_icon_visible", false)
	# 두 주사위가 서로의 자리로 크게 엇갈려 이동 (위로 올라가는 쪽은 살짝 커졌다 작아짐)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(ghost_a, "position", b_rect.position - global_position, SWIPE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(ghost_a, "size", b_rect.size, SWIPE_TIME)
	tw.tween_property(ghost_b, "position", a_rect.position - global_position, SWIPE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(ghost_b, "size", a_rect.size, SWIPE_TIME)
	tw.tween_property(ghost_b, "scale", Vector2(1.25, 1.25), SWIPE_TIME * 0.5)
	tw.chain().tween_property(ghost_b, "scale", Vector2.ONE, SWIPE_TIME * 0.3)
	tw.chain().tween_callback(func() -> void:
		ghost_a.queue_free()
		ghost_b.queue_free()
		_swiping = false
		_pick_swap_index = -1
		if session.flow.phase == RoundFlow.Phase.PREP:
			deck.swap_slots(active_index, reserve_index)
		else:
			# 무단 침입 통행증: 굴림 뒤 교체 → 들어온 주사위는 바로 굴림
			session.trespass_swap(active_index, reserve_index)
		refresh())


func _ghost(dice: DiceInstance, rect: Rect2) -> Control:
	var g: Control = ItemIcon.new()
	g.call("setup_dice", dice, dice.get_short_name(), Color("fff6d8"))
	g.position = rect.position - global_position
	g.size = rect.size
	g.pivot_offset = rect.size * 0.5
	g.z_index = 10
	add_child(g)
	return g


# --- 대기 주사위(가방) 줄 · 전체 교체 ------------------------------------------

func _swap_need() -> int:
	return mini(session.deck.reserve_filled_indices().size(), session.deck.active.size())


func _rebuild_bag_row() -> void:
	var deck: DeckManager = session.deck
	UiKit.clear(_bag_row)
	_bag_tokens.clear()
	var picking: bool = _pick_swap_index >= 0
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
		token.call("setup", d, d.get_short_name(), "교체" if picking else "", UiConfig.COLOR_SELECTED, false, false,
			not deck.can_edit_enchants(d), UiConfig.COLOR_SELECTED if picking else Color.TRANSPARENT,
			_sel_slot if d == _sel_dice else -1, true, tooltip)
		token.set_meta("tooltip_text", _dice_tooltip(d, null) + ("\n클릭: 이 주사위로 교체" if picking else ""))
		var reserve_index: int = i
		token.connect("pressed", func() -> void:
			if _pick_swap_index >= 0:
				_start_swipe(_pick_swap_index, reserve_index))
		token.connect("slot_pressed", func(slot: int) -> void: _on_slot_pressed(d, slot))
		_bag_row.add_child(token)
		_bag_tokens[i] = token
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
		all.disabled = not deck.can_edit() or need == 0 or picking
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
	# 계산 과정 패널은 제거됨 (주사위에 마우스를 올리면 툴팁으로 확인)
	if _calc_label == null:
		return
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
