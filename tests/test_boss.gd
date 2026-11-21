extends SceneTree
## 9·12·15R 보스 굴림 기믹 검증
## 실행: godot --headless --path <프로젝트> --script res://tests/test_boss.gd

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	print("===== 보스 굴림 기믹 테스트 =====")
	var add3: EnchantData = load("res://data/enchants/add_common.tres")
	var mul2: EnchantData = load("res://data/enchants/mul_uncommon.tres")

	# 9R: 슬롯 1 정지
	var d: DiceInstance = DiceInstance.new(load("res://data/dice/d6.tres"))
	d.equip(EnchantInstance.new(mul2), 0)
	d.equip(EnchantInstance.new(add3), 1)
	var ctx: RollContext = RollContext.new(null, 9)
	DiceRollResolver._apply_modifiers(ctx, BossRules.roll_modifiers(9))
	d.run_pipeline(ctx, 4)
	_eq(ctx.get_summon_value(), 7, "9R: 슬롯1(×2) 정지 → 4 + 3 = 7")
	var skipped: bool = false
	for e: Dictionary in ctx.logs:
		if e["skipped"]:
			skipped = true
	_check(skipped, "9R: 정지된 슬롯이 미발동으로 표시")

	# 12R: 두 번째 곱연산부터 절반
	var d2: DiceInstance = DiceInstance.new(load("res://data/dice/d6.tres"))
	d2.equip(EnchantInstance.new(mul2), 0)
	d2.equip(EnchantInstance.new(mul2), 1)
	var ctx2: RollContext = RollContext.new(null, 12)
	DiceRollResolver._apply_modifiers(ctx2, BossRules.roll_modifiers(12))
	d2.run_pipeline(ctx2, 5)
	_eq(ctx2.get_summon_value(), 15, "12R: 5 ×2 = 10, 두 번째 ×2 → ×1.5 = 15")
	_eq(BossRules.roll_modifiers(5), {}, "보스 라운드 아니면 규칙 없음")

	# 15R: 재굴림 -1, GameSession 연결
	var s: GameSession = GameSession.new(3)
	for i: int in range(14):
		s.flow.round_number = i + 2
		s.apply_round_rules()
	_eq(s.flow.get_reroll_limit(), GameBalance.REROLLS_PER_ROUND - 1, "15R: 재굴림 1회 감소")
	s.flow.round_number = 9
	s.apply_round_rules()
	_eq(s.flow.roll_modifiers.get("disabled_slots"), [0], "9R 진입 시 슬롯 정지 규칙 적용")
	_eq(s.flow.get_reroll_limit(), GameBalance.REROLLS_PER_ROUND, "9R은 재굴림 감소 없음")
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
