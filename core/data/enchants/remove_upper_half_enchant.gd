class_name RemoveUpperHalfEnchant
extends EnchantData
## 상위 절반 면 삭제 (굴림 전): 최댓값의 절반 초과(> max / 2) 면 삭제. 예) 6면 → [1, 2, 3]


func _init() -> void:
	phase = Phase.PRE_ROLL


func apply_pre_roll(faces: Array[int], _instance: EnchantInstance) -> Array[int]:
	var result: Array[int] = []
	if faces.is_empty():
		return result
	var max_face: int = faces.max()
	for face: int in faces:
		if face * 2 <= max_face:
			result.append(face)
	return result


func get_icon_text() -> String:
	return "△½"
