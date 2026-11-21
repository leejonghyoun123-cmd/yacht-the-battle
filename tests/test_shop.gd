extends SceneTree
## Step 4a 상점·타이머·주사위별 잠금 검증.
## 실행: godot --headless --path <프로젝트> --script res://tests/test_shop.gd

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	print("===== 야추 더 배틀 Step 4a 상점 테스트 =====")
	_test_stock()
	_test_buy()
	_test_enchant_rules()
	_test_sell()
	_test_timer_and_auto()
	_test_shield()
	print("===== 결과: 통과 %d / 실패 %d =====" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		print("  PASS  ", label)
	else:
		_fail_count += 1
		print("  FAIL  ", label, ("  → " + detail) if detail != "" else "")


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, label, "기대 %s, 실제 %s" % [str(expected), str(actual)])


func _session(gold: int = 5000) -> GameSession:
	var s: GameSession = GameSession.new(31)
	s.player.gold = gold
	return s


func _test_stock() -> void:
	print("[진열]")
	var s: GameSession = _session()
	var shop: ShopState = s.shop
	_eq(shop.dice_offers.size(), 4, "주사위 4칸")
	_eq(shop.dice_offers[0].kind, ShopOffer.Kind.TRAIT_LOCKED, "1·2칸 = 성질 변환 (잠김)")
	_eq(shop.dice_offers[2].kind, ShopOffer.Kind.DICE, "3·4칸 = 다면 주사위")
	_eq(shop.special_offers.size(), 2, "타로/아이템 2칸 (잠김)")
	_eq(shop.enchant_offers.size(), 3, "인첸트 3칸")
	_check(shop.food != null and shop.wall != null, "식량축적·성벽증축 상시 진열")
	_eq(shop.bag.title, "작은 가방", "가방은 다음 등급(작은 가방)")
	var round1_ok: bool = true
	for i: int in range(30):
		shop.reroll()
		for o: ShopOffer in shop.enchant_offers:
			if o.enchant_data.min_unlock_round > 1:
				round1_ok = false
	_check(round1_ok, "1R에는 100-X(7R 해금) 미등장")
	_eq(StarterDeck.D6, "res://data/dice/d6.tres", "시작 덱 6면")
	_check(s.deck.get_enchants_count() == 0 if s.deck.has_method("get_enchants_count") else s.deck.active[0].get_enchants().is_empty(), "시작 덱: 인첸트 없음")
	_eq(s.deck.first_reserve_index(), -1, "시작 덱: 예비 칸 비어 있음")
	var gold: int = s.player.gold
	_eq(shop.reroll(), "", "리롤")
	_eq(gold - s.player.gold, GameBalance.SHOP_REROLL_COST, "리롤 비용 차감")
	shop.free_reroll = true
	shop.reroll()
	_eq(gold - s.player.gold, GameBalance.SHOP_REROLL_COST, "무료 리롤은 비용 없음")


func _test_buy() -> void:
	print("[구매]")
	var s: GameSession = _session()
	var shop: ShopState = s.shop
	var dice_offer: ShopOffer = shop.dice_offers[2]
	var gold: int = s.player.gold
	_eq(shop.buy(dice_offer), "", "다면 주사위 구매")
	_eq(gold - s.player.gold, dice_offer.price, "가격 차감")
	_check(s.deck.reserve[0] != null and s.deck.reserve[0].data == dice_offer.dice_data, "가방(예비)에 들어감")
	_check(dice_offer.sold, "판매 완료 표시")
	_check(shop.buy(dice_offer) != "", "같은 상품 재구매 불가")
	shop.buy(shop.dice_offers[3])
	shop.reroll()
	var full: ShopOffer = shop.dice_offers[2]
	_eq(shop.can_buy(full), "가방에 빈칸이 없습니다", "가방(2칸) 가득 차면 주사위 구매 불가")
	_eq(shop.buy(shop.bag), "", "작은 가방 구매")
	_eq(s.deck.reserve_unlocked, 3, "예비 3칸")
	_eq(shop.bag.title, "중간 가방", "다음 등급 가방 진열")
	_eq(shop.get_bag_name(), "작은 가방", "보유 가방 이름")
	_eq(shop.can_buy(full), "", "가방 확장 후 주사위 구매 가능")
	var hp_max: int = s.player.max_hp
	shop.buy(shop.food)
	_eq(s.player.max_hp, hp_max + 50, "식량축적: 최대 체력 +50")
	_eq(shop.food.price, GameBalance.FOOD_PRICE + GameBalance.REPEAT_PURCHASE_STEP, "식량축적 재구매 시 +100원")
	var g2: int = s.player.gold
	shop.buy(shop.food)
	_eq(g2 - s.player.gold, GameBalance.FOOD_PRICE + 100, "두 번째 구매는 250원")
	_eq(shop.food.price, GameBalance.FOOD_PRICE + 200, "세 번째는 350원")
	shop.restock(2)
	_eq(shop.food.price, GameBalance.FOOD_PRICE, "다음 라운드에 원래 가격")
	s.player.gold = 0
	_eq(shop.can_buy(shop.wall), "골드가 부족합니다", "골드 부족")
	_check(shop.can_buy(shop.special_offers[0]) != "", "잠긴 칸(타로/아이템)은 구매 불가")


func _test_enchant_rules() -> void:
	print("[인첸트 장착 규칙]")
	var s: GameSession = _session()
	var shop: ShopState = s.shop
	var offer: ShopOffer = shop.enchant_offers[0]
	var d0: DiceInstance = s.deck.active[0]
	_check(shop.buy(offer, d0, -1) != "", "슬롯 지정 없이 구매 불가")
	_eq(shop.buy(offer, d0, 0), "", "주사위1 슬롯1에 구매·장착")
	_check(d0.slots[0] != null and d0.slots[0].data == offer.enchant_data, "장착 확인")
	var d1: DiceInstance = s.deck.active[1]
	_check(s.deck.transfer_enchant(d0, 0, d1, 2), "굴리기 전: 다른 주사위로 인첸트 이동")
	_check(d0.slots[0] == null and d1.slots[2] != null, "이동 결과")
	s.go_to_rolling()
	s.flow.roll()
	_check(not s.deck.transfer_enchant(d1, 2, d0, 0), "굴린 뒤: 굴린 주사위 인첸트 이동 불가")
	_check(not s.deck.move_enchant(d1, 2, 0), "굴린 뒤: 순서 변경 불가")
	shop.buy(shop.dice_offers[2])
	var bag_dice: DiceInstance = s.deck.reserve[0]
	shop.reroll()
	var e2: ShopOffer = shop.enchant_offers[0]
	_check(shop.buy(e2, d0, 1) != "", "굴린 주사위에는 새 인첸트 장착 불가")
	_eq(shop.buy(e2, bag_dice, 0), "", "가방 속(안 굴린) 주사위에는 장착 가능")
	_check(s.deck.move_enchant(bag_dice, 0, 1), "가방 속 주사위는 굴린 뒤에도 순서 변경 가능")
	# 빈 슬롯이 하나도 없으면 인첸트 구매 불가
	var s2: GameSession = _session()
	for d: DiceInstance in s2.deck.all_dice():
		for i: int in range(d.unlocked_slots):
			d.equip(EnchantInstance.new(load("res://data/enchants/add_common.tres")), i)
	_eq(s2.shop.can_buy(s2.shop.enchant_offers[0]), "빈 인첸트 슬롯이 없습니다 — 인첸트를 판매해 자리를 만드세요", "빈 슬롯 없으면 구매 불가 안내")


func _test_sell() -> void:
	print("[판매]")
	var s: GameSession = _session()
	var shop: ShopState = s.shop
	var d0: DiceInstance = s.deck.active[0]
	_check(shop.can_sell_dice(d0) != "", "가방에 대체 주사위가 없으면 출전 주사위 판매 불가")
	shop.buy(shop.dice_offers[2])
	var spare: DiceInstance = s.deck.reserve[0]
	var add3: EnchantData = load("res://data/enchants/add_common.tres")
	var mul2: EnchantData = load("res://data/enchants/mul_uncommon.tres")
	d0.equip(EnchantInstance.new(add3), 0)
	d0.equip(EnchantInstance.new(mul2), 1)
	var expected: int = ShopCatalog.sell_value(60) + ShopCatalog.sell_value(100) + ShopCatalog.sell_value(200)
	_eq(ShopCatalog.dice_sell_value(d0), expected, "주사위 판매가 = 주사위 + 인첸트 합산 (30+50+100)")
	var gold: int = s.player.gold
	_eq(shop.sell_dice(d0), expected, "인첸트 끼운 출전 주사위 판매")
	_eq(s.player.gold - gold, expected, "판매 골드 지급")
	_check(s.deck.active[0] == spare and s.deck.reserve[0] == null, "가방의 주사위가 출전 자리를 채움")
	spare.equip(EnchantInstance.new(add3), 0)
	_eq(shop.sell_enchant(spare, 0), ShopCatalog.sell_value(100), "인첸트만 판매 (반값)")
	_check(spare.slots[0] == null, "인첸트 제거됨")
	s.go_to_rolling()
	s.flow.roll()
	spare.equip(EnchantInstance.new(add3), 1)
	_check(shop.can_sell_enchant(spare, 1) != "", "굴린 주사위의 인첸트는 판매 불가")


func _test_timer_and_auto() -> void:
	print("[타이머 · 시간 만료 자동 진행]")
	var t: RoundTimer = RoundTimer.new()
	t.reset()
	_eq(t.get_text(), "1:30", "기본 1분 30초")
	_check(t.extend(), "30초 연장")
	_eq(t.get_text(), "2:00", "연장 후 2:00")
	_check(not t.extend(), "라운드당 1회만 연장")
	var fired: Array[bool] = [false]
	t.expired.connect(func() -> void: fired[0] = true)
	t.tick(121.0)
	_check(fired[0] and not t.running, "0이 되면 만료 신호")

	var s: GameSession = _session()
	var sim: BattleSimulation = s.auto_finalize()
	_check(sim != null and s.phase == GameSession.Phase.BATTLE, "연병장 상태에서 만료 → 자동 굴림·기록·배치·전투")
	_check(s.yacht.recorded.size() == 1, "얏츠판 1항목 자동 기록")
	var placed_ok: bool = true
	for sm: Dictionary in s.summons:
		if not sm["placed"] or sm["unit_id"] != &"sword":
			placed_ok = false
	_check(placed_ok, "남은 주사위는 소드로 자동 소환")
	_check(not s.board.cells[0].is_empty() and not s.board.cells[0].is_stack, "소비칸에 소환")
	sim.run_to_end()
	s.settle_battle()
	s.return_to_barracks()
	_check(s.timer.running and s.timer.get_text() == "1:30" and not s.timer.extended, "다음 라운드 타이머·연장 초기화")


func _test_shield() -> void:
	print("[성벽증축 실드]")
	var s: GameSession = _session()
	s.shop.buy(s.shop.wall)
	var shield: int = s.shop.get_wall_shield()
	_eq(s.player.round_shield, shield, "임시 실드 %d" % shield)
	var lose: BattleResult = BattleResult.new()
	lose.winner = 1
	lose.survivor_totals = [0.0, 50.0]
	var hp: int = s.player.hp
	var summary: Dictionary = BattleSettlement.settle_solo(lose, s.player, s.board, s.streak, 1)
	_eq(summary["shield_absorbed"], shield, "실드가 먼저 막음")
	_eq(s.player.hp, hp - (50 - shield), "남은 피해만 체력 감소")
