extends Control
## 주사위 테이블 화면 (굴림·재굴림·얏츠판 기록). 주사위 UI 예시 이미지 기준:
##   주사위 위 [▲][▼] = 가방 주사위와 순환 교체 (첫 굴림 전)
##   주사위 아래 곡선 모양 작은 인첸트 슬롯 (선택 → 다른 슬롯 클릭으로 이동)
##   가방 줄 + [전체 교체]: 가방 주사위가 5개 미만이면 바꿀 출전 주사위를 그 수만큼 고른다
## 나중에 주사위를 실제로 굴리는 공간·애니메이션을 넣을 때는 _make_card()의 주사위 아이콘 부분만 교체하면 된다.

signal placement_requested

const ItemIcon: GDScript = preload("res://ui/widgets/item_icon.gd")
const SlotRow: GDScript = preload("res://ui/widgets/slot_row.gd")

var session: GameSession
var tooltip: Node

var _boss_label: Label
var _status_label: Label
var _cards_row: HBoxContainer
var _bag_row: HBoxContainer
var _yacht_box: VBoxContainer
var _roll_button: Button
var _place_button: Button

## 인첸트 이동용 선택
var _sel_dice: DiceInstance = null
var _sel_slot: int = -1
## 전체 교체 선택 모드
var _swap_mode: bool = false
var _swap_picks: Array[int] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("1b1d24")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.add_theme_constant_override("margin_top", UiConfig.TOP_BAR_HEIGHT + 8)
	add_child(margin)
	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 6)
	margin.add_child(main)

	var boss_panel: PanelContainer = UiKit.panel(Color("3a2630"))
	_boss_label = UiKit.label("", 13)
	boss_panel.add_child(_boss_label)
	main.add_child(boss_panel)
	_status_label = UiKit.label("", 14, UiConfig.COLOR_ACCENT)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(_status_label)

	var middle: HBoxContainer = HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	main.add_child(middle)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(left)
	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", 8)
	_cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_cards_row)
	var bag_panel: PanelContainer = UiKit.panel(Color(0.16, 0.13, 0.1, 0.95))
	_bag_row = HBoxContainer.new()
	_bag_row.add_theme_constant_override("separation", 10)
	bag_panel.add_child(_bag_row)
	left.add_child(bag_panel)

	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(250, 0)
	middle.add_child(right)
	var yacht_panel: PanelContainer = UiKit.panel()
	yacht_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_yacht_box = VBoxContainer.new()
	_yacht_box.add_theme_constant_override("separation", 3)
	yacht_panel.add_child(_yacht_box)
	right.add_child(yacht_panel)
	_roll_button = UiKit.button("굴림", 20)
	_roll_button.custom_minimum_size = Vector2(0, 50)
	_roll_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_roll_button.pressed.connect(func() -> void: session.flow.roll())
	right.add_child(_roll_button)
	_place_button = UiKit.button("연병장에서 배치하기 ▶", 16)
	_place_button.custom_minimum_size = Vector2(0, 42)
	_place_button.pressed.connect(func() -> void: placement_requested.emit())
	right.add_child(_place_button)

	session.flow.changed.connect(_queue_refresh)
	session.deck.deck_changed.connect(_queue_refresh)


func _queue_refresh() -> void:
	if visible:
		refresh.call_deferred()


func refresh() -> void:
	if session == null or _cards_row == null:
		return
	var flow: RoundFlow = session.flow
	var deck: DeckManager = session.deck
	if flow.phase != RoundFlow.Phase.PREP:
		_swap_mode = false
	var info: Dictionary = LevelTable.get_upcoming_boss(flow.round_number)
	_boss_label.text = "보스 정보 없음" if info.is_empty() else "⚠ %dR 보스 [%s] (%s)  %s" % [
		info["round"], info["name"], "이번 라운드!" if info["rounds_left"] == 0 else "%d라운드 후" % info["rounds_left"], info["gimmick"]]

	UiKit.clear(_cards_row)
	for i: int in range(deck.active.size()):
		_cards_row.add_child(_make_card(i))
	_rebuild_bag_row()
	_rebuild_yacht()

	match flow.phase:
		RoundFlow.Phase.PREP:
			_roll_button.text = "굴림"
			_roll_button.disabled = _swap_mode
			_status_label.text = ("전체 교체: 가방 주사위와 바꿀 출전 주사위를 %d개 고르세요 (%d/%d)" % [_swap_need(), _swap_picks.size(), _swap_need()]) if _swap_mode \
				else "준비: [▲][▼]로 가방 주사위와 교체하거나 인첸트를 옮긴 뒤 [굴림]. 굴린 주사위는 이번 라운드 동안 인첸트가 고정됩니다."
		RoundFlow.Phase.ROLLING:
			_roll_button.text = "재굴림 (%d회 남음)" % flow.rerolls_left
			_roll_button.disabled = not flow.can_roll()
			_status_label.text = "남길 주사위를 눌러 [고정]하고 재굴림하거나, 오른쪽 얏츠판 항목을 눌러 확정·기록하세요 (매 라운드 1항목 필수)."
		RoundFlow.Phase.RECORDED:
			_roll_button.text = "확정됨"
			_roll_button.disabled = true
			_status_label.text = "%s 기록 +%s원 → [연병장에서 배치하기]로 소환하세요." % [
				YachtBoard.CATEGORY_NAMES[flow.recorded_category], NumberFormatter.format_num(flow.recorded_gold)]
	_place_button.visible = flow.phase == RoundFlow.Phase.RECORDED


# --- 주사위 카드 ---------------------------------------------------------------

func _make_card(index: int) -> Control:
	var flow: RoundFlow = session.flow
	var deck: DeckManager = session.deck
	var dice: DiceInstance = deck.active[index]
	var result: DiceRollResult = flow.results[index] if index < flow.results.size() else null
	var held: bool = flow.held[index]
	var picked: bool = _swap_mode and _swap_picks.has(index)
	var border: Color = UiConfig.COLOR_SELECTED if picked else (UiConfig.COLOR_TARGET if held else Color.TRANSPARENT)
	var card: PanelContainer = UiKit.panel(Color("323645"), border)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)

	# ▲▼ : 가방 주사위와 순환 교체
	var arrows: HBoxContainer = HBoxContainer.new()
	arrows.alignment = BoxContainer.ALIGNMENT_CENTER
	var can_cycle: bool = deck.can_edit() and not deck.reserve_filled_indices().is_empty() and not _swap_mode
	for dir: int in [-1, 1]:
		var ab: Button = UiKit.button("▲" if dir < 0 else "▼", 16)
		ab.disabled = not can_cycle
		ab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ab.pressed.connect(func() -> void: deck.cycle_active(index, dir))
		if tooltip != null:
			tooltip.call("attach", ab, func() -> String: return "가방 주사위와 교체 (%s)\n첫 굴림 전에만 가능" % ("이전" if dir < 0 else "다음"))
		arrows.add_child(ab)
	box.add_child(arrows)

	# 주사위 (굴림 중에는 눌러서 고정/해제, 전체 교체 중에는 선택)
	var holder: PanelContainer = UiKit.panel(Color(0, 0, 0, 0))
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon: Control = ItemIcon.new()
	icon.custom_minimum_size = Vector2(76, 76)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.call("setup", "dice", String(dice.data.id), Color("f4f1e8") if deck.can_edit_dice(dice) else Color("c9c4b8"))
	holder.add_child(icon)
	holder.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_on_card_pressed(index))
	if tooltip != null:
		tooltip.call("attach", holder, func() -> String: return _dice_tooltip(dice))
	box.add_child(holder)

	var value: Label = UiKit.label("-" if result == null else NumberFormatter.format_num(result.summon_value), 30)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	if held:
		var hl: Label = UiKit.label("고정됨", 12, UiConfig.COLOR_TARGET)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(hl)

	var steps: RichTextLabel = RichTextLabel.new()
	steps.bbcode_enabled = true
	steps.fit_content = true
	steps.scroll_active = false
	steps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	steps.add_theme_font_size_override("normal_font_size", 12)
	steps.add_theme_font_size_override("bold_font_size", 12)
	steps.text = _steps_bbcode(result) if result != null else ""
	box.add_child(steps)

	# 곡선 인첸트 슬롯 (예시 이미지처럼 주사위 아래에 작게)
	var row: Control = SlotRow.new()
	row.set("arc_depth", 10.0)
	row.call("setup", dice, UiConfig.SLOT_RADIUS + 2.0, tooltip)
	row.set("locked", not deck.can_edit_dice(dice))
	row.set("selected_slot", _sel_slot if dice == _sel_dice else -1)
	row.connect("slot_pressed", func(slot: int) -> void: _on_slot_pressed(dice, slot))
	box.add_child(row)
	return card


func _on_card_pressed(index: int) -> void:
	var flow: RoundFlow = session.flow
	if _swap_mode:
		if _swap_picks.has(index):
			_swap_picks.erase(index)
		elif _swap_picks.size() < _swap_need():
			_swap_picks.append(index)
		refresh.call_deferred()
	elif flow.phase == RoundFlow.Phase.ROLLING:
		flow.toggle_hold(index)


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


# --- 가방 줄 · 전체 교체 --------------------------------------------------------

func _swap_need() -> int:
	return mini(session.deck.reserve_filled_indices().size(), session.deck.active.size())


func _rebuild_bag_row() -> void:
	var deck: DeckManager = session.deck
	UiKit.clear(_bag_row)
	_bag_row.add_child(UiKit.label("%s\n%d/%d칸" % [session.shop.get_bag_name(), deck.reserve_filled_indices().size(), deck.reserve_unlocked], 12, UiConfig.COLOR_ACCENT))
	for i: int in range(deck.reserve_unlocked):
		var d: DiceInstance = deck.reserve[i]
		var cell: VBoxContainer = VBoxContainer.new()
		if d == null:
			cell.add_child(UiKit.label("빈칸", 12, UiConfig.COLOR_DIM))
		else:
			var icon: Control = ItemIcon.new()
			icon.custom_minimum_size = Vector2(44, 44)
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			icon.call("setup", "dice", String(d.data.id), Color("f4f1e8"))
			var holder: PanelContainer = UiKit.panel(Color(0, 0, 0, 0))
			holder.add_child(icon)
			if tooltip != null:
				tooltip.call("attach", holder, func() -> String: return _dice_tooltip(d))
			cell.add_child(holder)
			var row: Control = SlotRow.new()
			row.call("setup", d, UiConfig.SLOT_RADIUS - 2.0, tooltip)
			row.set("selected_slot", _sel_slot if d == _sel_dice else -1)
			row.connect("slot_pressed", func(slot: int) -> void: _on_slot_pressed(d, slot))
			cell.add_child(row)
		_bag_row.add_child(cell)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_row.add_child(spacer)
	var need: int = _swap_need()
	if _swap_mode:
		var ok: Button = UiKit.button("교체 확정 (%d/%d)" % [_swap_picks.size(), need], 14)
		ok.disabled = _swap_picks.size() != need
		ok.pressed.connect(func() -> void:
			deck.swap_selected(_swap_picks)
			_swap_mode = false
			_swap_picks.clear()
			refresh.call_deferred())
		_bag_row.add_child(ok)
		var cancel: Button = UiKit.button("취소", 14)
		cancel.pressed.connect(func() -> void:
			_swap_mode = false
			_swap_picks.clear()
			refresh.call_deferred())
		_bag_row.add_child(cancel)
	else:
		var all: Button = UiKit.button("전체 교체", 15)
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
				return "출전 주사위와 가방 주사위를 한 번에 교체\n가방 주사위가 5개보다 적으면 바꿀 출전 주사위를 그 수만큼 고릅니다")
		_bag_row.add_child(all)


# --- 얏츠판 -------------------------------------------------------------------

func _rebuild_yacht() -> void:
	UiKit.clear(_yacht_box)
	var flow: RoundFlow = session.flow
	var board: YachtBoard = session.yacht
	_yacht_box.add_child(UiKit.label("얏츠판 (1의 자리 판정)", 16, UiConfig.COLOR_ACCENT))
	_yacht_box.add_child(UiKit.label("프레스티지 %d · 보상 ×%d · %d/10칸" % [
		board.prestige_level, board.get_reward_multiplier(), board.recorded.size()], 12, UiConfig.COLOR_DIM))
	if flow.has_rolled():
		_yacht_box.add_child(UiKit.label("1의 자리: " + str(YachtBoard.to_digits(flow.get_summon_values())), 12, UiConfig.COLOR_DIM))
	var preview: Dictionary = flow.get_yacht_preview()
	for category: int in YachtBoard.Category.values():
		var cat_name: String = YachtBoard.CATEGORY_NAMES[category]
		var b: Button = UiKit.button("", 14)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if board.is_recorded(category):
			b.text = "✔ %s  %s원" % [cat_name, NumberFormatter.format_num(board.recorded[category])]
			b.disabled = true
		elif preview.has(category):
			var gold: int = preview[category]
			b.text = "%s  →  %s원" % [cat_name, NumberFormatter.format_num(gold)]
			if gold > 0:
				b.add_theme_color_override("font_color", Color("7bd88f"))
			b.disabled = flow.phase != RoundFlow.Phase.ROLLING
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			b.text = cat_name
			b.disabled = true
		b.pressed.connect(func() -> void: flow.record_yacht(category))
		_yacht_box.add_child(b)


# --- 표시 헬퍼 -----------------------------------------------------------------

## 연산 로그 → BBCode (메아리 발동·미발동을 확실히 표기)
func _steps_bbcode(result: DiceRollResult) -> String:
	var lines: PackedStringArray = []
	for entry: Dictionary in result.logs:
		var source: String = entry["source"]
		var op: String = entry["op"]
		var value_text: String = NumberFormatter.format_fixed(entry["value"])
		if entry["skipped"]:
			lines.append("[color=#ff7b7b]✖ %s 미발동[/color]" % source)
		elif source == "원시 눈금":
			lines.append("[b]눈금 %s[/b]" % op)
		elif op.begins_with("면 "):
			lines.append("[color=#9aa0b4]%s[/color]" % source)
		elif source.contains(" → "):
			lines.append("[color=#c9a0ff]↻ %s[/color] %s = %s" % [source.get_slice(" → ", 0), op, value_text])
		else:
			lines.append("%s = %s%s" % [op, value_text, " [color=#ffae57](1로 보정)[/color]" if entry["clamped"] else ""])
	if result.final_value % FixedNum.SCALE != 0:
		lines.append("[color=#9aa0b4]반올림 → %d[/color]" % result.summon_value)
	return "\n".join(lines)


func _dice_tooltip(dice: DiceInstance) -> String:
	var names: PackedStringArray = []
	for inst: EnchantInstance in dice.get_enchants():
		names.append(inst.get_display_name())
	var faces: String = str(dice.data.faces) if dice.data.faces.size() <= 8 else "1 ~ %d" % dice.data.faces.size()
	var outcomes: Dictionary = dice.preview_outcomes(session.get_round())
	var low: int = FixedNum.MAX
	var high: int = 0
	for f: int in outcomes.keys():
		low = mini(low, outcomes[f])
		high = maxi(high, outcomes[f])
	return "%s\n면: %s\n인첸트: %s\n예상 범위 %s ~ %s" % [
		dice.data.display_name, faces, " → ".join(names) if names.size() > 0 else "없음",
		NumberFormatter.format_num(low), NumberFormatter.format_num(high)]
