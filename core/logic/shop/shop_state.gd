class_name ShopState
extends RefCounted
## 상점 (UI 없는 순수 로직). 진열 배치는 예시 이미지 기준:
##   윗줄: 식량축적(상시) | 주사위 4칸(성질 변환 2 + 다면 주사위 2) | 가방(다음 등급)
##   아랫줄: 성벽증축(상시) | 타로/유저 아이템 2칸 | 인첸트 3칸
## 성질 변환·타로·유저 아이템 칸은 해당 시스템 단계 전까지 잠김.
## 구매·판매는 실패 사유 문자열을 반환한다 ("" = 성공).

signal changed

const DICE_OFFER_COUNT: int = 4
const TRAIT_OFFER_COUNT: int = 2
const RANK_NAMES: Array[String] = ["C", "B", "A", "S"]
const SPECIAL_OFFER_COUNT: int = 2
const ENCHANT_OFFER_COUNT: int = 3

var player: PlayerState
var deck: DeckManager
var rng: RandomNumberGenerator

var food: ShopOffer
var wall: ShopOffer
var dice_offers: Array[ShopOffer] = []
var bag: ShopOffer = null
var special_offers: Array[ShopOffer] = []
var enchant_offers: Array[ShopOffer] = []
## 이번 라운드 무료 리롤 (5연패 이상)
var free_reroll: bool = false
var round_number: int = 1


## 보유 아이템·타로 (GameSession이 넣어 준다)
var inventory: Inventory = null
## 마지막 구매 알림 (아이템 획득 문구 등)
var last_message: String = ""
## 아이템·타로 획득 처리 (GameSession.acquire_item / acquire_tarot)
var acquire_item_cb: Callable
var acquire_tarot_cb: Callable


func _init(p_player: PlayerState, p_deck: DeckManager, p_rng: RandomNumberGenerator) -> void:
	player = p_player
	deck = p_deck
	rng = p_rng


# =========================================================================
# 진열
# =========================================================================

## 새 라운드 진열 (식량·성벽은 상시, 나머지는 랜덤)
func restock(p_round: int) -> void:
	round_number = p_round
	food = _make(ShopOffer.Kind.FOOD, GameBalance.FOOD_PRICE, "식량축적", "최대 체력 +%d (최대 %d), 늘어난 만큼 회복" % [GameBalance.FOOD_MAX_HP_BONUS, GameBalance.MAX_HP_CAP])
	wall = _make(ShopOffer.Kind.WALL, GameBalance.WALL_PRICE, "성벽증축", "이번 라운드 피격 피해를 %d만큼 막는 임시 실드" % get_wall_shield())
	reroll_count = 0
	_roll_random_offers()
	_refresh_bag_offer()
	changed.emit()


## 이번 라운드 유료 리롤 횟수 (할수록 비싸진다)
var reroll_count: int = 0


## 리롤: 랜덤 칸(주사위·인첸트·특수)만 새로 진열
func reroll() -> String:
	if not free_reroll:
		if not player.spend_gold(get_reroll_cost()):
			return "골드가 부족합니다"
		reroll_count += 1
	else:
		free_reroll = false
	_roll_random_offers()
	changed.emit()
	return ""


## 다음 리롤 가격: 25 → 50 → 75원… (무료 리롤이 있으면 0)
func get_reroll_cost() -> int:
	if free_reroll:
		return 0
	return GameBalance.SHOP_REROLL_BASE_COST + reroll_count * GameBalance.SHOP_REROLL_COST_STEP


func get_wall_shield() -> int:
	return GameBalance.WALL_SHIELD_BASE + round_number * GameBalance.WALL_SHIELD_PER_ROUND


func _roll_random_offers() -> void:
	dice_offers.clear()
	# 성질 변환 칸 2개: 성질 풀에서 등급 가중치로 추첨 (같은 성질 중복 없음)
	var traits: Array[DiceTraitData] = ShopCatalog.trait_pool(round_number)
	for i: int in range(TRAIT_OFFER_COUNT):
		if not traits.is_empty():
			var t: DiceTraitData = _pick_by_rank(traits, func(x: DiceTraitData) -> int: return int(x.rank))
			traits.erase(t)
			var t_offer: ShopOffer = _make(ShopOffer.Kind.TRAIT, ShopCatalog.trait_price(t), t.display_name,
				"[%s등급 성질]\n%s\n구매 후 변환할 주사위를 고르세요" % [RANK_NAMES[int(t.rank)], t.description])
			t_offer.trait_data = t
			dice_offers.append(t_offer)
		else:
			dice_offers.append(_make(ShopOffer.Kind.TRAIT_LOCKED, 0, "성질 변환", "주사위 성질 단계에서 추가됩니다"))
	var dice_keys: Array = GameBalance.DICE_SHOP_WEIGHTS.keys()
	var dice_weights: Array = GameBalance.DICE_SHOP_WEIGHTS.values()
	for i: int in range(DICE_OFFER_COUNT - TRAIT_OFFER_COUNT):
		var id: StringName = ShopCatalog.pick_weighted(dice_keys, dice_weights, rng)
		var data: DiceData = ShopCatalog.load_dice(id)
		var offer: ShopOffer = _make(ShopOffer.Kind.DICE, ShopCatalog.dice_price(data), data.display_name, "면: %s\n구매하면 가방(예비 슬롯)에 들어갑니다" % _faces_text(data))
		offer.dice_data = data
		dice_offers.append(offer)

	special_offers.clear()
	# 타로 1칸 + 유저 아이템 1칸
	var rank_names: Array[String] = RANK_NAMES
	var tarots: Array[TarotCardData] = ShopCatalog.tarot_pool(round_number)
	if tarots.is_empty():
		special_offers.append(_make(ShopOffer.Kind.SPECIAL_LOCKED, 0, "타로", "진열할 카드가 없습니다"))
	else:
		var tc: TarotCardData = _pick_by_rank(tarots, func(x: TarotCardData) -> int: return int(x.rank))
		var t_off: ShopOffer = _make(ShopOffer.Kind.TAROT, ShopCatalog.tarot_price(tc), tc.display_name,
			"[%s · %s등급 타로]\n%s" % [TarotCardData.roman(tc.numeral), rank_names[int(tc.rank)], tc.description])
		t_off.tarot_data = tc
		special_offers.append(t_off)
	var item_pool: Array[UserItemData] = []
	for d: UserItemData in ShopCatalog.item_pool(round_number):
		if d.stackable or inventory == null or not inventory.owns_item(d.id):
			item_pool.append(d)
	if item_pool.is_empty():
		special_offers.append(_make(ShopOffer.Kind.SPECIAL_LOCKED, 0, "아이템", "진열할 아이템이 없습니다"))
	else:
		var it: UserItemData = _pick_by_rank(item_pool, func(x: UserItemData) -> int: return int(x.rank))
		var i_off: ShopOffer = _make(ShopOffer.Kind.ITEM, ShopCatalog.item_price(it), it.display_name,
			"[%s등급 아이템]\n%s%s" % [rank_names[int(it.rank)], it.description, "\n구매 후 적용할 주사위를 고르세요" if it.target == UserItemData.Target.DICE else ""])
		i_off.item_data = it
		special_offers.append(i_off)

	enchant_offers.clear()
	var pool: Array[EnchantData] = ShopCatalog.enchant_pool(round_number)
	var weights: Array = []
	for e: EnchantData in pool:
		weights.append(GameBalance.ENCHANT_RARITY_WEIGHTS[int(e.rarity)])
	for i: int in range(ENCHANT_OFFER_COUNT):
		if pool.is_empty():
			break
		var data: EnchantData = ShopCatalog.pick_weighted(pool, weights, rng)
		var offer: ShopOffer = _make(ShopOffer.Kind.ENCHANT, ShopCatalog.enchant_price(data), data.display_name, data.description + "\n구매 시 주사위 빈 슬롯에 바로 장착")
		offer.enchant_data = data
		enchant_offers.append(offer)


func _refresh_bag_offer() -> void:
	var next_tier: int = get_current_bag_tier() + 1
	if next_tier >= GameBalance.BAG_TIERS.size():
		bag = null
		return
	var info: Dictionary = GameBalance.BAG_TIERS[next_tier]
	bag = _make(ShopOffer.Kind.BAG, info["price"], info["name"], "가방(예비 슬롯) %d칸으로 확장. 지금 가방과 교체됩니다 (판매 불가)" % info["slots"])
	bag.bag_tier = next_tier


## 현재 가방 등급 (-1 = 기본 2칸)
func get_current_bag_tier() -> int:
	var tier: int = -1
	for i: int in range(GameBalance.BAG_TIERS.size()):
		if deck.reserve_unlocked >= int(GameBalance.BAG_TIERS[i]["slots"]):
			tier = i
	return tier


func get_bag_name() -> String:
	var tier: int = get_current_bag_tier()
	return "기본 주머니" if tier < 0 else String(GameBalance.BAG_TIERS[tier]["name"])


func _make(kind: ShopOffer.Kind, price: int, title: String, desc: String) -> ShopOffer:
	var o: ShopOffer = ShopOffer.new()
	o.kind = kind
	o.price = price
	o.base_price = price
	o.title = title
	o.description = desc
	return o


static func _faces_text(data: DiceData) -> String:
	if data.faces.size() <= 8:
		return str(data.faces)
	return "1 ~ %d" % data.faces.size()


# =========================================================================
# 구매
# =========================================================================

## 구매 가능 여부 ("" = 가능). 인첸트는 장착할 빈 슬롯도 확인.
func can_buy(offer: ShopOffer) -> String:
	if offer == null or offer.is_locked():
		return "아직 준비 중인 상품입니다"
	if offer.sold:
		return "이미 판매된 상품입니다"
	if not player.can_afford(offer.price):
		return "골드가 부족합니다"
	match offer.kind:
		ShopOffer.Kind.FOOD:
			if player.max_hp >= GameBalance.MAX_HP_CAP:
				return "최대 체력이 이미 상한(%d)입니다" % GameBalance.MAX_HP_CAP
		ShopOffer.Kind.DICE:
			if not deck.has_reserve_space():
				return "가방에 빈칸이 없습니다"
		ShopOffer.Kind.ENCHANT:
			if not deck.has_free_enchant_slot():
				return "빈 인첸트 슬롯이 없습니다 — 인첸트를 판매해 자리를 만드세요"
		ShopOffer.Kind.TRAIT:
			if get_trait_targets(offer.trait_data).is_empty():
				return offer.trait_data.get_missing_text()
		ShopOffer.Kind.TAROT:
			if inventory != null and not inventory.has_tarot_space():
				return "타로 손패가 가득 찼습니다 (최대 %d장)" % Inventory.MAX_TAROT_HAND
		ShopOffer.Kind.ITEM:
			if offer.item_data.target == UserItemData.Target.DICE:
				if get_item_targets(offer.item_data).is_empty():
					return "이 아이템을 쓸 수 있는 주사위가 없습니다"
			elif inventory != null and not inventory.has_item_space():
				return "아이템 칸이 가득 찼습니다 (최대 %d개)" % Inventory.MAX_ITEMS
	return ""


## 아이템을 적용할 수 있는 내 주사위
func get_item_targets(data: UserItemData) -> Array[DiceInstance]:
	var out: Array[DiceInstance] = []
	for d: DiceInstance in deck.all_dice():
		if d != null and data.can_apply_to(d):
			out.append(d)
	return out


## 대상 주사위를 골라야 하는 상품인가 (화면이 주사위 선택 연출을 띄운다)
func needs_dice_target(offer: ShopOffer) -> bool:
	return offer.kind == ShopOffer.Kind.TRAIT or (offer.kind == ShopOffer.Kind.ITEM and offer.item_data.target == UserItemData.Target.DICE)


func get_offer_targets(offer: ShopOffer) -> Array[DiceInstance]:
	if offer.kind == ShopOffer.Kind.TRAIT:
		return get_trait_targets(offer.trait_data)
	if offer.kind == ShopOffer.Kind.ITEM:
		return get_item_targets(offer.item_data)
	return []


## 이 성질로 변환할 수 있는 내 주사위 (이번 라운드에 굴린 주사위 제외)
func get_trait_targets(t: DiceTraitData) -> Array[DiceInstance]:
	var out: Array[DiceInstance] = []
	for d: DiceInstance in deck.all_dice():
		if d != null and deck.can_edit_dice(d) and t.can_attach_to(d):
			out.append(d)
	return out


static func _trait_requirement(t: DiceTraitData) -> String:
	return t.get_requirement_text()


## 구매. 인첸트는 target_dice / target_slot(빈 슬롯) 지정 필수.
func buy(offer: ShopOffer, target_dice: DiceInstance = null, target_slot: int = -1, picks: Array = []) -> String:
	var reason: String = can_buy(offer)
	if reason != "":
		return reason
	match offer.kind:
		ShopOffer.Kind.ENCHANT:
			if target_dice == null or not deck.can_edit_dice(target_dice):
				return "이번 라운드에 굴린 주사위에는 장착할 수 없습니다"
			if target_slot < 0 or target_slot >= target_dice.unlocked_slots or target_dice.slots[target_slot] != null:
				return "빈 슬롯을 골라 주세요"
			player.spend_gold(offer.price)
			deck.equip_enchant(target_dice, target_slot, EnchantInstance.new(offer.enchant_data))
		ShopOffer.Kind.TRAIT:
			if target_dice == null or not get_trait_targets(offer.trait_data).has(target_dice):
				return "이 주사위는 변환할 수 없습니다 (%s)" % _trait_requirement(offer.trait_data)
			player.spend_gold(offer.price)
			target_dice.attach_trait(offer.trait_data, rng)
		ShopOffer.Kind.TAROT:
			player.spend_gold(offer.price)
			acquire_tarot_cb.call(offer.tarot_data)
		ShopOffer.Kind.ITEM:
			if offer.item_data.target == UserItemData.Target.DICE and (target_dice == null or not get_item_targets(offer.item_data).has(target_dice)):
				return "이 주사위에는 쓸 수 없습니다"
			player.spend_gold(offer.price)
			last_message = String(acquire_item_cb.call(offer.item_data, target_dice, picks))
		ShopOffer.Kind.DICE:
			player.spend_gold(offer.price)
			deck.add_to_reserve(DiceInstance.new(offer.dice_data))
		ShopOffer.Kind.FOOD:
			player.spend_gold(offer.price)
			player.increase_max_hp(GameBalance.FOOD_MAX_HP_BONUS)
		ShopOffer.Kind.WALL:
			player.spend_gold(offer.price)
			player.round_shield += get_wall_shield()
		ShopOffer.Kind.BAG:
			player.spend_gold(offer.price)
			deck.set_reserve_slots(int(GameBalance.BAG_TIERS[offer.bag_tier]["slots"]))
	if offer.is_repeatable():
		# 식량·성벽: 같은 라운드에 또 사면 점점 비싸진다 (다음 라운드에 원래 가격)
		offer.purchase_count += 1
		offer.price = offer.base_price + offer.purchase_count * GameBalance.REPEAT_PURCHASE_STEP
	else:
		offer.sold = true
	if offer.kind == ShopOffer.Kind.BAG:
		_refresh_bag_offer()
	changed.emit()
	return ""


# =========================================================================
# 판매
# =========================================================================

## 주사위 판매 가능 여부 ("" = 가능)
func can_sell_dice(dice: DiceInstance) -> String:
	if not deck.can_edit_dice(dice):
		return "이번 라운드에 굴린 주사위는 판매할 수 없습니다"
	if deck.active.has(dice):
		if deck.is_deck_locked:
			return "굴림이 시작된 뒤에는 출전 주사위를 바꿀 수 없습니다"
		if deck.first_reserve_index() < 0:
			return "가방에 대신 출전할 주사위가 없습니다"
	return ""


## 주사위 판매 (끼워진 인첸트 판매가 합산). 받은 골드 반환, 실패 시 -1.
func sell_dice(dice: DiceInstance) -> int:
	if can_sell_dice(dice) != "":
		return -1
	var gold: int = ShopCatalog.dice_sell_value(dice)
	if not deck.remove_dice(dice):
		return -1
	player.add_gold(gold, PlayerState.GoldSource.OTHER)
	changed.emit()
	return gold


func can_sell_enchant(dice: DiceInstance, slot: int) -> String:
	if not deck.can_edit_dice(dice):
		return "이번 라운드에 굴린 주사위의 인첸트는 뺄 수 없습니다"
	if slot < 0 or slot >= dice.unlocked_slots or dice.slots[slot] == null:
		return "판매할 인첸트가 없습니다"
	return ""


func sell_enchant(dice: DiceInstance, slot: int) -> int:
	if can_sell_enchant(dice, slot) != "":
		return -1
	var removed: EnchantInstance = deck.remove_enchant(dice, slot)
	if removed == null:
		return -1
	var gold: int = ShopCatalog.sell_value(ShopCatalog.enchant_price(removed.data))
	player.add_gold(gold, PlayerState.GoldSource.OTHER)
	changed.emit()
	return gold


## 등급 가중치 추첨 (낮은 등급일수록 자주): GameBalance.ENCHANT_RARITY_WEIGHTS 재사용
func _pick_by_rank(pool: Array, rank_of: Callable) -> Variant:
	var weights: Array = []
	for x: Variant in pool:
		weights.append(GameBalance.ENCHANT_RARITY_WEIGHTS[clampi(int(rank_of.call(x)), 0, 3)])
	return ShopCatalog.pick_weighted(pool, weights, rng)
