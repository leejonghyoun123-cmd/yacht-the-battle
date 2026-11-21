extends SceneTree
## Step 3c 한 판 진행 검증 + 자동 플레이 밸런스 리포트.
## 실행: godot --headless --path <프로젝트> --script res://tests/test_game_session.gd

var _pass_count: int = 0
var _fail_count: int = 0

## 자동 플레이 배치 전략: 주사위 순서대로 [병과, 칸]
## 중첩칸(가운데 줄): 전열 실드, 중열 소드, 후열 보우 / 소비칸: 캐논(후열 왼쪽), 소드(중열 오른쪽)
const AUTO_PLAN: Array = [
	[&"shield", 7], [&"sword", 4], [&"bow", 1], [&"cannon", 0], [&"sword", 5],
]


func _initialize() -> void:
	print("===== 야추 더 배틀 Step 3c 한 판 진행 테스트 =====")
	_test_flow_rules()
	_auto_play_report()
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


func _test_flow_rules() -> void:
	print("[한 판 진행 규칙]")
	var s: GameSession = GameSession.new(11)
	_eq(s.phase, GameSession.Phase.BARRACKS, "연병장에서 시작")
	_check(s.start_battle() == null, "배치 전에는 전투 불가")
	_check(s.go_to_rolling(), "주사위 테이블로 이동")
	_check(s.go_to_barracks() and s.go_to_rolling(), "연병장 ↔ 주사위 테이블 자유 이동")
	_check(s.can_sell_stack(), "굴림 화면에서도 중첩칸 판매 가능 (준비 시간)")
	s.flow.roll()
	s.flow.record_yacht(YachtBoard.Category.YACHT)
	_eq(s.phase, GameSession.Phase.PLACEMENT, "얏츠판 기록 → 배치 단계")
	_check(not s.can_sell_stack(), "배치 중에는 중첩칸 판매 불가 (되돌리기 꼬임 방지)")
	_eq(s.summons.size(), 5, "소환 5건")
	_check(s.place(0, &"sword", 4), "1번 주사위 소드를 중첩칸(4)에 배치")
	_check(not s.place(0, &"sword", 4), "이미 배치한 주사위는 다시 배치 불가")
	_check(not s.place(1, &"bow", 4), "다른 병과는 같은 칸 불가")
	_check(s.place(1, &"sword", 4), "같은 병과는 같은 칸에 중첩")
	_eq(s.board.cells[4].count, s.summons[0]["value"] + s.summons[1]["value"], "칸 인원 = 두 주사위 소환값 합")
	s.reset_placement()
	_check(s.board.cells[4].is_empty() and s.next_unplaced_index() == 0, "배치 초기화")
	for i: int in range(5):
		s.place(i, AUTO_PLAN[i][0], AUTO_PLAN[i][1])
	_check(s.all_placed(), "5개 모두 배치 완료")
	var sim: BattleSimulation = s.start_battle()
	_check(sim != null and s.phase == GameSession.Phase.BATTLE, "전투 시작")
	sim.run_to_end()
	var summary: Dictionary = s.settle_battle()
	_eq(summary["round"], 1, "1라운드 정산")
	_eq(s.get_round(), 2, "2라운드로 진행")
	_check(not s.board.cells[0].is_empty() and not s.board.cells[5].is_empty(), "9칸 모두 중첩칸: 전투 후에도 유지")
	_check(s.board.cells[4].count > 0, "중첩칸 유지")
	s.return_to_barracks()
	_eq(s.phase, GameSession.Phase.BARRACKS, "연병장으로 복귀")
	var gold_before: int = s.player.gold
	var price: int = s.board.get_stack_sell_price(4)
	_eq(s.sell_stack_cell(4), price, "연병장에서 중첩칸 판매")
	_eq(s.player.gold, gold_before + price, "판매 골드 지급")
	var hint: Dictionary = s.get_enemy_hint()
	_eq(hint["round"], 2, "적 힌트: 2라운드")
	_check(hint["units"].size() == 2, "적 힌트: 병과 2종 (실드·보우)")


## 시작 덱 + 고정 배치 전략으로 15라운드 자동 플레이 → 라운드별 결과 리포트
func _auto_play_report() -> void:
	print("[자동 플레이 밸런스 리포트 (시작 덱, 상점 없음, 단순 배치)]")
	for seed_value: int in [101, 202, 303]:
		var s: GameSession = GameSession.new(seed_value)
		var line: PackedStringArray = []
		while s.phase != GameSession.Phase.GAME_OVER:
			var r: int = s.get_round()
			s.go_to_rolling()
			s.flow.roll()
			# 재굴림 없이 가장 비싼 얏츠판 항목 기록
			var preview: Dictionary = s.flow.get_yacht_preview()
			var best: int = preview.keys()[0]
			for c: int in preview.keys():
				if preview[c] > preview[best]:
					best = c
			s.flow.record_yacht(best)
			var summoned: int = 0
			for i: int in range(5):
				s.place(i, AUTO_PLAN[i][0], AUTO_PLAN[i][1])
				summoned += s.summons[i]["value"]
			var army: int = s.board.get_total_count()
			var sim: BattleSimulation = s.start_battle()
			sim.run_to_end()
			var summary: Dictionary = s.settle_battle()
			var mark: String = "승" if summary["winner"] == 0 else ("패" if summary["winner"] == 1 else "무")
			line.append("%dR %s(아군%d/적%d,체%d,금%d)" % [r, mark, army, EnemyTable.get_total(r), s.player.hp, s.player.gold])
			if s.phase == GameSession.Phase.SETTLED:
				s.return_to_barracks()
		print("  시드 %d: %s" % [seed_value, " ".join(line)])
	_check(true, "자동 플레이 15라운드 완주 (게임 오버 포함) 오류 없음")
