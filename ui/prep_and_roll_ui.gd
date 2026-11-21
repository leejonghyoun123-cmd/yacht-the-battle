extends Control
## Step 2 준비·굴림 화면 (프로토타입, 기본 Control 노드만 사용).
## 화면을 구성하는 노드는 모두 이 스크립트가 코드로 만든다.
## → 씬에는 루트 Control 하나에 이 스크립트만 붙이면 되므로 인스펙터 연결 누락이 생기지 않는다.
## 로직(RoundFlow·DeckManager·YachtBoard)은 UI를 모르고, UI는 시그널을 받아 다시 그리기만 한다.

## 0이면 실행할 때마다 무작위 시드
@export var fixed_seed: int = 0

const COLOR_BG: Color = Color("1b1d24")
const COLOR_PANEL: Color = Color("272a35")
const COLOR_CARD: Color = Color("323645")
const COLOR_SELECTED: Color = Color("f2c14e")
const COLOR_HELD: Color = Color("4f8a5b")
const COLOR_TEXT_DIM: Color = Color("9aa0b4")
const COLOR_GOOD: Color = Color("7bd88f")

var flow: RoundFlow
var selected_index: int = 0

# --- 동적으로 다시 채우는 컨테이너 ---
var _round_label: Label
var _gold_label: Label
var _hp_label: Label
var _boss_label: Label
var _active_row: HBoxContainer
var _enchant_box: VBoxContainer
var _yacht_box: VBoxContainer
var _reserve_row: HBoxContainer
var _swap_button: Button
var _roll_button: Button
var _next_button: Button
var _status_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_setup_logic()
	_build_layout()
	flow.changed.connect(_queue_refresh)
	flow.deck.deck_changed.connect(_queue_refresh)
	flow.player.gold_changed.connect(func(_g: int) -> void: _queue_refresh())
	_refresh()


var _refresh_queued: bool = false


## 버튼 시그널 처리 도중 그 버튼을 지우지 않도록, 다시 그리기는 프레임 끝으로 미룬다
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _setup_logic() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if fixed_seed != 0:
		rng.seed = fixed_seed
	else:
		rng.randomize()
	var deck: DeckManager = DeckManager.new()
	StarterDeck.build_into(deck)
	flow = RoundFlow.new(PlayerState.new(), deck, YachtBoard.new(), rng)


# =========================================================================
# 레이아웃 (1회 생성)
# =========================================================================

func _build_layout() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)

	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	margin.add_child(main)

	# 상단 바: 라운드 · 골드 · 체력 · 보스 예고
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	main.add_child(top)
	_round_label = _label("", 20)
	_gold_label = _label("", 20)
	_hp_label = _label("", 20)
	top.add_child(_round_label)
	top.add_child(_gold_label)
	top.add_child(_hp_label)
	var boss_panel: PanelContainer = _panel(Color("3a2630"))
	boss_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_label = _label("", 14)
	_boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_panel.add_child(_boss_label)
	top.add_child(boss_panel)

	# 진행 안내 (화면이 넘쳐도 잘리지 않도록 상단에 둔다)
	_status_label = _label("", 14, COLOR_SELECTED)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(_status_label)

	# 중앙: 왼쪽(활성 주사위 + 인첸트 패널) / 오른쪽(얏츠판)
	var middle: HBoxContainer = HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	main.add_child(middle)

	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	middle.add_child(left)
	left.add_child(_label("출전 주사위 (활성 5칸)", 15, COLOR_TEXT_DIM))
	_active_row = HBoxContainer.new()
	_active_row.add_theme_constant_override("separation", 6)
	_active_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_active_row)
	var enchant_panel: PanelContainer = _panel(COLOR_PANEL)
	_enchant_box = VBoxContainer.new()
	_enchant_box.add_theme_constant_override("separation", 0)
	enchant_panel.add_child(_enchant_box)
	left.add_child(enchant_panel)

	var yacht_panel: PanelContainer = _panel(COLOR_PANEL)
	yacht_panel.custom_minimum_size = Vector2(250, 0)
	_yacht_box = VBoxContainer.new()
	_yacht_box.add_theme_constant_override("separation", 3)
	yacht_panel.add_child(_yacht_box)
	middle.add_child(yacht_panel)

	# 하단: 예비 슬롯 + 버튼
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	main.add_child(bottom)
	var reserve_title: Label = _label("예비\n슬롯", 13, COLOR_TEXT_DIM)
	bottom.add_child(reserve_title)
	_reserve_row = HBoxContainer.new()
	_reserve_row.add_theme_constant_override("separation", 6)
	_reserve_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_reserve_row)

	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(190, 0)
	bottom.add_child(buttons)
	_swap_button = _button("덱 스왑 (활성 ↔ 예비)")
	_swap_button.pressed.connect(func() -> void: flow.deck.swap_active_and_reserve())
	_roll_button = _button("굴림")
	_roll_button.add_theme_font_size_override("font_size", 18)
	_roll_button.pressed.connect(func() -> void: flow.roll())
	_next_button = _button("다음 라운드 ▶ (임시)")
	_next_button.pressed.connect(_on_next_round)
	buttons.add_child(_swap_button)
	buttons.add_child(_roll_button)
	buttons.add_child(_next_button)


# =========================================================================
# 갱신 (로직 시그널마다 호출)
# =========================================================================

func _refresh() -> void:
	_refresh_queued = false
	if _active_row == null:
		return
	var locked: bool = flow.deck.is_deck_locked
	_round_label.text = "라운드 %d / %d" % [flow.round_number, LevelTable.FINAL_ROUND]
	_gold_label.text = "골드 %s" % NumberFormatter.format_num(flow.player.gold)
	_hp_label.text = "체력 %d / %d" % [flow.player.hp, flow.player.max_hp]
	_boss_label.text = _boss_text()

	_rebuild_active_cards()
	_rebuild_enchant_panel()
	_rebuild_yacht_board()
	_rebuild_reserve()

	_swap_button.disabled = locked
	_next_button.disabled = flow.phase != RoundFlow.Phase.RECORDED
	match flow.phase:
		RoundFlow.Phase.PREP:
			_roll_button.text = "굴림"
			_roll_button.disabled = false
			_status_label.text = "준비 단계: 인첸트 순서를 바꾸거나 예비 주사위와 교체한 뒤 [굴림]을 누르세요. 굴리면 덱이 잠깁니다."
		RoundFlow.Phase.ROLLING:
			_roll_button.text = "재굴림 (%d회 남음)" % flow.rerolls_left
			_roll_button.disabled = not flow.can_roll()
			_status_label.text = "[고정]할 주사위를 고르고 재굴림하거나, 오른쪽 얏츠판 항목을 눌러 확정·기록하세요 (매 라운드 1항목 필수)."
		RoundFlow.Phase.RECORDED:
			_roll_button.text = "확정됨"
			_roll_button.disabled = true
			var cat_name: String = YachtBoard.CATEGORY_NAMES[flow.recorded_category]
			_status_label.text = "%s 기록 완료: +%s원. 소환값 %s → (Step 3에서 병과 선택·배치·전투 연결 예정)" % [
				cat_name, NumberFormatter.format_num(flow.recorded_gold), str(flow.get_summon_values())]


func _boss_text() -> String:
	var info: Dictionary = LevelTable.get_upcoming_boss(flow.round_number)
	if info.is_empty():
		return "보스 정보 없음"
	var when: String = "이번 라운드!" if info["rounds_left"] == 0 else "%d라운드 후" % info["rounds_left"]
	return "⚠ %dR 보스 [%s] (%s)\n%s" % [info["round"], info["name"], when, info["gimmick"]]


func _rebuild_active_cards() -> void:
	_clear(_active_row)
	for i: int in range(flow.deck.active.size()):
		_active_row.add_child(_make_active_card(i))


func _make_active_card(index: int) -> Control:
	var dice: DiceInstance = flow.deck.active[index]
	var result: DiceRollResult = flow.results[index] if index < flow.results.size() else null
	var held: bool = flow.held[index]
	var border: Color = COLOR_SELECTED if index == selected_index else Color.TRANSPARENT
	var card: PanelContainer = _panel(COLOR_HELD if held else COLOR_CARD, border)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	box.add_child(_label("주사위%d · %s" % [index + 1, dice.data.display_name], 13, COLOR_TEXT_DIM))

	var value_text: String = "-" if result == null else NumberFormatter.format_num(result.summon_value)
	var value_label: Label = _label(value_text, 30)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value_label)

	var steps: RichTextLabel = RichTextLabel.new()
	steps.bbcode_enabled = true
	steps.fit_content = true
	steps.scroll_active = false
	steps.add_theme_font_size_override("normal_font_size", 12)
	steps.add_theme_font_size_override("bold_font_size", 12)
	steps.text = _steps_bbcode(result) if result != null else "[color=#9aa0b4]%s[/color]" % _enchant_summary(dice)
	steps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(steps)

	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	var hold_button: Button = _button("고정됨" if held else "고정")
	hold_button.disabled = flow.phase != RoundFlow.Phase.ROLLING
	hold_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hold_button.pressed.connect(func() -> void: flow.toggle_hold(index))
	row.add_child(hold_button)
	var select_button: Button = _button("인첸트")
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_button.pressed.connect(func() -> void:
		selected_index = index
		_refresh())
	row.add_child(select_button)
	return card


## 연산 로그 → 여러 줄 BBCode. 메아리 발동·미발동이 확실히 보이도록 표기한다.
func _steps_bbcode(result: DiceRollResult) -> String:
	var lines: PackedStringArray = []
	for entry: Dictionary in result.logs:
		var source: String = entry["source"]
		var op: String = entry["op"]
		var value_text: String = NumberFormatter.format_fixed(entry["value"])
		if entry["skipped"]:
			lines.append("[color=#ff7b7b]✖ %s 미발동[/color]\n[color=#ff7b7b]  (%s)[/color]" % [source, entry["reason"]])
		elif source == "원시 눈금":
			lines.append("[b]눈금 %s[/b]" % op)
		elif op.begins_with("면 "):
			lines.append("[color=#9aa0b4]%s %s[/color]" % [source, op])
		elif source.contains(" → "):
			# 복사 발동: "메아리 → 합연산 +3" 중 복사한 쪽 이름만 표기하고 연산은 그대로 보여준다
			lines.append("[color=#c9a0ff]↻ %s[/color] %s = %s" % [source.get_slice(" → ", 0), op, value_text])
		else:
			var clamp_text: String = " [color=#ffae57](1로 보정)[/color]" if entry["clamped"] else ""
			lines.append("%s = %s%s" % [op, value_text, clamp_text])
	if result.summon_value != FixedNum.round_to_int(result.final_value):
		lines.append("[color=#9aa0b4]최소 1 보정[/color]")
	elif result.final_value % FixedNum.SCALE != 0:
		lines.append("[color=#9aa0b4]반올림 → %d[/color]" % result.summon_value)
	return "\n".join(lines)


func _rebuild_enchant_panel() -> void:
	_clear(_enchant_box)
	var dice: DiceInstance = flow.deck.active[selected_index]
	var locked: bool = flow.deck.is_deck_locked
	var title: String = "주사위%d 인첸트 슬롯 (위→아래 순서로 연산)" % (selected_index + 1)
	if locked:
		title += "  — 굴림 후에는 순서 변경 불가"
	_enchant_box.add_child(_label(title, 14, COLOR_SELECTED))
	for slot: int in range(dice.unlocked_slots):
		var row: HBoxContainer = HBoxContainer.new()
		_enchant_box.add_child(row)
		var inst: EnchantInstance = dice.slots[slot]
		var name_label: Label = _label("슬롯 %d: %s" % [slot + 1, inst.get_display_name() if inst != null else "(비어 있음)"], 13)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var up: Button = _button("▲")
		up.disabled = locked or slot == 0
		up.pressed.connect(func() -> void: flow.deck.move_enchant(dice, slot, slot - 1))
		row.add_child(up)
		var down: Button = _button("▼")
		down.disabled = locked or slot >= dice.unlocked_slots - 1
		down.pressed.connect(func() -> void: flow.deck.move_enchant(dice, slot, slot + 1))
		row.add_child(down)
	var locked_slots: int = DiceInstance.MAX_SLOTS - dice.unlocked_slots
	if locked_slots > 0:
		_enchant_box.add_child(_label("잠긴 슬롯 %d칸 (조각칼/핸드드릴로 개방)" % locked_slots, 12, COLOR_TEXT_DIM))
	_enchant_box.add_child(_label(_preview_text(dice), 12, COLOR_TEXT_DIM))


## 면별 예상 소환값과 범위 (슬롯 순서를 바꿀 때마다 즉시 갱신)
func _preview_text(dice: DiceInstance) -> String:
	var outcomes: Dictionary = dice.preview_outcomes(flow.round_number)
	var parts: PackedStringArray = []
	var low: int = FixedNum.MAX
	var high: int = 0
	for face: int in outcomes.keys():
		var v: int = outcomes[face]
		low = mini(low, v)
		high = maxi(high, v)
		if parts.size() < 10:
			parts.append("%d→%s" % [face, NumberFormatter.format_num(v)])
	var more: String = " …" if outcomes.size() > 10 else ""
	return "예상 범위 %s ~ %s   |   %s%s" % [
		NumberFormatter.format_num(low), NumberFormatter.format_num(high), ", ".join(parts), more]


func _rebuild_yacht_board() -> void:
	_clear(_yacht_box)
	var board: YachtBoard = flow.board
	_yacht_box.add_child(_label("얏츠판 (1의 자리 판정)", 16, COLOR_SELECTED))
	_yacht_box.add_child(_label("프레스티지 %d · 보상 ×%d · %d/10칸" % [
		board.prestige_level, board.get_reward_multiplier(), board.recorded.size()], 12, COLOR_TEXT_DIM))
	if flow.has_rolled():
		_yacht_box.add_child(_label("1의 자리: " + str(YachtBoard.to_digits(flow.get_summon_values())), 12, COLOR_TEXT_DIM))
	var preview: Dictionary = flow.get_yacht_preview()
	for category: int in YachtBoard.Category.values():
		var cat_name: String = YachtBoard.CATEGORY_NAMES[category]
		var button: Button = _button("")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if board.is_recorded(category):
			button.text = "✔ %s  %s원" % [cat_name, NumberFormatter.format_num(board.recorded[category])]
			button.disabled = true
		elif preview.has(category):
			var gold: int = preview[category]
			button.text = "%s  →  %s원" % [cat_name, NumberFormatter.format_num(gold)]
			if gold > 0:
				button.add_theme_color_override("font_color", COLOR_GOOD)
			button.disabled = flow.phase != RoundFlow.Phase.ROLLING
		else:
			button.text = cat_name
			button.disabled = true
		button.pressed.connect(func() -> void: flow.record_yacht(category))
		_yacht_box.add_child(button)


func _rebuild_reserve() -> void:
	_clear(_reserve_row)
	var deck: DeckManager = flow.deck
	for i: int in range(GameBalance.MAX_RESERVE_SLOTS):
		var card: PanelContainer = _panel(COLOR_CARD)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 64)
		var box: VBoxContainer = VBoxContainer.new()
		card.add_child(box)
		if i >= deck.reserve_unlocked:
			box.add_child(_label("예비 %d\n(잠김 · 가방으로 개방)" % (i + 1), 12, COLOR_TEXT_DIM))
		elif deck.reserve[i] == null:
			box.add_child(_label("예비 %d\n(비어 있음)" % (i + 1), 12, COLOR_TEXT_DIM))
		else:
			var dice: DiceInstance = deck.reserve[i]
			box.add_child(_label("예비 %d · %s" % [i + 1, dice.data.display_name], 12))
			box.add_child(_label(_enchant_summary(dice), 11, COLOR_TEXT_DIM))
			var swap: Button = _button("주사위%d와 교체" % (selected_index + 1))
			swap.disabled = deck.is_deck_locked
			swap.pressed.connect(func() -> void: deck.swap_slots(selected_index, i))
			box.add_child(swap)
		_reserve_row.add_child(card)


func _on_next_round() -> void:
	flow.advance_round()


# =========================================================================
# 헬퍼
# =========================================================================

func _enchant_summary(dice: DiceInstance) -> String:
	var names: PackedStringArray = []
	for inst: EnchantInstance in dice.get_enchants():
		names.append(inst.get_display_name())
	return "인첸트 없음" if names.is_empty() else " → ".join(names)


func _label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	return b


func _panel(bg: Color, border: Color = Color.TRANSPARENT) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", style)
	return p


func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
