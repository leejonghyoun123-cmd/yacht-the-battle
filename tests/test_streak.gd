extends SceneTree
## 연승·연패 보상 지급 검증
## 실행: godot --headless --path <프로젝트> --script res://tests/test_streak.gd

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	print("===== 연승·연패 보상 테스트 =====")
	var player: PlayerState = PlayerState.new()
	player.hp = 10000
	player.max_hp = 10000
	var streak: StreakState = StreakState.new()
	var board: BoardState = BoardState.new()
	var lose: BattleResult = BattleResult.new()
	lose.winner = 1
	lose.survivor_totals = [0.0, 10.0]
	var expected: Array[int] = [0, 50, 100, 150, 200, 200]
	for i: int in range(expected.size()):
		var before: int = player.gold
		var s: Dictionary = BattleSettlement.settle_solo(lose, player, board, streak, 1)
		_eq(player.gold - before, expected[i], "%d연패 보상 %d원 지급" % [i + 1, expected[i]])
		_eq(s["streak_bonus"], expected[i], "%d연패 정산 요약에 표시" % (i + 1))
	_check(streak.has_free_reroll(), "5연패 이상 무료 리롤")
	var win: BattleResult = BattleResult.new()
	win.winner = 0
	win.survivors_by_cell = [{}, {}]
	BattleSettlement.settle_solo(win, player, board, streak, 1)
	_eq(streak.loss_streak, 0, "승리하면 연패 초기화")
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
