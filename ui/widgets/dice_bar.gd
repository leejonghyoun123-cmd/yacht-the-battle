extends VBoxContainer
## 내 주사위 바: 출전 주사위 5개(각각 아래에 동그란 인첸트 슬롯) + 가방.
## - 주사위 클릭: 선택 + 인첸트 슬롯 확대 패널 표시
## - 슬롯 클릭: 인첸트 선택 → 다른 슬롯 클릭 시 이동/맞바꿈 (이번 라운드에 굴린 주사위는 불가)
## - 가방 클릭: 가방 속 주사위 표시
## - buy_mode: 상점 인첸트 구매 중 → 빈 슬롯 클릭 시 slot_target_chosen
## 상점·연병장 등 여러 화면에서 재사용한다.

signal selection_changed
signal slot_target_chosen(dice: DiceInstance, slot: int)
## 성질 변환 구매 중 주사위를 고름
signal dice_target_chosen(dice: DiceInstance)

const ItemIcon: GDScript = preload("res://ui/widgets/item_icon.gd")
const SlotRow: GDScript = preload("res://ui/widgets/slot_row.gd")

var session: GameSession
var tooltip: Node
var selected_dice: DiceInstance = null
var selected_slot: int = -1
var buy_mode: bool = false
## 성질 변환 구매 중: 변환 가능한 주사위만 강조, 클릭 시 dice_target_chosen
var trait_targets: Array[DiceInstance] = []
var show_reserve: bool = false

var _reserve_panel: PanelContainer
var _reserve_row: HBoxContainer
var _detail_panel: PanelContainer
var _detail_box: VBoxContainer
var _main_row: HBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	# 가방 속 주사위와 확대 슬롯은 나란히 (세로로 쌓으면 화면 아래로 넘친다)
	var upper: HBoxContainer = HBoxContainer.new()
	upper.add_theme_constant_override("separation", 6)
	add_child(upper)
	_reserve_panel = _panel(Color(0.16, 0.13, 0.1, 0.95))
	_reserve_row = HBoxContainer.new()
	_reserve_row.add_theme_constant_override("separation", 8)
	_reserve_panel.add_child(_reserve_row)
	upper.add_child(_reserve_panel)
	_detail_panel = _panel(Color(0.1, 0.11, 0.15, 0.95))
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box = VBoxContainer.new()
	_detail_panel.add_child(_detail_box)
	upper.add_child(_detail_panel)
	_main_row = HBoxContainer.new()
	_main_row.add_theme_constant_override("separation", 10)
	_main_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_main_row)
	refresh()


func clear_selection() -> void:
	selected_dice = null
	selected_slot = -1
	selection_changed.emit()
	refresh()


func refresh() -> void:
	if session == null or _main_row == null:
		return
	var deck: DeckManager = session.deck
	if selected_dice != null and not deck.all_dice().has(selected_dice):
		selected_dice = null
		selected_slot = -1
	UiKit.clear(_main_row)
	for i: int in range(deck.active.size()):
		_main_row.add_child(_dice_widget(deck.active[i], "출전 %d" % (i + 1)))
	_main_row.add_child(_bag_widget())

	UiKit.clear(_reserve_row)
	_reserve_panel.visible = show_reserve
	if show_reserve:
		_reserve_row.add_child(UiKit.label("%s\n(%d칸)" % [session.shop.get_bag_name(), deck.reserve_unlocked], 12, UiConfig.COLOR_ACCENT))
		for i: int in range(deck.reserve_unlocked):
			if deck.reserve[i] == null:
				var empty: Control = UiKit.label("빈칸", 12, UiConfig.COLOR_DIM)
				empty.custom_minimum_size = Vector2(UiConfig.DICE_ICON_SIZE.x + 30, UiConfig.DICE_ICON_SIZE.y)
				empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				_reserve_row.add_child(empty)
			else:
				_reserve_row.add_child(_dice_widget(deck.reserve[i], "가방 %d" % (i + 1)))

	UiKit.clear(_detail_box)
	_detail_panel.visible = selected_dice != null
	if selected_dice != null:
		var locked: bool = not deck.can_edit_dice(selected_dice)
		var hint: String = "이번 라운드에 굴린 주사위 — 인첸트 고정" if locked else "인첸트 선택 → 다른 슬롯 클릭으로 이동"
		_detail_box.add_child(UiKit.label("%s  ·  %s" % [selected_dice.data.display_name, hint], 12, UiConfig.COLOR_DIM))
		var big: Control = SlotRow.new()
		big.set("show_names", true)
		big.call("setup", selected_dice, UiConfig.SLOT_RADIUS_LARGE, tooltip)
		_configure_row(big, selected_dice)
		_detail_box.add_child(big)


func _dice_widget(dice: DiceInstance, caption: String) -> Control:
	var editable: bool = session.deck.can_edit_dice(dice)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var ring: Color = UiConfig.COLOR_SELECTED if dice == selected_dice and selected_slot < 0 else Color.TRANSPARENT
	if trait_targets.has(dice):
		ring = UiConfig.COLOR_TARGET
	var icon_holder: PanelContainer = _panel(Color(0, 0, 0, 0.0), ring)
	icon_holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon: Control = ItemIcon.new()
	icon.custom_minimum_size = UiConfig.DICE_ICON_SIZE
	icon.call("setup", "dice", _dice_short(dice), Color("f4f1e8") if editable else Color("b9b6ae"))
	icon_holder.add_child(icon)
	icon_holder.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_on_dice_pressed(dice))
	if tooltip != null:
		tooltip.call("attach", icon_holder, func() -> String: return _dice_tooltip(dice))
	box.add_child(icon_holder)
	var cap: Label = UiKit.label(caption, 11, Color(0.15, 0.15, 0.18))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	var row: Control = SlotRow.new()
	row.call("setup", dice, UiConfig.SLOT_RADIUS, tooltip)
	_configure_row(row, dice)
	box.add_child(row)
	return box


func _configure_row(row: Control, dice: DiceInstance) -> void:
	row.set("locked", not session.deck.can_edit_dice(dice))
	row.set("highlight_empty", buy_mode)
	row.set("selected_slot", selected_slot if dice == selected_dice else -1)
	row.connect("slot_pressed", func(slot: int) -> void: _on_slot_pressed(dice, slot))


func _bag_widget() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	var holder: PanelContainer = _panel(Color(0, 0, 0, 0), UiConfig.COLOR_SELECTED if show_reserve else Color.TRANSPARENT)
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon: Control = ItemIcon.new()
	icon.custom_minimum_size = UiConfig.DICE_ICON_SIZE + Vector2(16, 8)
	icon.set("size_level", session.shop.get_current_bag_tier() + 1)
	icon.call("setup", "bag")
	holder.add_child(icon)
	holder.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			show_reserve = not show_reserve
			refresh.call_deferred())
	if tooltip != null:
		tooltip.call("attach", holder, func() -> String:
			var used: int = 0
			for d: DiceInstance in session.deck.reserve:
				if d != null:
					used += 1
			return "%s (%d/%d칸)\n클릭하면 가방 속 주사위를 봅니다.\n가방은 판매할 수 없고, 더 좋은 가방을 사면 교체됩니다." % [
				session.shop.get_bag_name(), used, session.deck.reserve_unlocked])
	box.add_child(holder)
	var cap: Label = UiKit.label("가방", 11, Color(0.15, 0.15, 0.18))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	return box


func _on_dice_pressed(dice: DiceInstance) -> void:
	if not trait_targets.is_empty():
		if trait_targets.has(dice):
			dice_target_chosen.emit(dice)
		return
	if selected_dice == dice and selected_slot < 0:
		selected_dice = null
	else:
		selected_dice = dice
	selected_slot = -1
	selection_changed.emit()
	refresh.call_deferred()


func _on_slot_pressed(dice: DiceInstance, slot: int) -> void:
	var deck: DeckManager = session.deck
	if not trait_targets.is_empty():
		_on_dice_pressed(dice)
		return
	if buy_mode:
		if deck.can_edit_dice(dice) and slot < dice.unlocked_slots and dice.slots[slot] == null:
			slot_target_chosen.emit(dice, slot)
		return
	# 인첸트를 고른 상태에서 다른 슬롯을 누르면 이동(대상에 있으면 맞바꿈)
	if selected_dice != null and selected_slot >= 0 and not (selected_dice == dice and selected_slot == slot):
		if deck.transfer_enchant(selected_dice, selected_slot, dice, slot):
			selected_dice = dice
			selected_slot = -1
			selection_changed.emit()
			refresh.call_deferred()
			return
	selected_dice = dice
	selected_slot = slot if (slot < dice.unlocked_slots and dice.slots[slot] != null) else -1
	selection_changed.emit()
	refresh.call_deferred()


func _dice_short(dice: DiceInstance) -> String:
	return dice.get_short_name()


func _dice_tooltip(dice: DiceInstance) -> String:
	var names: PackedStringArray = []
	for inst: EnchantInstance in dice.get_enchants():
		names.append(inst.get_display_name())
	var base_faces: Array[int] = dice.get_modified_faces()
	var faces: String = str(base_faces) if base_faces.size() <= 8 else "%d ~ %d" % [base_faces.min(), base_faces.max()]
	if dice.trait_data != null:
		faces += "\n성질: %s %s" %[dice.trait_data.display_name, dice.get_short_name()]
	var lock_note: String = "\n이번 라운드에 굴린 주사위 — 인첸트 고정" if not session.deck.can_edit_dice(dice) else ""
	return "%s\n면: %s\n인첸트: %s\n판매가 %d원 (인첸트 포함)%s" % [
		dice.data.display_name, faces, " → ".join(names) if names.size() > 0 else "없음",
		ShopCatalog.dice_sell_value(dice), lock_note]


func _panel(bg: Color, border: Color = Color.TRANSPARENT) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", style)
	return p
