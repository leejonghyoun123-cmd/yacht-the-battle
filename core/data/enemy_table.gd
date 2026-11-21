class_name EnemyTable
extends RefCounted
## 1인용 라운드별 적군 (06 레벨 디자인 기획서). 중첩 분기 특성은 아직 미적용(기본 병과).
## 환산 인원을 구성 병과에 균등 분배하고, 병과마다 한 칸씩 역할 열에 자동 배치한다.

const ARMIES: Dictionary = {
	1: { "total": 15, "units": [&"sword"] },
	2: { "total": 30, "units": [&"shield", &"bow"] },
	3: { "total": 55, "units": [&"shield", &"bow"] },
	4: { "total": 80, "units": [&"cannon", &"sword"] },
	5: { "total": 115, "units": [&"shield", &"healer", &"bow"] },
	6: { "total": 160, "units": [&"sword", &"healer", &"cannon"] },
	7: { "total": 220, "units": [&"giant", &"bow"] },
	8: { "total": 310, "units": [&"healer", &"sword", &"shield"] },
	9: { "total": 420, "units": [&"giant", &"healer", &"cannon"] },
	10: { "total": 600, "units": [&"sword", &"bow", &"shield"] },
	11: { "total": 950, "units": [&"cannon", &"healer", &"giant"] },
	12: { "total": 1400, "units": [&"shield", &"bow", &"healer", &"giant"] },
	13: { "total": 2100, "units": [&"giant", &"healer"] },
	14: { "total": 3000, "units": [&"sword", &"bow", &"shield", &"cannon", &"healer", &"giant"] },
	15: { "total": 4000, "units": [&"sword", &"bow", &"shield", &"cannon", &"healer", &"giant"] },
}

## 무한모드 배율 (16R~ 1.35배, 25R~ 1.5배)
const ENDLESS_GROWTH: float = 1.35
const ENDLESS_GROWTH_LATE: float = 1.5


static func get_total(round_number: int) -> int:
	if ARMIES.has(round_number):
		return ARMIES[round_number]["total"]
	var total: float = float(ARMIES[15]["total"])
	for r: int in range(16, round_number + 1):
		total *= ENDLESS_GROWTH_LATE if r >= 25 else ENDLESS_GROWTH
	return int(minf(total, float(FixedNum.MAX / FixedNum.SCALE)))


static func get_unit_ids(round_number: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	var source: Array = ARMIES[round_number]["units"] if ARMIES.has(round_number) else ARMIES[15]["units"]
	for id: StringName in source:
		ids.append(id)
	return ids


## 라운드 적군을 배치판으로 생성
static func build_board(round_number: int) -> BoardState:
	var board: BoardState = BoardState.new()
	var ids: Array[StringName] = get_unit_ids(round_number)
	var total: int = get_total(round_number)
	var base: int = total / ids.size()
	var remainder: int = total % ids.size()
	var used_cells: Array[int] = []
	for i: int in range(ids.size()):
		var count: int = base + (1 if i < remainder else 0)
		var data: UnitData = UnitCatalog.get_unit(ids[i])
		var cell: int = _pick_cell(data.role, used_cells)
		used_cells.append(cell)
		board.cells[cell].unit_id = ids[i]
		board.cells[cell].count = count
	return board


## 역할 열 우선 (가운데 → 왼쪽 → 오른쪽), 꽉 차면 다른 열의 빈칸
static func _pick_cell(role: UnitData.Role, used: Array[int]) -> int:
	var row: int = BoardState.row_for_role(role)
	for col: int in [1, 0, 2]:
		var idx: int = BoardState.index_of(row, col)
		if not used.has(idx):
			return idx
	for idx: int in range(BoardState.CELL_COUNT):
		if not used.has(idx):
			return idx
	return 0
