extends SceneTree
## Step 2 로직 자동 검증: 이중 덱, 덱 잠금, 재굴림, 얏츠판 기록, 라운드 진행.
## 실행: godot --headless --path <프로젝트> --script res://tests/test_round_flow.gd

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	print("===== 야추 더 배틀 Step 2 라운드 흐름 테스트 =====")
	_test_deck_swap()
	_test_lock_rules()
	_test_reroll_and_hold()
	_test_record_and_advance()
	_test_boss_table()
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


func _new_flow(seed_value: int = 99) -> RoundFlow:
	var deck: DeckManager = DeckManager.new()
	StarterDeck.build_into(deck)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return RoundFlow.new(PlayerState.new(), deck, YachtBoard.new(), rng)


func _test_deck_swap() -> void:
	print("[이중 덱 교체]")
	var flow: RoundFlow = _new_flow()
	var deck: DeckManager = flow.deck
	_eq(deck.active.size(), 5, "활성 5개")
	var a0: DiceInstance = deck.active[0]
	var r0: DiceInstance = deck.reserve[0]
	_check(deck.swap_slots(0, 0), "활성1 ↔ 예비1 교체")
	_check(deck.active[0] == r0 and deck.reserve[0] == a0, "교체 결과 반영")
	_check(not deck.swap_slots(1, 2), "빈 예비칸(잠김)과는 교체 불가")
	var before: Array[DiceInstance] = deck.active.duplicate()
	var r1: DiceInstance = deck.reserve[1]
	_check(deck.swap_active_and_reserve(), "[덱 스왑] 실행")
	_check(deck.active[0] == a0 and deck.active[1] == r1 and deck.reserve[1] == before[1], "개방된 예비 2칸과 활성 1·2번이 맞바뀜")
	_check(deck.active[2] == before[2] and deck.active[4] == before[4], "나머지 활성 3~5번은 그대로")
	_eq(deck.active.size(), 5, "스왑 후에도 활성 5개 유지")


func _test_lock_rules() -> void:
	print("[첫 굴림 후 덱 잠금]")
	var flow: RoundFlow = _new_flow()
	_check(flow.deck.move_enchant(flow.deck.active[1], 0, 1), "굴림 전 인첸트 순서 변경 가능")
	_check(flow.roll(), "첫 굴림")
	_check(flow.deck.is_deck_locked, "덱 잠금됨")
	_check(not flow.deck.swap_slots(0, 0), "잠금 후 교체 불가")
	_check(not flow.deck.swap_active_and_reserve(), "잠금 후 덱 스왑 불가")
	_check(not flow.deck.move_enchant(flow.deck.active[1], 0, 1), "잠금 후 인첸트 순서 변경 불가")


func _test_reroll_and_hold() -> void:
	print("[재굴림 · 고정]")
	var flow: RoundFlow = _new_flow()
	_check(not flow.toggle_hold(0), "굴리기 전에는 고정 불가")
	flow.roll()
	_eq(flow.rerolls_left, GameBalance.REROLLS_PER_ROUND, "첫 굴림 후 재굴림 3회")
	var first_raw: int = flow.results[2].raw_roll
	flow.toggle_hold(2)
	flow.roll()
	_eq(flow.results[2].raw_roll, first_raw, "고정한 주사위는 눈금 유지")
	_eq(flow.rerolls_left, 2, "재굴림 1회 소모")
	for i: int in range(5):
		if not flow.held[i]:
			flow.toggle_hold(i)
	_check(not flow.can_roll(), "전부 고정하면 재굴림 불가")
	flow.toggle_hold(0)
	flow.roll()
	flow.roll()
	_eq(flow.rerolls_left, 0, "재굴림 모두 소진")
	_check(not flow.roll(), "횟수 소진 후 굴림 불가")
	flow.reroll_penalty = 10
	_eq(flow.get_reroll_limit(), GameBalance.MIN_REROLLS, "보정 후에도 최소 1회 보장")


func _test_record_and_advance() -> void:
	print("[얏츠판 기록 · 라운드 진행]")
	var flow: RoundFlow = _new_flow()
	var start_gold: int = flow.player.gold
	_check(not flow.record_yacht(YachtBoard.Category.ACES), "굴리기 전에는 기록 불가")
	_check(not flow.advance_round(), "기록 전에는 다음 라운드 불가")
	flow.roll()
	var preview: Dictionary = flow.get_yacht_preview()
	_eq(preview.size(), 12, "미기록 12항목 미리보기")
	var expected_gold: int = preview[YachtBoard.Category.YACHT]
	_check(flow.record_yacht(YachtBoard.Category.YACHT), "얏츠 항목 기록 (불성립이면 0원)")
	_eq(flow.player.gold, start_gold + expected_gold, "미리보기 금액만큼 골드 지급")
	_check(not flow.roll(), "기록 후 재굴림 불가")
	_check(flow.advance_round(), "다음 라운드")
	_eq(flow.round_number, 2, "2라운드")
	_eq(flow.player.gold, start_gold + expected_gold + GameBalance.ROUND_INCOME, "라운드 수입 지급")
	_check(not flow.deck.is_deck_locked, "덱 잠금 해제")
	_eq(flow.phase, RoundFlow.Phase.PREP, "준비 단계로 복귀")
	flow.roll()
	_check(not flow.record_yacht(YachtBoard.Category.YACHT), "이미 기록한 항목은 다시 기록 불가")
	_eq(flow.get_yacht_preview().size(), 11, "남은 11항목만 미리보기")


func _test_boss_table() -> void:
	print("[보스 예고]")
	_eq(LevelTable.get_upcoming_boss(1)["round"], 3, "1R → 3R 보스 예고")
	_eq(LevelTable.get_upcoming_boss(3)["rounds_left"], 0, "3R은 보스 라운드")
	_eq(LevelTable.get_upcoming_boss(4)["name"], "홀짝의 심판관", "4R → 6R 홀짝의 심판관")
	_eq(LevelTable.get_upcoming_boss(16).size(), 0, "16R 이후는 아직 정보 없음")
	_eq(GameBalance.get_damage_cap(6), 75, "6R 피격 상한 75")
	_eq(GameBalance.get_damage_cap(7), 100, "7R 피격 상한 100")
	_eq(GameBalance.get_damage_cap(13), 0, "13R 상한 없음")
