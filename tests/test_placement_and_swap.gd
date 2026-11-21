extends SceneTree
## 연병장 덮어쓰기 배치·주사위 순환 교체·선택 전체 교체 검증
## 실행: godot --headless --path <프로젝트> --script res://tests/test_placement_and_swap.gd

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	print("===== 배치 덮어쓰기 · 주사위 교체 테스트 =====")
	_test_replace()
	_test_pick_swap()
	_test_swap_selected()
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


func _to_placement(s: GameSession) -> void:
	s.go_to_rolling()
	s.flow.roll()
	s.flow.record_yacht(YachtBoard.Category.YACHT)


func _test_replace() -> void:
	print("[덮어쓰기 배치]")
	var s: GameSession = GameSession.new(7)
	s.board.place(4, &"sword", 100)  # 이전 라운드부터 있던 중첩칸 소드 100명
	_to_placement(s)
	_eq(s.get_replace_info(4, &"sword")["needed"], false, "같은 병과는 덮어쓰기 아님")
	_check(not s.can_place(0, &"giant", 0), "없는 병과(거인)는 배치 불가")
	s.place(0, &"sword", 4)
	var info: Dictionary = s.get_replace_info(4, &"bow")
	_check(info["needed"], "다른 병과 → 덮어쓰기 필요")
	_eq(info["sell_count"], 100, "판매 대상은 이전부터 있던 100명만")
	_eq(info["sell_gold"], 100 * GameBalance.STACK_SELL_PER_UNIT, "판매가 = 100 × 중첩칸 단가")
	_eq(info["returned"], [0] as Array[int], "이번 라운드에 놓은 주사위1은 되돌림")
	var gold: int = s.player.gold
	_check(s.replace_and_place(1, &"bow", 4), "보우로 덮어쓰기 배치")
	_eq(s.player.gold - gold, 200, "기존 유닛 자동 판매 골드 지급")
	_eq(s.board.cells[4].unit_id, &"bow", "칸이 보우로 바뀜")
	_eq(s.board.cells[4].count, s.summons[1]["value"], "칸 인원 = 이번 주사위 소환값")
	_check(not s.summons[0]["placed"], "주사위1은 다시 배치 대기")
	s.reset_placement()
	_check(s.board.cells[4].is_empty(), "배치 초기화해도 판매한 소드는 되살아나지 않음")


## [⇅ 교체] 버튼이 쓰는 1:1 교체 (가방에서 고른 주사위와 맞바꿈)
func _test_pick_swap() -> void:
	print("[⇅ 교체: 가방 주사위 골라 교체]")
	var deck: DeckManager = DeckManager.new()
	StarterDeck.build_plain_into(deck)
	var a: DiceInstance = deck.active[2]
	var b1: DiceInstance = DiceInstance.new(load("res://data/dice/d6.tres"))
	var b2: DiceInstance = DiceInstance.new(load("res://data/dice/d6.tres"))
	deck.add_to_reserve(b1)
	deck.add_to_reserve(b2)
	_check(deck.swap_slots(2, 1), "출전3 ↔ 가방2 교체")
	_check(deck.active[2] == b2 and deck.reserve[1] == a, "고른 가방 주사위가 출전, 기존 주사위는 그 가방 칸으로")
	deck.lock()
	_check(not deck.swap_slots(2, 0), "굴린 뒤에는 교체 불가")


func _test_swap_selected() -> void:
	print("[전체 교체 (가방 주사위 수만큼 선택)]")
	var deck: DeckManager = DeckManager.new()
	StarterDeck.build_plain_into(deck)
	var b1: DiceInstance = DiceInstance.new(load("res://data/dice/d6.tres"))
	var b2: DiceInstance = DiceInstance.new(load("res://data/dice/d6.tres"))
	deck.add_to_reserve(b1)
	deck.add_to_reserve(b2)
	var old1: DiceInstance = deck.active[1]
	var old3: DiceInstance = deck.active[3]
	_check(not deck.swap_selected([1] as Array[int]), "가방 2개인데 1개만 고르면 실패")
	_check(deck.swap_selected([1, 3] as Array[int]), "주사위2·4 선택 후 교체")
	_check(deck.active[1] == b1 and deck.active[3] == b2, "고른 자리에 가방 주사위 출전")
	_check(deck.reserve[0] == old1 and deck.reserve[1] == old3, "기존 주사위는 가방으로")
