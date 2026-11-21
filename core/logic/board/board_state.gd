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
## 칸 자리에 영구 귀속된 타로 유닛칸 버프 { cell_index: Array[StatModifier] } (칸을 비워도 유지)
var slot_modifiers: Dictionary = {}


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
	# 유일 유닛(킹)은 판 전체에서 한 칸에만 (같은 칸에는 계속 쌓을 수 있다)
	var data: UnitData = UnitCatalog.get_unit(unit_id)
	if data != null and data.is_unique:
		for c: CellState in cells:
			if c.index != cell_index and not c.is_empty() and c.unit_id == unit_id:
				return false
	return cells[cell_index].can_accept(unit_id)


## 소환: 빈칸이거나 같은 병과면 인원을 더한다.
## mods: 이 소환이 칸에 붙이는 스탯 보정 / temporary: 과부하 주사위 (중첩칸이어도 이번 라운드 한정)
func place(cell_index: int, unit_id: StringName, amount: int, mods: Array[StatModifier] = [], temporary: bool = false) -> bool:
	if amount <= 0 or not can_place(cell_index, unit_id):
		return false
	var cell: CellState = cells[cell_index]
	cell.unit_id = unit_id
	if temporary and cell.is_stack:
		cell.temp_count = FixedNum.add(cell.temp_count, amount)
	else:
		cell.count = FixedNum.add(cell.count, amount)
	cell.add_modifiers(mods)
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
	# 킹은 칸 인원이 누적 K 수라 1장당 가격으로 따로 매긴다
	var data: UnitData = UnitCatalog.get_unit(cell.unit_id)
	var per_unit: int = GameBalance.KING_SELL_PER_STACK if (data != null and data.is_unique) else GameBalance.STACK_SELL_PER_UNIT
	if cell.count > FixedNum.MAX / per_unit:
		return FixedNum.MAX
	return cell.count * per_unit


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
			# 과부하 인원은 영구 누적되지 않는다
			survivors = maxi(0, survivors - cell.temp_count)
			cell.temp_count = 0
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
		p.total_count = cell.get_total()
		p.temp_count = cell.temp_count
		p.modifiers = cell.modifiers.duplicate()
		for m: StatModifier in slot_modifiers.get(cell.index, []):
			p.modifiers.append(m)
		p.is_consumable = not cell.is_stack
		packets.append(p)
	return packets


func to_dict() -> Array:
	var out: Array = []
	for cell: CellState in cells:
		out.append(cell.to_dict())
	return out


## 과부하(이번 라운드 한정) 인원 중 살아남은 수 — 승리 시 소비칸처럼 판매
func get_temp_survivors(survivors_by_cell: Dictionary) -> int:
	var total: int = 0
	for cell: CellState in cells:
		if cell.is_stack and cell.temp_count > 0:
			var survivors: int = roundi(float(survivors_by_cell.get(cell.index, 0.0)))
			total += mini(survivors, cell.temp_count)
	return total


## 타로 유닛칸 버프를 칸 자리에 영구 귀속
func add_slot_modifier(cell_index: int, mod: StatModifier) -> void:
	if not slot_modifiers.has(cell_index):
		slot_modifiers[cell_index] = [] as Array[StatModifier]
	(slot_modifiers[cell_index] as Array).append(mod)
	board_changed.emit()


func get_slot_modifiers(cell_index: int) -> Array:
	return slot_modifiers.get(cell_index, [])


## 더 러버 칸 연결 (중앙 관리, 칸끼리 서로 참조하지 않음)
var slot_links: Array[Vector2i] = []


func add_link(a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0 or a >= CELL_COUNT or b >= CELL_COUNT:
		return false
	slot_links.append(Vector2i(mini(a, b), maxi(a, b)))
	board_changed.emit()
	return true


## 저지먼트: 칸 자리의 타로 버프와 그 칸이 낀 연결을 모두 해제
func clear_slot_tarots(cell_index: int) -> void:
	slot_modifiers.erase(cell_index)
	for i: int in range(slot_links.size() - 1, -1, -1):
		if slot_links[i].x == cell_index or slot_links[i].y == cell_index:
			slot_links.remove_at(i)
	board_changed.emit()
