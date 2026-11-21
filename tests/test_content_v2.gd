extends SceneTree
## 주사위 성질 10종 · 유저 아이템 · 타로카드 검증
## 실행: godot --headless --path <프로젝트> --script res://tests/test_content_v2.gd

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	print("===== 성질·아이템·타로 테스트 =====")
	_test_traits_math()
	_test_mirror_magnet()
	_test_confirm_effects()
	_test_destroy_and_round_end()
	_test_overload()
	_test_poker_suit_in_battle()
	_test_items()
	_test_tarots_board()
	_test_tarots_battle()
	print("===== 결과: 통과 %d / 실패 %d =====" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func _trait(id: String) -> DiceTraitData:
	return load("res://data/traits/%s.tres" % id) as DiceTraitData


func _d6(trait_id: String = "") -> DiceInstance:
	var d: DiceInstance = DiceInstance.new(load("res://data/dice/d6.tres"))
	if trait_id != "":
		d.trait_data = _trait(trait_id)
	return d


func _value(d: DiceInstance, raw: int, round_number: int = 1, mods: Dictionary = {}) -> int:
	var ctx: RollContext = RollContext.new(null, round_number)
	DiceRollResolver._apply_modifiers(ctx, mods)
	d.run_pipeline(ctx, raw)
	return ctx.get_summon_value()


func _test_traits_math() -> void:
	_eq(_value(_d6("blood"), 4), 10, "피주사위: 4 ×2.5 = 10")
	_eq(_value(_d6("glass"), 4), 12, "유리주사위: 4 ×3 = 12")
	_eq(_value(_d6("overload"), 4), 8, "과부하: 4 ×2 = 8")
	_eq(_value(_d6("gold"), 10), 7, "황금: 10 ×0.7 = 7")
	# 뼈: 9R 슬롯 1 정지 무시
	var bone: DiceInstance = _d6("bone")
	bone.equip(EnchantInstance.new(load("res://data/enchants/add_common.tres")), 0)
	_eq(_value(bone, 4, 9, { "disabled_slots": [0] }), 7, "뼈주사위: 9R 슬롯 정지 무시 (4+3)")
	var plain: DiceInstance = _d6()
	plain.equip(EnchantInstance.new(load("res://data/enchants/add_common.tres")), 0)
	_eq(_value(plain, 4, 9, { "disabled_slots": [0] }), 4, "일반 주사위는 9R 슬롯 정지")
	var xb: DiceInstance = _d6("xbottle")
	xb.runtime_state[XBottleTrait.STATE_STACK] = 75
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var ctx: RollContext = RollContext.new(rng, 1)
	xb.roll(ctx)
	_eq(ctx.get_summon_value(), 75, "X병: 눈금 대신 누적 스택 75")


func _test_mirror_magnet() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var dice: Array[DiceInstance] = [_d6(), _d6("mirror"), _d6("mirror"), _d6(), _d6()]
	var res: Array[DiceRollResult] = DiceRollResolver.resolve(dice, rng, 1)
	_eq(res[1].summon_value, res[0].summon_value, "거울: 왼쪽 주사위 최종값 복사")
	_eq(res[2].summon_value, 1, "거울 연속: 왼쪽도 거울이면 1")
	var first: Array[DiceInstance] = [_d6("mirror"), _d6(), _d6(), _d6(), _d6()]
	_eq(DiceRollResolver.resolve(first, rng, 1)[0].summon_value, 1, "거울이 맨 왼쪽이면 1")
	# 자석: 나머지가 모두 같은 눈금이면 여러 번 중 일부는 끌려온다
	var pulled: int = 0
	for s: int in range(40):
		rng.seed = 100 + s
		var md: Array[DiceInstance] = [_d6("magnet"), _d6(), _d6(), _d6(), _d6()]
		var r: Array[DiceRollResult] = DiceRollResolver.resolve(md, rng, 1, [false, true, true, true, true],
			_fake_results([0, 5, 5, 5, 5]))
		if r[0].raw_roll == 5:
			pulled += 1
	_check(pulled >= 15 and pulled <= 35, "자석: 약 50%% 확률로 최빈값 5에 끌림 (%d/40)" % pulled)


func _fake_results(raws: Array) -> Array[DiceRollResult]:
	var out: Array[DiceRollResult] = []
	for i: int in range(raws.size()):
		var r: DiceRollResult = DiceRollResult.new()
		r.dice_index = i
		r.raw_roll = raws[i]
		out.append(r)
	return out


func _result(raw: int, final_value: int) -> DiceRollResult:
	var r: DiceRollResult = DiceRollResult.new()
	r.raw_roll = raw
	r.final_value = final_value * 10
	r.summon_value = final_value
	return r


func _test_confirm_effects() -> void:
	var s: GameSession = GameSession.new(11)
	s.player.hp = 100
	var msg: String = _trait("blood").on_confirm(_d6("blood"), _result(6, 15), s)
	_eq(s.player.hp, 94, "피주사위 확정: 체력 -6 (%s)" % msg)
	s.player.hp = 3
	_trait("blood").on_confirm(_d6("blood"), _result(6, 15), s)
	_eq(s.player.hp, 1, "피주사위: 체력 1 아래로 안 내려감")
	s.player.hp = 50
	_trait("fairy").on_confirm(_d6("fairy"), _result(6, 6), s)
	_eq(s.player.hp, 56, "요정: 체력 +6")
	var gold: int = s.player.gold
	_trait("gold").on_confirm(_d6("gold"), _result(5, 14), s)
	_eq(s.player.gold - gold, 7, "황금: 최종값 14의 50% = +7원")


func _test_destroy_and_round_end() -> void:
	var s: GameSession = GameSession.new(12)
	var glass: DiceInstance = s.deck.active[0]
	glass.trait_data = _trait("glass")
	glass.equip(EnchantInstance.new(load("res://data/enchants/add_common.tres")), 0)
	var spare: DiceInstance = _d6()
	s.deck.add_to_reserve(spare)
	s.destroy_dice(glass)
	_check(not s.deck.active.has(glass), "파괴된 주사위 제거")
	_eq(s.deck.active.size(), 5, "출전 5개 유지")
	_check(s.deck.active[0] == spare, "가방 주사위가 출전 칸 보충")
	var moved: bool = false
	for d: DiceInstance in s.deck.all_dice():
		if not d.get_enchants().is_empty():
			moved = true
	_check(moved, "인첸트 자동 회수 (다른 주사위 빈 슬롯으로)")
	# 가방이 비었으면 기본 6면 생성
	var s2: GameSession = GameSession.new(13)
	var victim: DiceInstance = s2.deck.active[2]
	s2.destroy_dice(victim)
	_eq(s2.deck.active.size(), 5, "가방이 비어도 5개 유지 (기본 6면 생성)")
	_eq(String(s2.deck.active[2].data.id), "d6", "새 기본 6면 주사위")
	# X병: 가방에 있으면 스택 누적
	var s3: GameSession = GameSession.new(14)
	var xb: DiceInstance = _d6("xbottle")
	s3.deck.add_to_reserve(xb)
	_trait("xbottle").on_round_end(xb, false, s3)
	_trait("xbottle").on_round_end(xb, false, s3)
	_eq(XBottleTrait.stack_of(xb), 50, "X병: 가방에서 라운드마다 +25")
	_trait("xbottle").on_round_end(xb, true, s3)
	_check(not s3.deck.all_dice().has(xb), "X병: 사용한 라운드 끝에 파괴")


func _test_overload() -> void:
	var b: BoardState = BoardState.new()
	b.place(1, &"sword", 30)
	b.place(1, &"sword", 20, [], true)
	_eq(b.cells[1].count, 30, "과부하: 중첩칸 영구 인원은 그대로")
	_eq(b.get_spawn_packets()[0].total_count, 50, "과부하: 이번 전투에는 합산 50명")
	b.apply_stack_retention({ 1: 50.0 })
	_eq(b.cells[1].count, 30, "전투 후 과부하 인원은 영구 누적 안 됨")
	_eq(b.cells[1].temp_count, 0, "과부하 인원 정리")


func _test_poker_suit_in_battle() -> void:
	var b: BoardState = BoardState.new()
	var spade: StatModifier = PokerTrait.get_suit_modifier(PokerTrait.SuitType.SPADE)
	b.place(4, &"sword", 10, [spade, PokerTrait.get_royal_modifier()])
	b.place(4, &"sword", 5, [spade])
	_eq(b.cells[4].modifiers.size(), 2, "같은 수트 보정은 한 칸에 한 번만")
	var sim: BattleSimulation = BattleSimulation.new()
	sim.setup([b.get_spawn_packets(), []], 1)
	_near(sim.units[0].attack, 10.0 * 1.2 * 1.3, "♠ ×1.2 + 로열 ×1.3 공격력")
	sim.run_to_end()
	var heart: BattleUnit = BattleUnit.new()
	heart.setup(0, 0, 0, UnitCatalog.get_unit(&"sword"), 1.0, false, 1, [PokerTrait.get_suit_modifier(PokerTrait.SuitType.DIAMOND)])
	_near(heart.shield, 20.0, "♦: 최대 체력 20% 실드")
	heart.take_damage(15.0)
	_near(heart.hp, 100.0, "실드가 먼저 피해를 흡수")


func _item(id: String) -> UserItemData:
	return load("res://data/items/%s.tres" % id) as UserItemData


func _test_items() -> void:
	var s: GameSession = GameSession.new(21)
	s.acquire_item(_item("love_fifty"))
	s.inventory.items[0].state[TriggerFaceItem.STATE_FACE] = 3
	s.acquire_item(_item("conditional_math"))
	var cm: ItemInstance = s.inventory.items[1]
	cm.state[TriggerFaceItem.STATE_FACE] = 3
	cm.state[ConditionalMathItem.STATE_MULT] = false
	s.refresh_item_rules()
	_eq(_value(_d6(), 3, 1, s.flow.roll_modifiers), 60, "50이좋아(우선) → +?곱?(+10) = 60")
	_eq(_value(_d6(), 4, 1, s.flow.roll_modifiers), 4, "지정 눈금이 아니면 그대로")

	var s2: GameSession = GameSession.new(22)
	s2.acquire_item(_item("last_digit_washer"))
	_eq(_value(_d6(), 12, 1, s2.flow.roll_modifiers), 19, "끝자리 세탁기: 12 → 19")
	var s3: GameSession = GameSession.new(23)
	s3.acquire_item(_item("empty_slot"))
	_eq(_value(_d6(), 4, 1, s3.flow.roll_modifiers), 7, "빈 슬롯 3칸: 4 ×1.75 = 7")

	var s4: GameSession = GameSession.new(24)
	var base_limit: int = s4.flow.get_reroll_limit()
	s4.acquire_item(_item("didnt_roll"))
	_eq(s4.flow.get_reroll_limit(), base_limit + 1, "나 안굴렸는데?: 재굴림 +1")
	var target: DiceInstance = s4.deck.active[0]
	s4.acquire_item(_item("chisel"), target)
	_eq(target.unlocked_slots, 4, "조각칼: 슬롯 3 → 4")
	_eq(s4.inventory.items.size(), 1, "조각칼은 쓰고 사라짐")

	var s5: GameSession = GameSession.new(25)
	s5.acquire_item(_item("piggy_bank"))
	var piggy: ItemInstance = s5.inventory.items[0]
	piggy.data.on_round_end(piggy, s5)
	piggy.data.on_round_end(piggy, s5)
	var g: int = s5.player.gold
	s5.activate_item(piggy)
	_eq(s5.player.gold - g, 300, "돼지저금통 깨기: 150 × 2라운드")
	_eq(s5.inventory.items.size(), 0, "깬 저금통은 사라짐")

	var s6: GameSession = GameSession.new(26)
	var g6: int = s6.player.gold
	s6.acquire_item(_item("loan_shark"))
	_eq(s6.player.gold - g6, 800, "고리대금: 즉시 +800")
	var g7: int = s6.player.gold
	s6.player.add_gold(100, PlayerState.GoldSource.YACHT_BOARD)
	s6.player.add_gold(100, PlayerState.GoldSource.ROUND_INCOME)
	_eq(s6.player.gold - g7, 150, "상환 중: 얏츠판 보상만 50% 차감")

	var s7: GameSession = GameSession.new(27)
	s7.acquire_item(_item("hand_forgery"))
	_check(s7.yacht.preview([1, 2, 4, 5, 9], 1).get(YachtBoard.Category.LARGE_STRAIGHT, 0) > 0, "족보 위조권: 1·2·_·4·5 라지 스트레이트")
	_check(s7.yacht.preview([3, 3, 3, 3, 9], 1).get(YachtBoard.Category.YACHT, 0) > 0, "족보 위조권: 4개 동일 얏츠")
	var s8: GameSession = GameSession.new(28)
	_eq(s8.yacht.preview([3, 3, 3, 3, 9], 1).get(YachtBoard.Category.YACHT, 0), 0, "위조권 없으면 4개는 얏츠 아님")


func _tarot(id: String) -> TarotCardData:
	return load("res://data/tarots/%s.tres" % id) as TarotCardData


func _test_tarots_board() -> void:
	var s: GameSession = GameSession.new(31)
	s.acquire_tarot(_tarot("hanged_man"))
	_check(s.use_tarot(_tarot("hanged_man")) != "", "칸 지정 카드는 칸이 필요")
	_eq(s.use_tarot(_tarot("hanged_man"), 4), "", "행맨을 4번 칸에 지정")
	s.board.place(4, &"shield", 10)
	var p: SpawnPacket = s.board.get_spawn_packets()[0]
	_check(p.modifiers.has(_tarot("hanged_man").cell_modifier), "칸 자리 버프가 스폰에 포함")
	s.board.cells[4].clear()
	_eq(s.board.get_slot_modifiers(4).size(), 1, "칸을 비워도 타로 버프는 자리에 남음")
	var u: BattleUnit = BattleUnit.new()
	u.setup(0, 0, 4, UnitCatalog.get_unit(&"shield"), 1.0, false, 10, [_tarot("hanged_man").cell_modifier, _tarot("hanged_man").cell_modifier, _tarot("high_priestess").cell_modifier])
	_near(u.get_damage_taken_mult(), 0.25, "행맨×2+하이프리스티스+실드 방어도 받는 피해 25% 아래로는 안 내려감")
	# 저스티스
	s.acquire_tarot(_tarot("justice"))
	s.use_tarot(_tarot("justice"))
	var taken: Dictionary = s.player.take_round_damage(50)
	_eq(taken["hp"], 15, "저스티스 실드 35 흡수 → 체력 피해 15")
	s.apply_round_rules()
	_eq(s.player.justice_shield, 35, "라운드 시작 시 저스티스 실드 리필")
	# 예약 최대 2장
	for id: String in ["moon", "fool"]:
		s.acquire_tarot(_tarot(id))
		s.use_tarot(_tarot(id))
	s.acquire_tarot(_tarot("star"))
	_check(s.use_tarot(_tarot("star")) != "", "전투 예약은 2장까지")


func _packet(cell: int, id: StringName, count: int) -> SpawnPacket:
	var p: SpawnPacket = SpawnPacket.new()
	p.cell_index = cell
	p.unit_data = UnitCatalog.get_unit(id)
	p.total_count = count
	return p


func _test_tarots_battle() -> void:
	var sim: BattleSimulation = BattleSimulation.new()
	sim.setup([[_packet(4, &"shield", 50)], [_packet(4, &"shield", 50)]], 3)
	sim.add_battle_tarot(0, _tarot("fool"))
	sim.add_battle_tarot(0, _tarot("moon"))
	while sim.phase != BattleSimulation.Phase.FIGHT:
		sim.step()
	_near(sim.units[0].tarot_attack_mult, 2.0, "더 풀: 아군 공격 ×2")
	_near(sim.units[sim.units.size() - 1].tarot_attack_mult, 2.0, "더 풀: 적도 공격 ×2")
	_near(sim.units[0].tarot_haste_mult, 1.6, "더 문: 공속 +60%")
	for i: int in range(int(10.5 / BattleRules.SIM_DT)):
		sim.step()
	if sim.units[0].alive:
		_near(sim.units[0].tarot_haste_mult, 1.0, "더 문: 10초 뒤 원래대로")
	else:
		_check(true, "더 문: (유닛 사망으로 건너뜀)")
	sim.run_to_end()

	# 더 월드: 약한 아군이 밀리면 전투 무효
	var w: BattleSimulation = BattleSimulation.new()
	w.setup([[_packet(4, &"sword", 5)], [_packet(4, &"sword", 200)]], 5)
	w.add_battle_tarot(0, _tarot("world"))
	var r: BattleResult = w.run_to_end()
	_eq(r.reason, "void", "더 월드: 아군 체력 30% 이하 → 무효")
	var s: GameSession = GameSession.new(41)
	s.board.place(0, &"sword", 10)
	var hp: int = s.player.hp
	var summary: Dictionary = BattleSettlement.settle_solo(r, s.player, s.board, s.streak, 3, 2)
	_eq(s.player.hp, hp, "무효: 체력 피해 없음")
	_eq(summary["void_gold"], 400, "무효 위로금 200 × 프레스티지 배율 2")
	_eq(s.board.cells[0].count, 10, "무효: 소비칸 유지")

	# 더 타워: 번개 이벤트
	var t: BattleSimulation = BattleSimulation.new()
	t.setup([[_packet(4, &"shield", 50)], [_packet(4, &"sword", 50)]], 9)
	t.add_battle_tarot(0, _tarot("tower"), 2)
	var zaps: int = 0
	var guard: int = 3000
	while not t.is_finished() and guard > 0:
		t.step()
		for e: Dictionary in t.events:
			if e["type"] == "zap":
				zaps += 1
		guard -= 1
	_check(zaps >= 3, "더 타워: 연쇄 번개 발동 (%d회)" % zaps)

	# 더 허밋: 5초 면역
	var h: BattleUnit = BattleUnit.new()
	h.setup(0, 0, 0, UnitCatalog.get_unit(&"sword"), 1.0, false, 1, [_tarot("hermit").cell_modifier])
	_eq(h.take_damage(50.0), 0.0, "더 허밋: 면역 중 피해 0")
	_check(not h.is_targetable(), "더 허밋: 타겟 불가")


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
