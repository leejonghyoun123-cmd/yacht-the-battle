extends SceneTree
## Step 1 핵심 로직 자동 검증 (UI 없음).
## 실행: godot --headless --path <프로젝트> --script res://tests/test_core_logic.gd
## 실패가 하나라도 있으면 종료 코드 1.

var _pass_count: int = 0
var _fail_count: int = 0


## 테스트 전용: 모든 면을 지우는 인첸트 (최소 1면 보장 검증용)
class RemoveAllFacesEnchant extends EnchantData:
	func _init() -> void:
		phase = Phase.PRE_ROLL
		display_name = "전부 삭제(테스트)"

	func apply_pre_roll(_faces: Array[int], _instance: EnchantInstance) -> Array[int]:
		return []


func _initialize() -> void:
	print("===== 야추 더 배틀 Step 1 핵심 로직 테스트 =====")
	_test_fixed_num()
	_test_number_formatter()
	_test_slot_order()
	_test_decimal_pipeline()
	_test_clamp_to_one()
	_test_face_removal_safety()
	_test_echo()
	_test_move_enchant()
	_test_big_numbers()
	_test_resolver_determinism()
	_test_yacht_categories()
	_test_yacht_record_and_prestige()
	print("===== 결과: 통과 %d / 실패 %d =====" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


# --- 헬퍼 ------------------------------------------------------------------

func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		print("  PASS  ", label)
	else:
		_fail_count += 1
		print("  FAIL  ", label, ("  → " + detail) if detail != "" else "")


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, label, "기대 %s, 실제 %s" % [str(expected), str(actual)])


func _d6(slots_open: int = 3) -> DiceInstance:
	var d: DiceInstance = DiceInstance.new(DiceData.create_standard(&"d6", "6면", 6))
	d.unlock_slots(slots_open - d.unlocked_slots)
	return d


func _add(amount: float) -> EnchantInstance:
	var e: AddFlatEnchant = AddFlatEnchant.new()
	e.display_name = "+" + str(amount)
	e.amount = amount
	return EnchantInstance.new(e)


func _mul(factor: float) -> EnchantInstance:
	var e: MultiplyEnchant = MultiplyEnchant.new()
	e.display_name = "×" + str(factor)
	e.factor = factor
	return EnchantInstance.new(e)


func _sub100() -> EnchantInstance:
	var e: SubFrom100Enchant = SubFrom100Enchant.new()
	e.display_name = "100-X"
	return EnchantInstance.new(e)


func _lower_half() -> EnchantInstance:
	var e: RemoveLowerHalfEnchant = RemoveLowerHalfEnchant.new()
	e.display_name = "하위 절반 삭제"
	return EnchantInstance.new(e)


func _echo() -> EnchantInstance:
	var e: EchoSlotEnchant = EchoSlotEnchant.new()
	e.display_name = "메아리"
	return EnchantInstance.new(e)


func _run(d: DiceInstance, raw: int) -> RollContext:
	var ctx: RollContext = RollContext.new(null, 1)
	d.run_pipeline(ctx, raw)
	return ctx


func _skip_count(ctx: RollContext) -> int:
	var n: int = 0
	for entry: Dictionary in ctx.logs:
		if entry["skipped"]:
			n += 1
	return n


# --- 테스트 ----------------------------------------------------------------

func _test_fixed_num() -> void:
	print("[FixedNum]")
	_eq(FixedNum.round_to_int(45), 5, "4.5 반올림 → 5")
	_eq(FixedNum.round_to_int(44), 4, "4.4 반올림 → 4")
	_eq(FixedNum.to_text(135), "13.5", "135 → '13.5'")
	_eq(FixedNum.to_text(130), "13", "130 → '13'")
	_eq(FixedNum.add(FixedNum.MAX, 10), FixedNum.MAX, "덧셈 상한 포화")
	_eq(FixedNum.mul_milli(FixedNum.MAX, 2000), FixedNum.MAX, "곱셈 상한 포화 (음수로 뒤집히지 않음)")
	_eq(FixedNum.mul_float(30, 1.5), 45, "3 × 1.5 = 4.5")


func _test_number_formatter() -> void:
	print("[NumberFormatter]")
	_eq(NumberFormatter.format_num(999), "999", "999")
	_eq(NumberFormatter.format_num(1500), "1.5K", "1500 → 1.5K")
	_eq(NumberFormatter.format_num(1234567), "1.2M", "1234567 → 1.2M")
	_eq(NumberFormatter.format_num(999950), "1M", "999950 → 1M (1000K 아님)")
	_eq(NumberFormatter.format_fixed(135), "13.5", "고정소수점 13.5")
	_eq(NumberFormatter.format_fixed(FixedNum.from_int(2500000)), "2.5M", "고정소수점 2.5M")


func _test_slot_order() -> void:
	print("[슬롯 순서]")
	var a: DiceInstance = _d6()
	a.equip(_add(3.0), 0)
	a.equip(_mul(2.0), 1)
	_eq(_run(a, 3).get_summon_value(), 12, "[+3, ×2] 3 → 6 → 12")
	var b: DiceInstance = _d6()
	b.equip(_mul(2.0), 0)
	b.equip(_add(3.0), 1)
	_eq(_run(b, 3).get_summon_value(), 9, "[×2, +3] 3 → 6 → 9")
	_eq(a.calculate_final_value(3), 12, "규칙 시그니처 calculate_final_value(raw) 동작")


func _test_decimal_pipeline() -> void:
	print("[소수점 1자리 유지]")
	var d: DiceInstance = _d6()
	d.equip(_mul(1.5), 0)
	var ctx: RollContext = _run(d, 3)
	_eq(ctx.value, 45, "3 × 1.5 = 4.5 유지")
	_eq(ctx.get_summon_value(), 5, "최종 소환 시 반올림 → 5")
	var d2: DiceInstance = _d6()
	d2.equip(_mul(1.5), 0)
	d2.equip(_mul(1.5), 1)
	var ctx2: RollContext = _run(d2, 3)
	_eq(ctx2.value, 67, "3 × 1.5 × 1.5 = 6.75 → 소수점 1자리 6.7 (중간 반올림 없음)")
	_eq(ctx2.get_summon_value(), 7, "최종 반올림 → 7")


func _test_clamp_to_one() -> void:
	print("[0 이하 → 1 보정]")
	var d: DiceInstance = _d6(5)
	d.equip(_mul(3.0), 0)
	d.equip(_mul(3.0), 1)
	d.equip(_mul(3.0), 2)
	d.equip(_sub100(), 3)
	var ctx: RollContext = _run(d, 6)  # 6 → 18 → 54 → 162 → 100-162 = -62 → 1
	_eq(ctx.value, FixedNum.ONE, "100 - 162 → 1로 보정")
	var clamped: bool = false
	for entry: Dictionary in ctx.logs:
		if entry["clamped"]:
			clamped = true
	_check(clamped, "보정 사실이 로그에 기록됨")
	_eq(ctx.underflow_bank, FixedNum.from_int(62), "음수 초과량 62 누적 (오버플로우 배터리용)")
	d.equip(_add(3.0), 4)
	_eq(_run(d, 6).get_summon_value(), 4, "보정 직후 다음 슬롯은 1에서 계속 (1 + 3 = 4)")


func _test_face_removal_safety() -> void:
	print("[면 삭제 최소 1면 보장]")
	var d: DiceInstance = _d6()
	d.equip(_lower_half(), 0)
	_eq(d.get_modified_faces(), [4, 5, 6] as Array[int], "6면 하위 절반 삭제 → [4,5,6]")
	d.equip(_lower_half(), 1)
	_eq(d.get_modified_faces(), [4, 5, 6] as Array[int], "중복 적용해도 [4,5,6]")
	d.equip(EnchantInstance.new(RemoveAllFacesEnchant.new()), 2)
	_eq(d.get_modified_faces(), [4, 5, 6] as Array[int], "전부 삭제 필터는 건너뛰어 면 유지")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var ctx: RollContext = RollContext.new(rng, 1)
	d.roll(ctx)
	_check(ctx.raw_roll >= 4, "굴림 결과는 남은 면에서만 나옴", "raw=" + str(ctx.raw_roll))
	_check(_skip_count(ctx) == 1, "건너뛴 필터가 미발동으로 기록됨")


func _test_echo() -> void:
	print("[메아리 (복사 무한 루프 차단)]")
	var d: DiceInstance = _d6()
	d.equip(_add(3.0), 0)
	d.equip(_echo(), 1)
	_eq(_run(d, 2).get_summon_value(), 8, "[+3, 메아리] 2 → 5 → 8")

	var chain: DiceInstance = _d6()
	chain.equip(_add(3.0), 0)
	chain.equip(_echo(), 1)
	chain.equip(_echo(), 2)
	var ctx: RollContext = _run(chain, 2)
	_eq(ctx.get_summon_value(), 8, "메아리 2연속: 두 번째 메아리는 미발동 (8 유지)")
	_eq(_skip_count(ctx), 1, "미발동 1건 기록")

	var first: DiceInstance = _d6()
	first.equip(_echo(), 0)
	_eq(_skip_count(_run(first, 2)), 1, "1번 슬롯 메아리 → 미발동 (직전 없음)")

	var after_empty: DiceInstance = _d6()
	after_empty.equip(_add(3.0), 0)
	after_empty.equip(_echo(), 2)
	var ctx2: RollContext = _run(after_empty, 2)
	_eq(ctx2.get_summon_value(), 5, "빈 슬롯 뒤 메아리 → 미발동 (5)")
	_check(str(ctx2.logs[-1]["reason"]).contains("비어"), "미발동 사유: 직전 슬롯이 비어 있음")

	var after_pre: DiceInstance = _d6()
	after_pre.equip(_lower_half(), 0)
	after_pre.equip(_echo(), 1)
	_eq(_skip_count(_run(after_pre, 4)), 1, "굴림 전 인첸트 뒤 메아리 → 미발동")

	var copy_mul: DiceInstance = _d6()
	copy_mul.equip(_mul(2.0), 0)
	copy_mul.equip(_echo(), 1)
	var ctx3: RollContext = _run(copy_mul, 3)
	_eq(ctx3.get_summon_value(), 12, "[×2, 메아리] 3 → 6 → 12")
	_check(str(ctx3.logs[-1]["source"]).begins_with("메아리 → "), "복사 발동 로그에 '메아리 → 대상' 표기")


func _test_move_enchant() -> void:
	print("[슬롯 순서 변경]")
	var d: DiceInstance = _d6()
	var plus: EnchantInstance = _add(3.0)
	var times: EnchantInstance = _mul(2.0)
	d.equip(plus, 0)
	d.equip(times, 1)
	_check(d.move_enchant(1, 0), "1번 → 0번 이동 성공")
	_check(d.slots[0] == times and d.slots[1] == plus, "순서가 [×2, +3]로 바뀜")
	_eq(_run(d, 3).get_summon_value(), 9, "바뀐 순서로 연산 (3 → 6 → 9)")
	_check(not d.move_enchant(0, 4), "잠긴 슬롯(5번)으로는 이동 불가")
	_eq(d.slots.size(), DiceInstance.MAX_SLOTS, "슬롯 배열 길이 5 유지")


func _test_big_numbers() -> void:
	print("[대형 숫자]")
	var d: DiceInstance = _d6(5)
	for i: int in range(5):
		d.equip(_mul(1000000.0), i)
	var ctx: RollContext = _run(d, 6)
	_eq(ctx.value, FixedNum.MAX, "6 × 100만^5 → 상한에서 포화")
	_check(ctx.get_summon_value() > 0, "포화 후에도 양수 유지")
	print("    표시: ", NumberFormatter.format_fixed(ctx.value))


func _test_resolver_determinism() -> void:
	print("[일괄 굴림 · 결정론]")
	var dice: Array[DiceInstance] = []
	for i: int in range(5):
		var d: DiceInstance = _d6()
		d.equip(_add(1.0), 0)
		dice.append(d)
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 12345
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_b.seed = 12345
	var first: Array[DiceRollResult] = DiceRollResolver.resolve(dice, rng_a, 1)
	var second: Array[DiceRollResult] = DiceRollResolver.resolve(dice, rng_b, 1)
	_eq(DiceRollResolver.to_summon_values(first), DiceRollResolver.to_summon_values(second), "같은 시드 → 같은 결과")
	for r: DiceRollResult in first:
		print("    주사위", r.dice_index + 1, ": ", r.describe())

	var held: Array[bool] = [true, false, true, false, true]
	var reroll: Array[DiceRollResult] = DiceRollResolver.resolve(dice, rng_a, 1, held, first)
	var kept: bool = true
	for i: int in [0, 2, 4]:
		if reroll[i].raw_roll != first[i].raw_roll:
			kept = false
	_check(kept, "재굴림 시 고정한 주사위는 원시 눈금 유지")


func _test_yacht_categories() -> void:
	print("[얏츠판 판정 (1의 자리)]")
	var C := YachtBoard.Category
	_eq(YachtBoard.score_base(C.ACES, [11, 21, 31, 4, 5], 1), 30, "에이스: 11·21·31 → 3개 × 1 × 10 = 30")
	_eq(YachtBoard.score_base(C.THREES, [13, 23, 5, 6, 7], 1), 60, "쓰리: 13·23 → 3+3 = 6 → 60")
	_eq(YachtBoard.score_base(C.ACES, [10, 20, 30, 40, 50], 1), 0, "1의 자리 0은 상단 해당 없음")
	_eq(YachtBoard.score_base(C.LARGE_STRAIGHT, [10, 1, 2, 3, 4], 1), 600, "0·1·2·3·4 라지: 합 10 → 100 + 500")
	_eq(YachtBoard.score_base(C.SMALL_STRAIGHT, [6, 7, 8, 9, 9], 1), 640, "6·7·8·9 스몰: 합 39 → 390 + 250")
	_eq(YachtBoard.score_base(C.SMALL_STRAIGHT, [8, 9, 10, 11, 5], 1), 0, "9 → 0 순환 연속은 인정 안 함")
	_eq(YachtBoard.score_base(C.FULL_HOUSE, [3, 13, 23, 5, 15], 1), 340, "풀하우스 3·3·3·5·5: 합 19 → 190 + 150")
	_eq(YachtBoard.score_base(C.YACHT, [7, 17, 27, 37, 47], 3), 1250, "얏츠: 500 + 3R × 250")
	_eq(YachtBoard.score_base(C.FOUR_OF_A_KIND, [7, 17, 27, 37, 47], 3), 425, "얏츠는 포카드로 인정: 합 35 → 350 + 75")
	_eq(YachtBoard.score_base(C.FULL_HOUSE, [7, 17, 27, 37, 47], 3), 0, "얏츠는 풀하우스로 불인정")
	_eq(YachtBoard.score_base(C.YACHT, [10, 20, 30, 40, 50], 1), 750, "0 다섯 개도 얏츠")
	_eq(YachtBoard.score_base(C.FOUR_OF_A_KIND, [1, 2, 3, 4, 5], 1), 0, "족보 불성립 → 0")


func _test_yacht_record_and_prestige() -> void:
	print("[얏츠판 기록 · 프레스티지]")
	var board: YachtBoard = YachtBoard.new()
	var prestige_events: Array[int] = []
	board.prestige_triggered.connect(func(level: int) -> void: prestige_events.append(level))
	var junk: Array[int] = [1, 3, 5, 7, 9]
	_eq(board.record(YachtBoard.Category.YACHT, junk, 1), 0, "불성립 족보도 0원으로 기록 가능")
	_eq(board.record(YachtBoard.Category.YACHT, junk, 1), -1, "같은 항목 재기록 불가")
	for category: int in YachtBoard.Category.values():
		if board.prestige_level == 0 and not board.is_recorded(category):
			board.record(category, junk, 1)
	_eq(board.prestige_level, 1, "10칸 완성 → 프레스티지 1")
	_eq(prestige_events, [1] as Array[int], "prestige_triggered 시그널 발행")
	_eq(board.recorded.size(), 0, "보드 초기화")
	var values: Array[int] = [1, 11, 2, 3, 4]
	var preview: Dictionary = board.preview(values, 1)
	_eq(preview[YachtBoard.Category.ACES], 40, "프레스티지 후 보상 2배 (에이스 20 → 40)")
