class_name BoardState
extends RefCounted
## 3x3 배치판 (한 플레이어 또는 적군).
## 인덱스 = row * 3 + col.  row 0 = 후열, 1 = 중열, 2 = 전열(적과 가장 가까움)
## col 1(가운데 세로 줄) = 중첩칸, col 0·2 = 소비칸.

signal board_changed

const SIZE: int = 3
const CELL_COUNT: int = 9
const STACK_COLUMN: int = 1

var cells: Array[CellState] = []
var retention_policy: StackRetentionPolicy = StackRetentionPolicy.new()


func _init() -> void:
	for i: int in range(CELL_COUNT):
		var c: CellState = CellState.new()
		c.index = i
		c.is_stack = (i % SIZE) == STACK_COLUMN
		cells.append(c)


static func index_of(row: int, col: int) -> int:
	return row * SIZE + col


static func row_of(index: int) -> int:
	return index / SIZE


static func col_of(index: int) -> int:
	return index % SIZE


static func row_for_role(role: UnitData.Role) -> int:
	match role:
		UnitData.Role.TANK:
			return 2
		UnitData.Role.MELEE:
			return 1
	return 0


func can_place(cell_index: int, unit_id: StringName) -> bool:
	if cell_index < 0 or cell_index >= CELL_COUNT or unit_id == &"":
		return false
	return cells[cell_index].can_accept(unit_id)


## 소환: 빈칸이거나 같은 병과면 인원을 더한다.
func place(cell_index: int, unit_id: StringName, amount: int) -> bool:
	if amount <= 0 or not can_place(cell_index, unit_id):
		return false
	var cell: CellState = cells[cell_index]
	cell.unit_id = unit_id
	cell.count = FixedNum.add(cell.count, amount)
	board_changed.emit()
	return true


## 중첩칸 판매 (준비 단계에서만 호출할 것). 받을 골드를 반환하고 칸을 비운다.
func sell_stack_cell(cell_index: int) -> int:
	if cell_index < 0 or cell_index >= CELL_COUNT:
		return 0
	var cell: CellState = cells[cell_index]
	if not cell.is_stack or cell.is_empty():
		return 0
	var gold: int = get_stack_sell_price(cell_index)
	cell.clear()
	board_changed.emit()
	return gold


func get_stack_sell_price(cell_index: int) -> int:
	var cell: CellState = cells[cell_index]
	if not cell.is_stack or cell.is_empty():
		return 0
	if cell.count > FixedNum.MAX / GameBalance.STACK_SELL_PER_UNIT:
		return FixedNum.MAX
	return cell.count * GameBalance.STACK_SELL_PER_UNIT


func clear_consumables() -> void:
	for cell: CellState in cells:
		if not cell.is_stack:
			cell.clear()
	board_changed.emit()


## 전투 후 중첩칸 인원 정리 (정책에 따름). survivors_by_cell: { cell_index: 생존 환산 인원 }
func apply_stack_retention(survivors_by_cell: Dictionary) -> void:
	for cell: CellState in cells:
		if cell.is_stack and not cell.is_empty():
			var survivors: int = roundi(float(survivors_by_cell.get(cell.index, 0.0)))
			cell.count = retention_policy.next_count(cell.count, survivors)
			if cell.count <= 0:
				cell.clear()
	board_changed.emit()


func get_total_count() -> int:
	var total: int = 0
	for cell: CellState in cells:
		total = FixedNum.add(total, cell.count)
	return total


## 전투 스폰용 데이터
func get_spawn_packets() -> Array[SpawnPacket]:
	var packets: Array[SpawnPacket] = []
	for cell: CellState in cells:
		if cell.is_empty():
			continue
		var p: SpawnPacket = SpawnPacket.new()
		p.cell_index = cell.index
		p.unit_data = UnitCatalog.get_unit(cell.unit_id)
		p.total_count = cell.count
		p.is_consumable = not cell.is_stack
		packets.append(p)
	return packets


func to_dict() -> Array:
	var out: Array = []
	for cell: CellState in cells:
		out.append(cell.to_dict())
	return out
