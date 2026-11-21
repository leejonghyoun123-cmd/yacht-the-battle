class_name InvertFacesEnchant
extends EnchantData
## 눈금 반전 (굴림 전): 모든 면을 (최댓값 + 1) - X로 반전


func _init() -> void:
	phase = Phase.PRE_ROLL


func apply_pre_roll(faces: Array[int], _instance: EnchantInstance) -> Array[int]:
	var result: Array[int] = []
	if faces.is_empty():
		return result
	var max_face: int = faces.max()
	for face: int in faces:
		result.append(maxi(1, max_face + 1 - face))
	return result


func get_icon_text() -> String:
	return "⇅"
