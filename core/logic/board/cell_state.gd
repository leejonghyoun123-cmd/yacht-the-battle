class_name CellState
extends RefCounted
## 배치판 한 칸. 한 칸에는 한 병과만 들어가며 같은 병과는 인원이 계속 쌓인다.
## count는 "총 누적 인원"(압축 전 값)이다. 50명 초과분은 스폰 시 정예 압축된다.

var index: int = 0
var is_stack: bool = false
var unit_id: StringName = &""
var count: int = 0
## 이번 라운드 한정 인원 (과부하 주사위: 중첩칸에 놓아도 영구 누적되지 않고 소비칸처럼 정산)
var temp_count: int = 0
## 이 칸 유닛에 붙은 스탯 보정 (뼈주사위 등). 칸이 비면 함께 사라진다.
var modifiers: Array[StatModifier] = []


func is_empty() -> bool:
	return (count + temp_count) <= 0 or unit_id == &""


func can_accept(p_unit_id: StringName) -> bool:
	return is_empty() or unit_id == p_unit_id


func get_total() -> int:
	return FixedNum.add(count, temp_count)


func add_modifiers(mods: Array[StatModifier]) -> void:
	for m: StatModifier in mods:
		if m != null and not modifiers.has(m):
			modifiers.append(m)


func clear() -> void:
	unit_id = &""
	count = 0
	temp_count = 0
	modifiers.clear()


func to_dict() -> Dictionary:
	return { "index": index, "unit": String(unit_id), "count": count, "temp": temp_count, "mods": modifiers.duplicate() }
