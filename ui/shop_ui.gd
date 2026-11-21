extends Control
## 상점 화면 (예시 이미지의 구성: 왼쪽 간판·버튼 열 + 오른쪽 테두리 진열대. 크기·간격은 UiConfig)
##   [간판 "상점"]   | [식량축적]  [성질변환][성질변환][다면주사위][다면주사위] [가방]
##   [알림]          | [성벽증축]  [타로][아이템] [인첸트][인첸트][인첸트]
##   [판매][리롤]    |
##   [돌아가기]      | [ 내 주사위 + 가방 (DiceBar) ]
##   상품마다 위에 가격표(꼬리표)가 걸린다 (ui/widgets/price_tag.gd)
## 판매: 내 주사위/인첸트를 클릭해 선택 → [판매]. 인첸트 구매: 상품 클릭 → 빈 슬롯 클릭.

signal back_requested

const ItemIcon: GDScript = preload("res://ui/widgets/item_icon.gd")
const DiceBar: GDScript = preload("res://ui/widgets/dice_bar.gd")
const DicePickOverlay: GDScript = preload("res://ui/widgets/dice_pick_overlay.gd")
const ChoicePopup: GDScript = preload("res://ui/widgets/choice_popup.gd")
const PriceTag: GDScript = preload("res://ui/widgets/price_tag.gd")
const ShopSign: GDScript = preload("res://ui/widgets/shop_sign.gd")

var session: GameSession
var tooltip: Node

var _row1: HBoxContainer
var _row2: HBoxContainer
## 화면 가운데에 잠깐 뜨는 알림 (골드 부족은 크게, 그 외 실패·안내는 작게)
var _toast: PanelContainer = null
var _toast_tween: Tween = null
const GOLD_SHORT_TEXT: String = "소지골드가 부족합니다."
const TOAST_HOLD: float = 1.1
var _sell_button: Button
var _reroll_button: Button
var _dice_bar: VBoxContainer
var _pending_offer: ShopOffer = null
var _confirm: ConfirmationDialog
var _pick_overlay: Control
var _choice_popup: Control
## 대상 주사위 + 단계별 선택 중인 값 (사포와펜)
var _pick_dice: DiceInstance = null
var _pick_values: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = UiConfig.COLOR_SHOP_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 배경 무늬 (옅은 사선)
	var pattern: Control = Control.new()
	pattern.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pattern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pattern.draw.connect(func() -> void:
		var step: float = 36.0
		var n: int = int((pattern.size.x + pattern.size.y) / step) + 1
		for i: int in range(n):
			var x: float = float(i) * step
			pattern.draw_line(Vector2(x, 0), Vector2(x - pattern.size.y, pattern.size.y), Color(1, 1, 1, 0.025), 10.0))
	add_child(pattern)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", UiConfig.TOP_BAR_HEIGHT + 8)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var main: HBoxContainer = HBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	margin.add_child(main)

	# 왼쪽 열: 간판 · 알림 · [판매] [리롤] [돌아가기]
	var side: VBoxContainer = VBoxContainer.new()
	side.custom_minimum_size = Vector2(UiConfig.SHOP_SIDE_WIDTH, 0)
	side.add_theme_constant_override("separation", 10)
	main.add_child(side)
	side.add_child(ShopSign.new())
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	var money_row: HBoxContainer = HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 10)
	side.add_child(money_row)
	_sell_button = _big_button("판매", UiConfig.COLOR_SELL)
	_sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_button.custom_minimum_size = Vector2(0, 76)
	_sell_button.pressed.connect(_on_sell_pressed)
	money_row.add_child(_sell_button)
	_reroll_button = _big_button("리롤", UiConfig.COLOR_REROLL)
	_reroll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reroll_button.custom_minimum_size = Vector2(0, 76)
	_reroll_button.pressed.connect(func() -> void: _show_message(session.shop.reroll()))
	money_row.add_child(_reroll_button)
	var back: Button = _big_button("돌아가기", UiConfig.COLOR_BACK)
	back.custom_minimum_size = Vector2(0, 84)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func() -> void:
		_cancel_buy_mode()
		back_requested.emit())
	side.add_child(back)

	# 오른쪽: 붉은 테두리 진열대 (2줄) + 아래 내 주사위 바
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	main.add_child(right)
	var frame: PanelContainer = PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.07, 0.1, 0.1, 0.75)
	frame_style.border_color = UiConfig.SHOP_FRAME_COLOR
	frame_style.set_border_width_all(4)
	frame_style.set_corner_radius_all(14)
	frame_style.content_margin_left = 16
	frame_style.content_margin_right = 16
	frame_style.content_margin_top = 8
	frame_style.content_margin_bottom = 12
	frame.add_theme_stylebox_override("panel", frame_style)
	right.add_child(frame)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", UiConfig.SHOP_ROW_GAP)
	frame.add_child(rows)
	_row1 = HBoxContainer.new()
	_row1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row1.add_theme_constant_override("separation", UiConfig.SHOP_COLUMN_GAP)
	rows.add_child(_row1)
	_row2 = HBoxContainer.new()
	_row2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row2.add_theme_constant_override("separation", UiConfig.SHOP_COLUMN_GAP)
	rows.add_child(_row2)

	var bar_panel: PanelContainer = PanelContainer.new()
	var bar_style: StyleBoxFlat = StyleBoxFlat.new()
	bar_style.bg_color = UiConfig.COLOR_BAR_BG
	bar_style.set_content_margin_all(8)
	bar_style.set_corner_radius_all(10)
	bar_panel.add_theme_stylebox_override("panel", bar_style)
	right.add_child(bar_panel)
	_dice_bar = DiceBar.new()
	_dice_bar.set("session", session)
	_dice_bar.set("tooltip", tooltip)
	_dice_bar.connect("selection_changed", _refresh_buttons)
	_dice_bar.connect("slot_target_chosen", _on_slot_target_chosen)
	_dice_bar.connect("dice_target_chosen", _on_dice_target_chosen)
	bar_panel.add_child(_dice_bar)

	_pick_overlay = DicePickOverlay.new()
	add_child(_pick_overlay)
	_pick_overlay.connect("chosen", _on_pick_chosen)
	_pick_overlay.connect("cancelled", func() -> void:
		_pending_offer = null
		refresh())

	_choice_popup = ChoicePopup.new()
	add_child(_choice_popup)
	_choice_popup.connect("chosen", func(v: Variant) -> void:
		_pick_values.append(v)
		_continue_pick())
	_choice_popup.connect("cancelled", func() -> void:
		_pick_overlay.call("close")
		_pending_offer = null
		refresh())

	_confirm = ConfirmationDialog.new()
	_confirm.title = "판매 확인"
	_confirm.ok_button_text = "판매"
	_confirm.cancel_button_text = "취소"
	_confirm.confirmed.connect(_sell_selected_dice)
	add_child(_confirm)

	session.shop.changed.connect(refresh)
	session.deck.deck_changed.connect(refresh)
	session.player.gold_changed.connect(func(_g: int) -> void: refresh())
	refresh()


func refresh() -> void:
	if _row1 == null or not is_inside_tree():
		return
	_refresh.call_deferred()


func _refresh() -> void:
	var shop: ShopState = session.shop
	# 각 줄 첫 칸은 상시 상품(식량·성벽), 조금 띄우고 나머지
	UiKit.clear(_row1)
	_row1.add_child(_offer_card(shop.food))
	_row1.add_child(_fixed_gap())
	for o: ShopOffer in shop.dice_offers:
		_row1.add_child(_offer_card(o))
	_row1.add_child(_offer_card(shop.bag))
	UiKit.clear(_row2)
	_row2.add_child(_offer_card(shop.wall))
	_row2.add_child(_fixed_gap())
	for o: ShopOffer in shop.special_offers:
		_row2.add_child(_offer_card(o))
	for o: ShopOffer in shop.enchant_offers:
		_row2.add_child(_offer_card(o))
	_dice_bar.call("refresh")
	_refresh_buttons()


func _refresh_buttons() -> void:
	var shop: ShopState = session.shop
	_reroll_button.text = "무료 리롤" if shop.free_reroll else "리롤\n%d원" % shop.get_reroll_cost()
	var dice: DiceInstance = _dice_bar.get("selected_dice")
	var slot: int = _dice_bar.get("selected_slot")
	if dice == null:
		_sell_button.text = "판매"
		_sell_button.disabled = true
	elif slot >= 0:
		_sell_button.text = "판매\n+%d원" % ShopCatalog.sell_value(ShopCatalog.enchant_price(dice.slots[slot].data))
		_sell_button.disabled = shop.can_sell_enchant(dice, slot) != ""
	else:
		_sell_button.text = "판매\n+%d원" % ShopCatalog.dice_sell_value(dice)
		_sell_button.disabled = shop.can_sell_dice(dice) != ""


# --- 상품 카드 --------------------------------------------------------------

## 상품 카드: 위에 가격표가 걸리고, 아래 진열 카드(종류별 색 띠 + 큰 아이콘 + 이름)
func _offer_card(offer: ShopOffer) -> Control:
	var holder: VBoxContainer = VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override("separation", -10)
	# 가격표 자리 (카드 위로 살짝 걸침)
	var tag_row: CenterContainer = CenterContainer.new()
	tag_row.custom_minimum_size = Vector2(0, UiConfig.SHOP_TAG_SIZE.y + 4)
	tag_row.z_index = 1
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tag_row)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = UiConfig.SHOP_CARD_SIZE
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var accent: Color = _offer_color(offer)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = UiConfig.SHOP_CARD_BG
	style.set_corner_radius_all(12)
	style.content_margin_top = 16
	style.content_margin_bottom = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.border_color = accent
	style.set_border_width_all(2)
	style.border_width_top = 6
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 4)
	if offer != null and offer == _pending_offer:
		style.border_color = UiConfig.COLOR_TARGET
		style.set_border_width_all(4)
	card.add_theme_stylebox_override("panel", style)
	holder.add_child(card)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	if offer == null:
		var done: Label = UiKit.label("가방\n최고 등급", 15, UiConfig.COLOR_DIM)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(done)
		return holder

	var tag: Control = PriceTag.new()
	var tag_state: int = PriceTag.TagState.LOCKED if offer.is_locked() else (PriceTag.TagState.SOLD if offer.sold else PriceTag.TagState.ON_SALE)
	tag.call("setup", "준비 중" if offer.is_locked() else ("판매됨" if offer.sold else "%s원" % NumberFormatter.format_num(offer.price)), tag_state)
	tag_row.add_child(tag)
	var icon: Control = ItemIcon.new()
	icon.custom_minimum_size = UiConfig.SHOP_ICON_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_setup_icon(icon, offer)
	box.add_child(icon)
	var title_bg: PanelContainer = UiKit.panel(Color(0, 0, 0, 0.35))
	(title_bg.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(3)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title: Label = UiKit.label(offer.title, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_bg.add_child(title)
	box.add_child(title_bg)
	if not offer.is_available():
		holder.modulate = Color(1, 1, 1, 0.45)
	else:
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_on_offer_pressed(offer))
		# 마우스를 올리면 살짝 떠오름
		card.mouse_entered.connect(func() -> void: _hover_card(holder, true))
		card.mouse_exited.connect(func() -> void: _hover_card(holder, false))
	if tooltip != null:
		tooltip.call("attach", card, func() -> String: return _offer_tooltip(offer))
	return holder


func _hover_card(holder: Control, on: bool) -> void:
	if not is_instance_valid(holder):
		return
	holder.pivot_offset = Vector2(holder.size.x * 0.5, holder.size.y)
	var tw: Tween = holder.create_tween()
	tw.tween_property(holder, "scale", Vector2.ONE * (1.04 if on else 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 상품 종류별 카드 윗띠 색
func _offer_color(offer: ShopOffer) -> Color:
	if offer == null:
		return Color("4a5a58")
	match offer.kind:
		ShopOffer.Kind.FOOD:
			return Color("c8964f")
		ShopOffer.Kind.WALL:
			return Color("9aa3a8")
		ShopOffer.Kind.DICE:
			return Color("e9e4d4")
		ShopOffer.Kind.BAG:
			return Color("a0683a")
		ShopOffer.Kind.TRAIT:
			return offer.trait_data.color
		ShopOffer.Kind.TAROT:
			return Color("9b7be0")
		ShopOffer.Kind.ITEM:
			return UiConfig.rarity_color(int(offer.item_data.rank))
		ShopOffer.Kind.ENCHANT:
			return UiConfig.rarity_color(int(offer.enchant_data.rarity))
	return Color("4a5a58")


func _fixed_gap() -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(maxi(0, UiConfig.SHOP_FIXED_COLUMN_GAP - UiConfig.SHOP_COLUMN_GAP * 2), 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _setup_icon(icon: Control, offer: ShopOffer) -> void:
	match offer.kind:
		ShopOffer.Kind.FOOD:
			icon.call("setup", "food")
		ShopOffer.Kind.WALL:
			icon.call("setup", "wall")
		ShopOffer.Kind.DICE:
			if offer.dice_data.faces.size() == 2:
				icon.call("setup", "coin", "2면")
			else:
				icon.call("setup", "dice", String(offer.dice_data.id), Color("f4f1e8"))
		ShopOffer.Kind.BAG:
			icon.set("size_level", offer.bag_tier + 1)
			icon.call("setup", "bag")
		ShopOffer.Kind.ENCHANT:
			icon.call("setup", "enchant", offer.enchant_data.get_icon_text(), UiConfig.rarity_color(int(offer.enchant_data.rarity)))
		ShopOffer.Kind.TRAIT:
			if offer.trait_data is PokerTrait:
				icon.set("suit", PokerTrait.SuitType.SPADE)
				icon.call("setup", "card", "A")
			else:
				icon.set("sub_text", offer.trait_data.badge)
				icon.set("sub_color", offer.trait_data.color)
				icon.call("setup", "dice", "성질", Color("f4f1e8").lerp(offer.trait_data.color, 0.35))
		ShopOffer.Kind.TAROT:
			icon.set("sub_text", offer.tarot_data.display_name)
			icon.call("setup", "tarot", TarotCardData.roman(offer.tarot_data.numeral))
		ShopOffer.Kind.ITEM:
			icon.call("setup", "item", offer.item_data.icon_text, UiConfig.rarity_color(int(offer.item_data.rank)))
		_:
			icon.call("setup", "locked")


func _offer_tooltip(offer: ShopOffer) -> String:
	var text: String = "%s\n%s" % [offer.title, offer.description]
	if offer.is_available():
		text += "\n가격 %d원" % offer.price
		var reason: String = session.shop.can_buy(offer)
		if reason != "":
			text += "\n⚠ " + reason
	return text


func _on_offer_pressed(offer: ShopOffer) -> void:
	if offer == _pending_offer:
		_cancel_buy_mode()
		return
	var reason: String = session.shop.can_buy(offer)
	if reason != "":
		_show_message(reason)
		return
	if offer.kind == ShopOffer.Kind.ENCHANT:
		# 인첸트는 인벤토리가 없으므로 장착할 빈 슬롯을 먼저 고른다
		_pending_offer = offer
		_dice_bar.set("buy_mode", true)
		_dice_bar.call("refresh")
		_show_message("[%s] 장착할 빈 슬롯(초록 테두리)을 클릭하세요. 상품을 다시 누르면 취소." % offer.title)
		refresh()
		return
	if session.shop.needs_dice_target(offer):
		# 성질 변환·대상 지정 아이템: 화면을 어둡게 덮고 고를 수 있는 주사위만 앞에 띄운다
		_pending_offer = offer
		var verb: String = "변환할" if offer.kind == ShopOffer.Kind.TRAIT else "적용할"
		_pick_overlay.call("open", "[%s] %s 주사위를 고르세요" % [offer.title, verb], session.shop.get_offer_targets(offer), session.deck)
		return
	var result: String = session.shop.buy(offer)
	session.shop.last_message = ""
	_show_message(result)


## 선택창에서 주사위를 고름 → 구매 → 성공하면 변환 연출
func _on_pick_chosen(dice: DiceInstance) -> void:
	_pick_dice = dice
	_pick_values = []
	_continue_pick()


## 주사위를 고른 뒤 단계별 선택지가 남아 있으면 팝업, 없으면 구매
func _continue_pick() -> void:
	var offer: ShopOffer = _pending_offer
	var dice: DiceInstance = _pick_dice
	if offer == null or dice == null:
		_pick_overlay.call("close")
		return
	if offer.kind == ShopOffer.Kind.ITEM:
		var choices: Array[Dictionary] = offer.item_data.get_dice_choices(dice, _pick_values)
		if not choices.is_empty():
			var step: String = "지울 숫자를 고르세요" if _pick_values.is_empty() else "그 자리에 새길 숫자를 고르세요"
			_choice_popup.call("open", "[%s] %s" % [offer.title, step], choices)
			return
	_pending_offer = null
	var result: String = session.shop.buy(offer, dice, -1, _pick_values)
	if result != "":
		_pick_overlay.call("close")
		_show_message(result)
		return
	var caption: String = "%s → %s!" % [dice.data.display_name, offer.title]
	if offer.kind == ShopOffer.Kind.TRAIT and dice.trait_data is PokerTrait:
		caption = "포커카드로 변환! (%s)" % (dice.trait_data as PokerTrait).get_state_text(dice)
	_pick_overlay.call("play_transform", dice, caption)
	session.shop.last_message = ""
	refresh()


func _on_slot_target_chosen(dice: DiceInstance, slot: int) -> void:
	if _pending_offer == null:
		return
	var offer: ShopOffer = _pending_offer
	_cancel_buy_mode()
	_show_message(session.shop.buy(offer, dice, slot))


func _cancel_buy_mode() -> void:
	_pending_offer = null
	_dice_bar.set("buy_mode", false)
	_dice_bar.set("trait_targets", [] as Array[DiceInstance])
	_dice_bar.call("refresh")
	refresh()


# --- 판매 -------------------------------------------------------------------

func _on_sell_pressed() -> void:
	var dice: DiceInstance = _dice_bar.get("selected_dice")
	var slot: int = _dice_bar.get("selected_slot")
	if dice == null:
		return
	if slot >= 0:
		var gold: int = session.shop.sell_enchant(dice, slot)
		if gold < 0:
			_show_message(session.shop.can_sell_enchant(dice, slot))
		_dice_bar.call("clear_selection")
		return
	var reason: String = session.shop.can_sell_dice(dice)
	if reason != "":
		_show_message(reason)
		return
	if not dice.get_enchants().is_empty():
		_confirm.dialog_text = "해당 주사위에는 인첸트가 끼워져 있습니다.\n정말 판매하시겠습니까?\n(인첸트 포함 +%d원)" % ShopCatalog.dice_sell_value(dice)
		_confirm.popup_centered()
		return
	_sell_selected_dice()


func _sell_selected_dice() -> void:
	var dice: DiceInstance = _dice_bar.get("selected_dice")
	if dice == null:
		return
	var gold: int = session.shop.sell_dice(dice)
	if gold < 0:
		_show_message(session.shop.can_sell_dice(dice))
	_dice_bar.call("clear_selection")


# --- 헬퍼 -------------------------------------------------------------------

## 구매·판매가 막혔을 때만 알린다 (성공한 행동은 기록하지 않음). "" = 알릴 것 없음.
func _show_message(text: String) -> void:
	if text == "":
		return
	if text == ShopState.GOLD_SHORT_MESSAGE:
		_flash_center(GOLD_SHORT_TEXT, true)
	else:
		_flash_center(text, false)


## 화면 가운데 알림: 튀어나오듯 커지고(골드 부족은 좌우로 흔들림) 잠시 뒤 사라진다
func _flash_center(text: String, big: bool) -> void:
	if _toast_tween != null:
		_toast_tween.kill()
	if _toast != null and is_instance_valid(_toast):
		_toast.queue_free()
	_toast = UiKit.panel(Color(0.12, 0.03, 0.03, 0.94) if big else Color(0.05, 0.06, 0.08, 0.92), UiConfig.SHOP_FRAME_COLOR if big else UiConfig.COLOR_ACCENT)
	var sb: StyleBoxFlat = _toast.get_theme_stylebox("panel") as StyleBoxFlat
	sb.set_border_width_all(4 if big else 2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 40 if big else 22
	sb.content_margin_right = sb.content_margin_left
	sb.content_margin_top = 22 if big else 12
	sb.content_margin_bottom = sb.content_margin_top
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 18
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.z_index = 50
	var l: Label = UiKit.label(text, 46 if big else 20, Color("ffdf6b") if big else Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 8 if big else 0)
	l.add_theme_color_override("font_outline_color", Color("5a1010"))
	_toast.add_child(l)
	add_child(_toast)
	_toast.reset_size()
	var center: Vector2 = size * 0.5 + (Vector2.ZERO if big else Vector2(0, 40))
	_toast.position = center - _toast.size * 0.5
	_toast.pivot_offset = _toast.size * 0.5
	_toast.scale = Vector2.ONE * 0.6
	_toast.modulate.a = 0.0
	var home: float = _toast.position.x
	var toast: Control = _toast
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.parallel().tween_property(toast, "modulate:a", 1.0, 0.12)
	if big:
		for k: int in range(4):
			var dx: float = (12.0 if k % 2 == 0 else -12.0) * (1.0 - float(k) * 0.2)
			_toast_tween.tween_property(toast, "position:x", home + dx, 0.05)
		_toast_tween.tween_property(toast, "position:x", home, 0.05)
	_toast_tween.tween_interval(TOAST_HOLD)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(toast.queue_free)


func _big_button(text: String, color: Color) -> Button:
	var b: Button = UiKit.button(text, 20)
	b.custom_minimum_size = Vector2(150, 52)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = color
		if state == "hover":
			sb.bg_color = color.lightened(0.15)
		elif state == "pressed":
			sb.bg_color = color.darkened(0.2)
		elif state == "disabled":
			sb.bg_color = color.darkened(0.45)
		sb.set_corner_radius_all(8)
		b.add_theme_stylebox_override(state, sb)
	return b


func _on_dice_target_chosen(dice: DiceInstance) -> void:
	if _pending_offer == null or _pending_offer.kind != ShopOffer.Kind.TRAIT:
		return
	var offer: ShopOffer = _pending_offer
	_cancel_buy_mode()
	_show_message(session.shop.buy(offer, dice))
