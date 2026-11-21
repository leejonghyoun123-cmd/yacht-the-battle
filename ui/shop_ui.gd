extends Control
## 상점 화면 (배치는 예시 이미지 기준, 크기·간격은 UiConfig에서 조정)
##   [식량축적] [성질변환][성질변환][다면주사위][다면주사위] [가방]
##   [성벽증축] [타로/아이템][타로/아이템] [인첸트][인첸트][인첸트]
##   [판매][리롤]   [ 내 주사위 + 가방 (DiceBar) ]   [돌아가기]
## 판매: 내 주사위/인첸트를 클릭해 선택 → [판매]. 인첸트 구매: 상품 클릭 → 빈 슬롯 클릭.

signal back_requested

const ItemIcon: GDScript = preload("res://ui/widgets/item_icon.gd")
const DiceBar: GDScript = preload("res://ui/widgets/dice_bar.gd")

var session: GameSession
var tooltip: Node

var _fixed_col: VBoxContainer
var _row1: HBoxContainer
var _row2: HBoxContainer
var _message: Label
var _sell_button: Button
var _reroll_button: Button
var _dice_bar: VBoxContainer
var _pending_offer: ShopOffer = null
var _confirm: ConfirmationDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = UiConfig.COLOR_SHOP_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", UiConfig.TOP_BAR_HEIGHT + 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	margin.add_child(main)

	# 진열대
	var shelf: HBoxContainer = HBoxContainer.new()
	shelf.alignment = BoxContainer.ALIGNMENT_CENTER
	shelf.add_theme_constant_override("separation", UiConfig.SHOP_FIXED_COLUMN_GAP)
	main.add_child(shelf)
	_fixed_col = VBoxContainer.new()
	_fixed_col.add_theme_constant_override("separation", UiConfig.SHOP_ROW_GAP)
	shelf.add_child(_fixed_col)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", UiConfig.SHOP_ROW_GAP)
	shelf.add_child(rows)
	_row1 = HBoxContainer.new()
	_row1.add_theme_constant_override("separation", UiConfig.SHOP_COLUMN_GAP)
	rows.add_child(_row1)
	_row2 = HBoxContainer.new()
	_row2.add_theme_constant_override("separation", UiConfig.SHOP_COLUMN_GAP)
	rows.add_child(_row2)

	_message = UiKit.label("", 15, UiConfig.COLOR_ACCENT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(_message)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(spacer)

	# 하단: 판매·리롤 | 내 주사위 바 | 돌아가기
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	main.add_child(bottom)
	var left_buttons: VBoxContainer = VBoxContainer.new()
	left_buttons.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_child(left_buttons)
	_sell_button = _big_button("판매", UiConfig.COLOR_SELL)
	_sell_button.pressed.connect(_on_sell_pressed)
	left_buttons.add_child(_sell_button)
	_reroll_button = _big_button("리롤", UiConfig.COLOR_REROLL)
	_reroll_button.pressed.connect(func() -> void: _show_message(_result_text(session.shop.reroll(), "새 상품이 진열되었습니다")))
	left_buttons.add_child(_reroll_button)

	var bar_panel: PanelContainer = PanelContainer.new()
	var bar_style: StyleBoxFlat = StyleBoxFlat.new()
	bar_style.bg_color = UiConfig.COLOR_BAR_BG
	bar_style.set_content_margin_all(8)
	bar_style.set_corner_radius_all(4)
	bar_panel.add_theme_stylebox_override("panel", bar_style)
	bar_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bar_panel)
	_dice_bar = DiceBar.new()
	_dice_bar.set("session", session)
	_dice_bar.set("tooltip", tooltip)
	_dice_bar.connect("selection_changed", _refresh_buttons)
	_dice_bar.connect("slot_target_chosen", _on_slot_target_chosen)
	_dice_bar.connect("dice_target_chosen", _on_dice_target_chosen)
	bar_panel.add_child(_dice_bar)

	var back: Button = _big_button("돌아가기", UiConfig.COLOR_BACK)
	back.custom_minimum_size = Vector2(150, 110)
	back.pressed.connect(func() -> void:
		_cancel_buy_mode()
		back_requested.emit())
	bottom.add_child(back)

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
	UiKit.clear(_fixed_col)
	_fixed_col.add_child(_offer_card(shop.food))
	_fixed_col.add_child(_offer_card(shop.wall))
	UiKit.clear(_row1)
	for o: ShopOffer in shop.dice_offers:
		_row1.add_child(_offer_card(o))
	_row1.add_child(_offer_card(shop.bag))
	UiKit.clear(_row2)
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

func _offer_card(offer: ShopOffer) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = UiConfig.SHOP_CARD_SIZE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.18)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(4)
	if offer != null and offer == _pending_offer:
		style.border_color = UiConfig.COLOR_TARGET
		style.set_border_width_all(3)
	card.add_theme_stylebox_override("panel", style)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	if offer == null:
		var done: Label = UiKit.label("가방\n최고 등급", 13, UiConfig.COLOR_DIM)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(done)
		return card

	var price_text: String = "준비 중" if offer.is_locked() else ("판매됨" if offer.sold else "%s원" % NumberFormatter.format_num(offer.price))
	var price: Label = UiKit.label(price_text, 15, Color("ffe08a") if offer.is_available() else UiConfig.COLOR_DIM)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(price)
	var icon: Control = ItemIcon.new()
	icon.custom_minimum_size = UiConfig.SHOP_ICON_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_setup_icon(icon, offer)
	box.add_child(icon)
	var title: Label = UiKit.label(offer.title, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if not offer.is_available():
		card.modulate = Color(1, 1, 1, 0.45)
	else:
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_on_offer_pressed(offer))
	if tooltip != null:
		tooltip.call("attach", card, func() -> String: return _offer_tooltip(offer))
	return card


func _setup_icon(icon: Control, offer: ShopOffer) -> void:
	match offer.kind:
		ShopOffer.Kind.FOOD:
			icon.call("setup", "food")
		ShopOffer.Kind.WALL:
			icon.call("setup", "wall")
		ShopOffer.Kind.DICE:
			icon.call("setup", "dice", String(offer.dice_data.id), Color("f4f1e8"))
		ShopOffer.Kind.BAG:
			icon.set("size_level", offer.bag_tier + 1)
			icon.call("setup", "bag")
		ShopOffer.Kind.ENCHANT:
			icon.call("setup", "enchant", offer.enchant_data.get_icon_text(), UiConfig.rarity_color(int(offer.enchant_data.rarity)))
		ShopOffer.Kind.TRAIT:
			icon.call("setup", "dice", offer.trait_data.badge, UiConfig.rarity_color(int(offer.trait_data.rank)))
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
		_show_message("구매를 취소했습니다")
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
	if offer.kind == ShopOffer.Kind.TRAIT:
		# 성질 변환: 변환할 주사위(초록 테두리)를 고른다
		_pending_offer = offer
		_dice_bar.set("trait_targets", session.shop.get_trait_targets(offer.trait_data))
		_dice_bar.set("show_reserve", true)
		_dice_bar.call("refresh")
		_show_message("[%s] 변환할 주사위(초록 테두리)를 클릭하세요. 상품을 다시 누르면 취소." % offer.title)
		refresh()
		return
	_show_message(_result_text(session.shop.buy(offer), "%s 구매!" % offer.title))


func _on_slot_target_chosen(dice: DiceInstance, slot: int) -> void:
	if _pending_offer == null:
		return
	var offer: ShopOffer = _pending_offer
	_cancel_buy_mode()
	_show_message(_result_text(session.shop.buy(offer, dice, slot), "%s 장착 완료!" % offer.title))


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
		_show_message("인첸트 판매 +%d원" % gold if gold >= 0 else session.shop.can_sell_enchant(dice, slot))
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
	_show_message("주사위 판매 +%d원" % gold if gold >= 0 else session.shop.can_sell_dice(dice))
	_dice_bar.call("clear_selection")


# --- 헬퍼 -------------------------------------------------------------------

func _show_message(text: String) -> void:
	_message.text = text


func _result_text(reason: String, success: String) -> String:
	return success if reason == "" else reason


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
	_show_message(_result_text(session.shop.buy(offer, dice), "%s 변환 완료!" % offer.title))
