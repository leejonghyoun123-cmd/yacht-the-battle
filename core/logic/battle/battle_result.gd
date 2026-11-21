class_name BattleResult
extends RefCounted
## 전투 결과 (정산 입력). 팀 0 = 플레이어(또는 방장), 1 = 적(또는 상대)

const DRAW: int = -1

var winner: int = DRAW
## "annihilation"(전멸) / "timeout"(60초 초과 → 남은 체력 비교)
var reason: String = ""
var fight_duration: float = 0.0
## [팀] → { cell_index: 생존 환산 인원(float) }
var survivors_by_cell: Array[Dictionary] = [{}, {}]
## [팀] → 생존 환산 인원 합
var survivor_totals: Array[float] = [0.0, 0.0]
## [팀] → 남은 체력 합 (시간 초과 판정용)
var remaining_hp: Array[float] = [0.0, 0.0]


func get_survivor_total(team: int) -> int:
	return roundi(survivor_totals[team])


## 소비칸 생존자 환산 인원 합 (판매용)
func get_consumable_survivors(team: int, board: BoardState) -> int:
	var total: float = 0.0
	for cell_index: int in survivors_by_cell[team].keys():
		if not board.cells[cell_index].is_stack:
			total += survivors_by_cell[team][cell_index]
	return roundi(total)
