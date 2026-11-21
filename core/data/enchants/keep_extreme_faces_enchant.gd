class_name KeepExtremeFacesEnchant
extends EnchantData
## 극단 면 남기기 (굴림 전, 희귀): 가장 큰 면 2개(keep_top) 또는 가장 작은 면 2개만 남기고 전부 삭제

@export var keep_top: bool = true
@export var keep_count: int = 2


func _init() -> void:
	phase = Phase.PRE_ROLL
	rarity = Rarity.RARE


func apply_pre_roll(faces: Array[int], _instance: EnchantInstance) -> Array[int]:
	var sorted: Array[int] = faces.duplicate()
	sorted.sort()
	if keep_top:
		sorted.reverse()
	return sorted.slice(0, mini(keep_count, sorted.size()))


func get_icon_text() -> String:
	return "▲2" if keep_top else "▼2"
