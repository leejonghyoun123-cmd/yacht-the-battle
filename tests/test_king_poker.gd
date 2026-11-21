extends SceneTree
## 중첩 특수능력(분기) · 킹 · 포커카드 검증
## 실행: godot --headless --path <프로젝트> --script res://tests/test_king_poker.gd

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	print("===== 분기·킹·포커카드 테스트 =====")
	_test_branches()
	_test_king_battle()
	_test_reflect()
	_test_poker_trait()
	_test_session_king()
	_test_shop_trait()
	print("===== 결과: 통과 %d / 실패 %d =====" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func _test_branches() -> void:
	var sword: UnitData = UnitCatalog.get_unit(&"sword")
	_eq(sword.get_branch_level(49), 0, "소드 49명: 분기 없음")
	_eq(sword.get_branch_level(50), 1, "소드 50명: 1분기")
	_eq(sword.get_branch_level(150), 2, "소드 150명: 2분기")
	var u: BattleUnit = BattleUnit.new()
	u.setup(0, 0, 0, sword, 1.0, false, 150)
	_near(u.attack, 10.0 * 1.3 * 1.1, "소드 2분기 공격력 = 10 ×1.3 ×1.1")
	_near(u.splash_radius, 22.0, "소드 2분기 회전베기 광역 22")
	var king: UnitData = UnitCatalog.get_unit(&"king")
	_eq(king.get_branch_level(2), 0, "킹 2명: 분기 없음")
	_eq(king.get_branch_level(3), 1, "킹 3명: 1분기")
	_eq(king.get_branch_level(5), 2, "킹 5명: 2분기")
	_eq(BattleRules.get_spawn_plan(5, false, true), { "spawn": 1, "ratio": 1.0 }, "킹은 누적 수와 상관없이 1명 소환")
	var k: BattleUnit = BattleUnit.new()
	k.setup(1, 0, 0, king, 1.0, false, 5)
	_near(k.king_attack_mult, 1.5, "킹 2분기: 장판 공격 배수 1.5")
	_near(k.king_damage_taken_mult, 0.68, "킹 2분기: 받는 피해 배수 0.68")
	_near(k.king_haste_mult, 1.25, "킹 2분기: 공속 배수 1.25")


func _packet(cell: int, id: StringName, count: int) -> SpawnPacket:
	var p: SpawnPacket = SpawnPacket.new()
	p.cell_index = cell
	p.unit_data = UnitCatalog.get_unit(id)
	p.total_count = count
	return p


func _test_king_battle() -> void:
	var sim: BattleSimulation = BattleSimulation.new()
	sim.setup([[_packet(4, &"king", 1), _packet(1, &"sword", 4)], [_packet(4, &"sword", 1)]], 7)
	var king: BattleUnit = null
	var allies: Array[BattleUnit] = []
	var enemy: BattleUnit = null
	for u: BattleUnit in sim.units:
		if u.team == 1:
			enemy = u
		elif u.data.is_unique:
			king = u
		else:
			allies.append(u)
	# 아군 4명을 킹 바로 옆에 모은다
	king.pos = Vector2.ZERO
	for i: int in range(allies.size()):
		allies[i].pos = Vector2(10.0 + i * 5.0, 0.0)
	enemy.pos = Vector2(500.0, 0.0)
	sim._update_auras()
	_near(allies[0].buff_attack_mult, 1.3, "장판 안 아군 공격력 ×1.3")
	_near(allies[0].buff_damage_taken_mult, 0.8, "장판 안 아군 받는 피해 ×0.8")
	_eq(king.share_targets.size(), 4, "피해 분담 명단: 아군 4 (+ 킹 본인)")
	var king_hp: float = king.hp
	var ally_hp: float = allies[0].hp
	sim._hit(enemy, king, 100.0)
	_near(king_hp - king.hp, 100.0 / 5.0 * 0.8, "킹이 받은 100 피해 → 5명이 20씩 (장판 ×0.8 → 16)")
	_near(ally_hp - allies[0].hp, 16.0, "아군도 16씩 나눠 받음")
	sim.run_to_end()


func _test_reflect() -> void:
	var sim: BattleSimulation = BattleSimulation.new()
	sim.setup([[_packet(4, &"shield", 150)], [_packet(4, &"sword", 1)]], 3)
	var shield: BattleUnit = null
	var enemy: BattleUnit = null
	for u: BattleUnit in sim.units:
		if u.team == 0 and shield == null:
			shield = u
		elif u.team == 1:
			enemy = u
	_near(shield.reflect_ratio, 0.25, "실드 2분기 가시방패 반사 25%")
	var enemy_hp: float = enemy.hp
	sim._hit(enemy, shield, 40.0)
	_check(enemy.hp < enemy_hp, "실드를 때리면 공격자도 피해", "%f → %f" % [enemy_hp, enemy.hp])
	sim.run_to_end()


func _test_poker_trait() -> void:
	var poker: DiceTraitData = load("res://data/traits/poker.tres")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var traited: DiceInstance = DiceInstance.new(load("res://data/dice/d6.tres"))
	_check(traited.attach_trait(load("res://data/traits/bone.tres"), rng), "다른 성질 먼저 부여")
	_check(not traited.attach_trait(poker, rng), "성질 있는 6면 주사위는 포커카드 불가")
	var d2: DiceInstance = DiceInstance.new(load("res://data/dice/d6.tres"))
	_check(d2.attach_trait(poker, rng), "6면 주사위 → 포커카드 변환")
	_eq(d2.get_modified_faces().size(), 13, "면 13개 (A~K)")
	_eq(d2.face_label(13), "K", "13 = K")
	_eq(d2.face_label(1), "A", "1 = A")
	_check(d2.runtime_state.has(PokerTrait.STATE_SUIT), "수트 기록")
	_check(not d2.attach_trait(poker, rng), "이미 성질 있는 주사위는 다시 변환 불가")
	_eq(poker.get_unlocked_units(1, d2), [&"giant"] as Array[StringName], "A → 거인")
	_eq(poker.get_unlocked_units(13, d2), [&"king"] as Array[StringName], "K → 킹")
	_eq(poker.get_unlocked_units(7, d2).size(), 0, "7 → 해금 없음")


func _summon(value: int, unlocks: Array[StringName]) -> Dictionary:
	return {
		"dice_index": 0, "base": value, "value": value, "reason": "", "raw": 13,
		"unlocks": unlocks, "amount": 0, "placed": false, "unit_id": &"", "cell": -1,
	}


func _test_session_king() -> void:
	var s: GameSession = GameSession.new(99)
	s.phase = GameSession.Phase.PLACEMENT
	s.summons = [_summon(13, [&"king"]), _summon(13, [&"king"]), _summon(9, []), _summon(13, [&"king"])]
	_check(not s.can_use_unit(2, &"king"), "K가 아닌 주사위는 킹 불가")
	_check(not s.can_use_unit(2, &"giant"), "A가 아닌 주사위는 거인 불가")
	_check(s.place(0, &"king", 4), "K → 킹 배치")
	_eq(s.board.cells[4].count, 1, "킹 칸 누적 1 (소환값 13과 무관)")
	_check(not s.place(1, &"king", 1), "킹은 다른 칸에 또 놓을 수 없음 (유일)")
	_check(s.place(1, &"king", 4), "같은 칸에는 킹 누적")
	_eq(s.board.cells[4].count, 2, "킹 칸 누적 2")
	_check(s.place(2, &"sword", 0), "일반 병과는 그대로")
	_eq(s.board.cells[0].count, 9, "소드 9명")


func _test_shop_trait() -> void:
	var s: GameSession = GameSession.new(123)
	var shop: ShopState = s.shop
	var offer: ShopOffer = shop.dice_offers[0]
	_eq(offer.kind, ShopOffer.Kind.TRAIT, "성질 칸 진열")
	# 진열은 무작위라 포커카드로 고정해서 검사
	offer.trait_data = load("res://data/traits/poker.tres")
	offer.price = ShopCatalog.trait_price(offer.trait_data)
	s.player.gold = 2000
	# 모든 주사위에 다른 성질이 붙어 있으면 구매 불가 + 안내 문구
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var bone: DiceTraitData = load("res://data/traits/bone.tres")
	for d: DiceInstance in s.deck.active:
		d.attach_trait(bone, rng)
	_eq(shop.can_buy(offer), "성질 없는 6면주사위를 보유하고있어야 구매가 가능합니다", "성질 없는 6면 주사위가 없으면 구매 불가 + 안내 문구")
	var d2: DiceInstance = DiceInstance.new(load("res://data/dice/d6.tres"))
	s.deck.add_to_reserve(d2)
	_eq(shop.can_buy(offer), "", "성질 없는 6면 주사위가 있으면 구매 가능")
	var gold: int = s.player.gold
	_eq(shop.buy(offer, s.deck.active[0]), "이 주사위는 변환할 수 없습니다 (6면 주사위 · 성질 없음)", "성질 있는 주사위 지정 → 거절")
	_eq(shop.buy(offer, d2), "", "성질 없는 6면 주사위 지정 → 변환")
	_check(d2.trait_data is PokerTrait, "변환 완료")
	_eq(gold - s.player.gold, ShopCatalog.trait_price(offer.trait_data), "가격 차감 (B등급 250원)")


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		print("  PASS  ", label)
	else:
		_fail_count += 1
		print("  FAIL  ", label, ("  → " + detail) if detail != "" else "")


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, label, "기대 %s, 실제 %s" % [str(expected), str(actual)])


func _near(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.01, label, "기대 %.3f, 실제 %.3f" % [expected, actual])
