class_name SpawnPacket
extends RefCounted
## 배치판 한 칸 → 전투 스폰 요청 (03 문서 SpawnPacket)

var cell_index: int = 0
var unit_data: UnitData
## 총 누적 인원 (압축 전)
var total_count: int = 0
var is_consumable: bool = false
## 이후 타로·포커 수트 등 스탯 보정 목록
var stat_modifiers: Array[Dictionary] = []
