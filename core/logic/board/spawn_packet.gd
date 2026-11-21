class_name SpawnPacket
extends RefCounted
## 배치판 한 칸 → 전투 스폰 요청 (03 문서 SpawnPacket)

var cell_index: int = 0
var unit_data: UnitData
## 총 누적 인원 (압축 전)
var total_count: int = 0
var is_consumable: bool = false
## 이후 타로 등 스탯 보정 목록 (예전 형식, 사용하지 않음)
var stat_modifiers: Array[Dictionary] = []
## 이 칸 유닛 전원에 적용할 스탯 보정 (칸 보정 + 타로 유닛칸 버프)
var modifiers: Array[StatModifier] = []
## 이번 라운드 한정 인원 (과부하 주사위). 총 인원에 포함되어 있다.
var temp_count: int = 0
