class_name CellState
extends RefCounted
## 배치판 한 칸. 한 칸에는 한 병과만 들어가며 같은 병과는 인원이 계속 쌓인다.
## count는 "총 누적 인원"(압축 전 값)이다. 50명 초과분은 스폰 시 정예 압축된다.

var index: int = 0
var is_stack: bool = false
var unit_id: StringName = &""
var count: int = 0


func is_empty() -> bool:
	return count <= 0 or unit_id == &""


func can_accept(p_unit_id: StringName) -> bool:
	return is_empty() or unit_id == p_unit_id


func clear() -> void:
	unit_id = &""
	count = 0


func to_dict() -> Dictionary:
	return { "index": index, "unit": String(unit_id), "count": count }
