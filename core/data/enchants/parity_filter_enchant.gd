class_name ParityFilterEnchant
extends EnchantData
## 홀짝 필터 (굴림 전): 짝수 면 전부 삭제(REMOVE_EVEN) 또는 홀수 면 전부 삭제(REMOVE_ODD)

enum FilterMode { REMOVE_EVEN, REMOVE_ODD }

@export var mode: FilterMode = FilterMode.REMOVE_EVEN


func _init() -> void:
	phase = Phase.PRE_ROLL
	rarity = Rarity.UNCOMMON


func apply_pre_roll(faces: Array[int], _instance: EnchantInstance) -> Array[int]:
	var result: Array[int] = []
	for face: int in faces:
		var even: bool = face % 2 == 0
		if (mode == FilterMode.REMOVE_EVEN and not even) or (mode == FilterMode.REMOVE_ODD and even):
			result.append(face)
	return result


func get_icon_text() -> String:
	return "홀만" if mode == FilterMode.REMOVE_EVEN else "짝만"
