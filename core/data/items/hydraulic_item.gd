class_name HydraulicItem
extends UserItemData
## 유압 압축기: 내 팀의 정예 압축 기준 50 → 25명, 압축 스탯 증폭 ×1.15 (적 팀에는 영향 없음)

@export var threshold: int = 25
@export var stat_bonus: float = 1.15


func get_compression(_item: ItemInstance) -> Dictionary:
	return { "threshold": threshold, "bonus": stat_bonus }
