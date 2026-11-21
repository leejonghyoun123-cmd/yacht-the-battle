class_name FakeMaxFaceEnchant
extends EnchantData
## 가짜 최댓값 (굴림 전): 가장 낮은 면 1개를 최댓값으로 교체


func _init() -> void:
	phase = Phase.PRE_ROLL
	rarity = Rarity.UNCOMMON


func apply_pre_roll(faces: Array[int], _instance: EnchantInstance) -> Array[int]:
	var result: Array[int] = faces.duplicate()
	if result.is_empty():
		return result
	var max_face: int = result.max()
	var low_index: int = result.find(result.min())
	result[low_index] = max_face
	return result


func get_icon_text() -> String:
	return "▲1"
