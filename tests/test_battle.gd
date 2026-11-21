extends SceneTree
## Step 3a 전투 로직 자동 검증: 정예 압축, 배치판, 보스 소환 보정, 적 편성, 전투 결정론, 정산, 성능.
## 실행: godot --headless --path <프로젝트> --script res://tests/test_battle.gd

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	print("===== 야추 더 배틀 Step 3a 전투 로직 테스트 =====")
	_test_compression()
	_test_board_all_stack()
	# 예전 방식(가운데 줄만 중첩칸)도 설정 하나로 돌아갈 수 있는지 계속 검사
	GameBalance.ALL_CELLS_STACK = false
	_test_board()
	GameBalance.ALL_CELLS_STACK = true
	_test_boss_rules()
	_test_enemy_table()
	_test_battle_basic()
	_test_determinism()
	_test_timeout()
	GameBalance.ALL_CELLS_STACK = false
	_test_settlement()
	GameBalance.ALL_CELLS_STACK = true
	_test_settlement_all_stack()
	_test_performance()
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


func _board_with(cells: Dictionary) -> BoardState:
	var b: BoardState = BoardState.new()
	for idx: int in cells.keys():
		b.place(idx, cells[idx][0], cells[idx][1])
	return b


func _simulate(player: BoardState, enemy: BoardState, seed_value: int) -> BattleSimulation:
	var sim: BattleSimulation = BattleSimulation.new()
	sim.setup([player.get_spawn_packets(), enemy.get_spawn_packets()], seed_value)
	sim.run_to_end()
	return sim


func _test_compression() -> void:
	print("[정예 압축]")
	_eq(BattleRules.get_spawn_plan(30), { "spawn": 30, "ratio": 1.0 }, "30명 → 그대로 30 스폰")
	_eq(BattleRules.get_spawn_plan(300), { "spawn": 50, "ratio": 6.0 }, "300명 → 50 스폰, 배수 6")
	_eq(BattleRules.get_tier(1.0), 1, "배수 1 → 티어 1")
	_eq(BattleRules.get_tier(2.0), 2, "배수 2 → 티어 2 (은색)")
	_eq(BattleRules.get_tier(6.0), 3, "배수 6 → 티어 3 (금색)")
	_eq(BattleRules.get_tier(15.0), 4, "배수 15 → 티어 4 (붉은색)")
	var u: BattleUnit = BattleUnit.new()
	u.setup(0, 0, 0, UnitCatalog.get_unit(&"sword"), 6.0, false)
	_eq(u.max_hp, 600.0, "배수 6 소드 체력 100 → 600")
	_eq(u.attack, 60.0, "배수 6 소드 공격 10 → 60")


func _test_board() -> void:
	print("[배치판 — 예전 방식: 가운데 줄만 중첩칸]")
	var b: BoardState = BoardState.new()
	_check(b.cells[1].is_stack and b.cells[4].is_stack and b.cells[7].is_stack, "가운데 세로 줄(1·4·7)이 중첩칸")
	_check(not b.cells[0].is_stack and not b.cells[8].is_stack, "양옆 줄이 소비칸")
	_check(b.place(4, &"sword", 10), "빈칸에 소드 10명 배치")
	_check(b.place(4, &"sword", 5), "같은 병과는 같은 칸에 중첩")
	_eq(b.cells[4].count, 15, "누적 15명")
	_check(not b.place(4, &"bow", 5), "다른 병과는 같은 칸 불가")
	b.place(0, &"bow", 20)
	_eq(b.get_stack_sell_price(4), 15 * GameBalance.STACK_SELL_PER_UNIT, "중첩칸 판매가 = 누적 인원 × 단가")
	_eq(b.get_stack_sell_price(0), 0, "소비칸은 준비 단계 판매 대상 아님")
	b.cells[4].count = 300
	_eq(b.get_stack_sell_price(4), 300 * GameBalance.STACK_SELL_PER_UNIT, "스폰 50이어도 누적 300 기준으로 판매가 산정")
	_eq(b.sell_stack_cell(4), 600, "판매 시 골드 반환")
	_check(b.cells[4].is_empty(), "판매 후 칸 비움")
	b.place(4, &"shield", 40)
	b.clear_consumables()
	_check(b.cells[0].is_empty() and b.cells[4].count == 40, "소비칸만 비우고 중첩칸 유지")
	b.apply_stack_retention({ 4: 3.0 })
	_eq(b.cells[4].count, 40, "기본 정책: 전투 사망으로 중첩칸 인원 감소 없음")
	b.retention_policy = StackRetentionPolicy.new(StackRetentionPolicy.Mode.KEEP_SURVIVORS)
	b.apply_stack_retention({ 4: 12.0 })
	_eq(b.cells[4].count, 12, "정책 교체 시 생존자만 유지 (교체 가능 확인)")


func _test_boss_rules() -> void:
	print("[보스 소환 보정]")
	var r: DiceRollResult = DiceRollResult.new()
	r.raw_roll = 2
	r.summon_value = 15
	_eq(BossRules.modify_summon(3, r)["value"], 8, "3R: 눈금 2 → 15의 50% = 7.5 → 8")
	_eq(BossRules.modify_summon(2, r)["value"], 15, "보스 라운드가 아니면 그대로")
	_eq(BossRules.modify_summon(3, r, true)["value"], 15, "뼈주사위(면역)는 무시")
	r.raw_roll = 4
	_eq(BossRules.modify_summon(3, r)["value"], 15, "3R: 눈금 4는 해당 없음")
	r.summon_value = 20
	_eq(BossRules.modify_summon(6, r)["value"], 12, "6R: 짝수 20 → 40% 감소 = 12")
	r.summon_value = 21
	_eq(BossRules.modify_summon(6, r)["value"], 21, "6R: 홀수는 그대로")


func _test_enemy_table() -> void:
	print("[적 편성]")
	for round_number: int in [1, 3, 7, 14, 15]:
		_eq(EnemyTable.build_board(round_number).get_total_count(), EnemyTable.get_total(round_number), "%dR 환산 인원 합계 일치" % round_number)
	var r2: BoardState = EnemyTable.build_board(2)
	_eq(r2.cells[BoardState.index_of(2, 1)].unit_id, &"shield", "2R: 실드는 전열 가운데")
	_eq(r2.cells[BoardState.index_of(0, 1)].unit_id, &"bow", "2R: 보우는 후열 가운데")
	_eq(EnemyTable.get_total(16), roundi(4000 * 1.35), "16R 무한모드 1.35배")


func _test_battle_basic() -> void:
	print("[전투 기본]")
	var strong: BoardState = _board_with({ 4: [&"sword", 60], 7: [&"shield", 40] })
	var weak: BoardState = _board_with({ 4: [&"sword", 10] })
	var sim: BattleSimulation = _simulate(strong, weak, 1)
	_eq(sim.result.winner, 0, "강한 쪽(플레이어) 승리")
	_eq(sim.result.reason, "annihilation", "전멸로 종료")
	_check(sim.result.survivor_totals[0] > 0.0, "승자 생존자 존재", str(sim.result.survivor_totals))
	var sim2: BattleSimulation = _simulate(weak, strong, 1)
	_eq(sim2.result.winner, 1, "반대로 놓으면 적 승리")

	var phases: Array[int] = []
	var tracker: BattleSimulation = BattleSimulation.new()
	tracker.setup([strong.get_spawn_packets(), weak.get_spawn_packets()], 5)
	tracker.phase_changed.connect(func(p: int) -> void: phases.append(p))
	var whistle_time: float = -1.0
	while not tracker.is_finished():
		tracker.step()
		for e: Dictionary in tracker.events:
			if e["type"] == "whistle":
				whistle_time = tracker.total_time
	_eq(phases.slice(0, 3), [BattleSimulation.Phase.WHISTLE, BattleSimulation.Phase.FIGHT, BattleSimulation.Phase.ENDED] as Array[int], "진열 → 호각 대기 → 교전 → 종료 순서")
	_check(whistle_time >= BattleRules.WHISTLE_DELAY, "진열 후 3초 뒤 호각", "호각 시각 %.2f초" % whistle_time)

	var big: BoardState = _board_with({ 4: [&"sword", 300] })
	var sim3: BattleSimulation = BattleSimulation.new()
	sim3.setup([big.get_spawn_packets(), weak.get_spawn_packets()], 1)
	var team0: int = 0
	for u: BattleUnit in sim3.units:
		if u.team == 0:
			team0 += 1
	_eq(team0, 50, "300명 칸 → 실제 스폰 50개체")
	_eq(sim3.units[0].tier, 3, "배수 6 → 금색 티어")


func _test_determinism() -> void:
	print("[결정론 (멀티·스킵 대비)]")
	var a: BoardState = _board_with({ 1: [&"cannon", 40], 4: [&"sword", 80], 7: [&"shield", 50], 0: [&"bow", 30] })
	var e: BoardState = EnemyTable.build_board(5)
	var r1: BattleResult = _simulate(a, e, 777).result
	var r2: BattleResult = _simulate(a, e, 777).result
	_check(r1.winner == r2.winner and is_equal_approx(r1.fight_duration, r2.fight_duration)
		and is_equal_approx(r1.survivor_totals[0], r2.survivor_totals[0])
		and is_equal_approx(r1.survivor_totals[1], r2.survivor_totals[1]), "같은 입력·시드 → 완전히 같은 결과",
		"%s vs %s" % [str(r1.survivor_totals), str(r2.survivor_totals)])
	print("    5R(115명, 실드+힐러+보우) 상대: 승자 팀 %d, %.1f초, 생존 %s" % [r1.winner, r1.fight_duration, str(r1.survivor_totals)])


func _test_timeout() -> void:
	print("[60초 제한]")
	# 서로 닿지 않는 상황을 만들기 위해 이동속도 0인 유닛 데이터 사용
	var frozen: UnitData = (UnitCatalog.get_unit(&"sword").duplicate() as UnitData)
	frozen.move_speed = 0.0
	var p0: SpawnPacket = SpawnPacket.new()
	p0.cell_index = 4
	p0.unit_data = frozen
	p0.total_count = 20
	var p1: SpawnPacket = SpawnPacket.new()
	p1.cell_index = 4
	p1.unit_data = frozen
	p1.total_count = 10
	var sim: BattleSimulation = BattleSimulation.new()
	sim.setup([[p0], [p1]], 3)
	sim.run_to_end()
	_eq(sim.result.reason, "timeout", "60초 초과로 종료")
	_eq(sim.result.winner, 0, "남은 환산 체력이 많은 쪽 승리")
	_check(absf(sim.result.fight_duration - BattleRules.FIGHT_TIME_LIMIT) < 0.1, "교전 시간 60초", str(sim.result.fight_duration))


func _test_settlement() -> void:
	print("[정산]")
	var player: PlayerState = PlayerState.new()
	var streak: StreakState = StreakState.new()
	var board: BoardState = _board_with({ 4: [&"sword", 40], 0: [&"bow", 20] })
	var win: BattleResult = BattleResult.new()
	win.winner = 0
	win.survivors_by_cell = [{ 4: 30.0, 0: 12.0 }, {}]
	var gold_before: int = player.gold
	var s: Dictionary = BattleSettlement.settle_solo(win, player, board, streak, 1)
	_eq(s["sale_count"], 12, "소비칸 생존 12명 판매")
	_eq(player.gold - gold_before, GameBalance.WIN_BONUS + 12 * GameBalance.CONSUMABLE_SALE_PER_UNIT, "승리 보너스 + 판매금 (1연승은 보상 없음)")
	_check(board.cells[0].is_empty() and board.cells[4].count == 40, "소비칸 비움, 중첩칸 유지")
	board.place(0, &"bow", 20)
	var gold_mid: int = player.gold
	BattleSettlement.settle_solo(win, player, board, streak, 2)
	_eq(player.gold - gold_mid, GameBalance.WIN_BONUS + 100 + 12 * GameBalance.CONSUMABLE_SALE_PER_UNIT, "2연승 보상 +100")

	var lose: BattleResult = BattleResult.new()
	lose.winner = 1
	lose.survivor_totals = [0.0, 120.0]
	board.place(0, &"bow", 20)
	var hp_before: int = player.hp
	var s2: Dictionary = BattleSettlement.settle_solo(lose, player, board, streak, 2)
	_eq(s2["damage"], 75, "패배: 적 생존 120 → 1~6R 상한 75")
	_eq(player.hp, hp_before - 75, "체력 75 감소")
	_eq(s2["sale_count"], 0, "패배 시 소비칸 판매 없음")
	_check(board.cells[0].is_empty(), "패배해도 소비칸 비움")
	_eq(streak.win_streak, 0, "패배로 연승 끊김")
	BattleSettlement.settle_solo(lose, player, board, streak, 13)
	_eq(player.hp, hp_before - 75 - 120, "13R 이후 상한 없음 (120 피해)")


func _test_performance() -> void:
	print("[성능: 최대 규모 450 vs 450]")
	var full_a: BoardState = BoardState.new()
	var full_b: BoardState = BoardState.new()
	var ids: Array[StringName] = [&"shield", &"sword", &"shield", &"sword", &"sword", &"sword", &"bow", &"cannon", &"healer"]
	for i: int in range(9):
		full_a.place(i, ids[i], 500)
		full_b.place(i, ids[i], 450)
	var sim: BattleSimulation = BattleSimulation.new()
	sim.setup([full_a.get_spawn_packets(), full_b.get_spawn_packets()], 9)
	_eq(sim.units.size(), 900, "900개체 스폰 (칸당 50 상한)")
	var start: int = Time.get_ticks_usec()
	var steps: int = 0
	while not sim.is_finished():
		sim.step()
		steps += 1
	var ms: float = float(Time.get_ticks_usec() - start) / 1000.0
	var per_step: float = ms / float(steps)
	print("    %d step, 총 %.0fms, step당 %.2fms (실시간 1배속 예산: 33ms/프레임당 1step)" % [steps, ms, per_step])
	print("    결과: 승자 팀 %d, %s, %.1f초" % [sim.result.winner, sim.result.reason, sim.result.fight_duration])
	_check(per_step < 8.0, "step당 8ms 미만 (4배속에서도 프레임당 32ms 이내)", "%.2fms" % per_step)


func _test_board_all_stack() -> void:
	print("[배치판 — 기본: 9칸 모두 중첩칸]")
	var b: BoardState = BoardState.new()
	var all: bool = true
	for c: CellState in b.cells:
		all = all and c.is_stack
	_check(all, "9칸 모두 중첩칸")
	b.place(0, &"bow", 20)
	_eq(b.get_stack_sell_price(0), 20 * GameBalance.STACK_SELL_PER_UNIT, "양옆 칸도 판매 가능")
	b.clear_consumables()
	_eq(b.cells[0].count, 20, "전투 후 비워지는 칸 없음")
	_check(not b.get_spawn_packets()[0].is_consumable, "스폰도 중첩칸으로")


func _test_settlement_all_stack() -> void:
	print("[정산 — 9칸 모두 중첩칸]")
	var player: PlayerState = PlayerState.new()
	var streak: StreakState = StreakState.new()
	var board: BoardState = _board_with({ 4: [&"sword", 40], 0: [&"bow", 20] })
	var win: BattleResult = BattleResult.new()
	win.winner = 0
	win.survivors_by_cell = [{ 4: 30.0, 0: 12.0 }, {}]
	var gold_before: int = player.gold
	var s: Dictionary = BattleSettlement.settle_solo(win, player, board, streak, 1)
	_eq(s["sale_count"], 0, "판매할 소비칸 생존자 없음")
	_eq(player.gold - gold_before, GameBalance.WIN_BONUS, "승리 보너스만")
	_check(board.cells[0].count == 20 and board.cells[4].count == 40, "모든 칸 유지")
	var lose: BattleResult = BattleResult.new()
	lose.winner = 1
	lose.survivor_totals = [0.0, 10.0]
	BattleSettlement.settle_solo(lose, player, board, streak, 2)
	_check(board.cells[0].count == 20, "패배해도 칸 유지")
