class_name GameSession
extends RefCounted
## 솔로 한 판 진행 (UI 없는 순수 로직).
##   BARRACKS  : 연병장(준비). 중첩칸 판매·덱 편집 가능 → [주사위 굴리기]
##   ROLLING   : RoundFlow로 굴림·재굴림 → 얏츠판 기록
##   PLACEMENT : 주사위마다 병과 선택 → 칸에 소환 (보스 소환 보정 적용)
##   BATTLE    : 전투 시뮬레이션 진행 (화면이 step을 돌림)
##   SETTLED   : 정산 완료 → 다음 라운드 연병장 / 게임 오버 / 15R 클리어

signal changed
signal phase_changed(new_phase: Phase)
signal game_over(cleared: bool)

enum Phase { BARRACKS, ROLLING, PLACEMENT, BATTLE, SETTLED, GAME_OVER }

var player: PlayerState
var deck: DeckManager
var yacht: YachtBoard
var flow: RoundFlow
var board: BoardState
var streak: StreakState
var rng: RandomNumberGenerator

var phase: Phase = Phase.BARRACKS
## 소환 목록: [{ "dice_index", "base", "value", "reason", "placed", "unit_id", "cell" }]
var summons: Array[Dictionary] = []
var battle: BattleSimulation = null
var last_summary: Dictionary = {}
var _board_snapshot: Array = []


func _init(seed_value: int = 0) -> void:
	rng = RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	player = PlayerState.new()
	deck = DeckManager.new()
	StarterDeck.build_plain_into(deck)
	yacht = YachtBoard.new()
	flow = RoundFlow.new(player, deck, yacht, rng)
	board = BoardState.new()
	streak = StreakState.new()
	shop = ShopState.new(player, deck, rng)
	shop.restock(flow.round_number)
	timer = RoundTimer.new()
	timer.reset()
	flow.yacht_recorded.connect(_on_yacht_recorded)


## 상점 (연병장에서 이동)
var shop: ShopState
## 준비 시간 타이머 (1분 30초 + 1회 30초 연장). 화면이 tick을 넘겨주고, 만료 시 auto_finalize 호출.
var timer: RoundTimer


## 준비 단계인가 (연병장·굴림·배치 — 전투 전)
func is_preparing() -> bool:
	return phase == Phase.BARRACKS or phase == Phase.ROLLING or phase == Phase.PLACEMENT


## 굴림 화면 → 연병장 (화면은 자유롭게 오갈 수 있다)
func go_to_barracks() -> bool:
	if phase == Phase.ROLLING:
		_set_phase(Phase.BARRACKS)
		return true
	return phase == Phase.BARRACKS


## 준비 시간 만료: 굴리지 않았으면 자동 굴림 → 가장 비싼 얏츠판 항목 기록 →
## 남은 주사위는 소드로 빈 소비칸(없으면 소드를 받을 수 있는 칸)에 소환 → 전투 시작.
func auto_finalize() -> BattleSimulation:
	if phase == Phase.BARRACKS or phase == Phase.ROLLING:
		if phase == Phase.BARRACKS:
			_set_phase(Phase.ROLLING)
		if flow.phase == RoundFlow.Phase.PREP:
			flow.roll()
		var preview: Dictionary = flow.get_yacht_preview()
		var best: int = -1
		for c: int in preview.keys():
			if best < 0 or preview[c] > preview[best]:
				best = c
		flow.record_yacht(best)
	if phase != Phase.PLACEMENT:
		return null
	for i: int in range(summons.size()):
		if summons[i]["placed"]:
			continue
		var target: Dictionary = _auto_target()
		place(i, target["unit"], target["cell"])
	return start_battle()


## 자동 소환 위치: 소드를 받을 수 있는 소비칸 → 중첩칸 → (없으면) 첫 칸의 병과 그대로
func _auto_target() -> Dictionary:
	for stack_pass: bool in [false, true]:
		for cell: CellState in board.cells:
			if cell.is_stack == stack_pass and cell.can_accept(&"sword"):
				return { "unit": &"sword", "cell": cell.index }
	return { "unit": board.cells[0].unit_id, "cell": 0 }


func get_round() -> int:
	return flow.round_number


# --- 연병장 (준비) ---------------------------------------------------------

## 중첩칸 판매: 연병장·굴림 단계 (배치 중에는 이번 라운드 소환과 섞여 되돌리기가 꼬이므로 불가)
func can_sell_stack() -> bool:
	return phase == Phase.BARRACKS or phase == Phase.ROLLING


## 중첩칸 판매 (준비 단계에서만). 받은 골드 반환.
func sell_stack_cell(cell_index: int) -> int:
	if not can_sell_stack():
		return 0
	var gold: int = board.sell_stack_cell(cell_index)
	if gold > 0:
		player.add_gold(gold, PlayerState.GoldSource.OTHER)
		changed.emit()
	return gold


## 연병장 → 주사위 테이블
func go_to_rolling() -> bool:
	if phase == Phase.ROLLING:
		return true
	if phase != Phase.BARRACKS:
		return false
	_set_phase(Phase.ROLLING)
	return true


## 적 정보 힌트 (솔로: 대략적인 규모와 병과)
func get_enemy_hint() -> Dictionary:
	var r: int = get_round()
	var names: PackedStringArray = []
	for id: StringName in EnemyTable.get_unit_ids(r):
		names.append(UnitCatalog.get_unit(id).display_name)
	return {
		"round": r,
		"approx_total": _approximate(EnemyTable.get_total(r)),
		"units": names,
		"boss": LevelTable.BOSSES.get(r, {}),
	}


static func _approximate(value: int) -> int:
	if value < 20:
		return value
	var magnitude: int = int(pow(10.0, floorf(log(float(value)) / log(10.0)) - 1.0))
	return int(roundf(float(value) / float(magnitude))) * magnitude


# --- 배치 -------------------------------------------------------------------

func _on_yacht_recorded(_category: int, _gold: int) -> void:
	summons.clear()
	for result: DiceRollResult in flow.results:
		var mod: Dictionary = BossRules.modify_summon(get_round(), result)
		summons.append({
			"dice_index": result.dice_index, "base": result.summon_value,
			"value": mod["value"], "reason": mod["reason"],
			"placed": false, "unit_id": &"", "cell": -1,
		})
	_board_snapshot = board.to_dict()
	_set_phase(Phase.PLACEMENT)


func can_place(summon_index: int, unit_id: StringName, cell_index: int) -> bool:
	if phase != Phase.PLACEMENT or summon_index < 0 or summon_index >= summons.size():
		return false
	if summons[summon_index]["placed"]:
		return false
	return board.can_place(cell_index, unit_id)


func place(summon_index: int, unit_id: StringName, cell_index: int) -> bool:
	if not can_place(summon_index, unit_id, cell_index):
		return false
	board.place(cell_index, unit_id, summons[summon_index]["value"])
	summons[summon_index]["placed"] = true
	summons[summon_index]["unit_id"] = unit_id
	summons[summon_index]["cell"] = cell_index
	changed.emit()
	return true


func next_unplaced_index() -> int:
	for i: int in range(summons.size()):
		if not summons[i]["placed"]:
			return i
	return -1


func all_placed() -> bool:
	return phase == Phase.PLACEMENT and next_unplaced_index() == -1


## 이번 라운드 배치를 모두 되돌린다
func reset_placement() -> void:
	if phase != Phase.PLACEMENT:
		return
	_restore_board(_board_snapshot)
	for s: Dictionary in summons:
		s["placed"] = false
		s["unit_id"] = &""
		s["cell"] = -1
	changed.emit()


func _restore_board(snapshot: Array) -> void:
	for entry: Dictionary in snapshot:
		var cell: CellState = board.cells[entry["index"]]
		cell.unit_id = StringName(entry["unit"])
		cell.count = entry["count"]
	board.board_changed.emit()


# --- 전투 ·정산 --------------------------------------------------------------

## 배치 완료 → 전투 시뮬레이션 생성 (화면이 step을 돌리거나 run_to_end로 스킵)
func start_battle() -> BattleSimulation:
	if not all_placed():
		return null
	battle = BattleSimulation.new()
	var enemy: BoardState = EnemyTable.build_board(get_round())
	battle.setup([board.get_spawn_packets(), enemy.get_spawn_packets()], rng.randi())
	timer.stop()
	_set_phase(Phase.BATTLE)
	return battle


## 전투 결과 정산. 게임 오버가 아니면 다음 라운드로 넘어가 연병장으로 돌아온다.
func settle_battle() -> Dictionary:
	if phase != Phase.BATTLE or battle == null or not battle.is_finished():
		return {}
	var finished_round: int = get_round()
	last_summary = BattleSettlement.settle_solo(battle.result, player, board, streak, finished_round)
	last_summary["round"] = finished_round
	battle = null
	# 성벽증축 임시 실드는 해당 라운드에만 유효
	player.round_shield = 0
	if player.is_dead():
		_set_phase(Phase.GAME_OVER)
		game_over.emit(false)
		return last_summary
	if finished_round >= LevelTable.FINAL_ROUND:
		# 15R 결과로 한 판 종료 (승리 = 클리어). 무한모드 연결은 이후 단계에서.
		_set_phase(Phase.GAME_OVER)
		game_over.emit(last_summary["winner"] == 0)
		return last_summary
	flow.advance_round()
	shop.restock(get_round())
	shop.free_reroll = streak.has_free_reroll()
	_set_phase(Phase.SETTLED)
	return last_summary


## 정산 화면 확인 후 연병장으로
func return_to_barracks() -> void:
	if phase == Phase.SETTLED:
		timer.reset()
		_set_phase(Phase.BARRACKS)


func _set_phase(p: Phase) -> void:
	phase = p
	phase_changed.emit(p)
	changed.emit()
