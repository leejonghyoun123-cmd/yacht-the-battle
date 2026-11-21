class_name RemoveLowerHalfEnchant
extends EnchantData
## 하위 절반 면 삭제 (굴림 전): 주사위 최댓값의 절반 이하(<= max / 2) 면을 삭제한다.
## 예) 6면 주사위 → 1, 2, 3 삭제 → [4, 5, 6]


func _init() -> void:
	phase = Phase.PRE_ROLL


func apply_pre_roll(faces: Array[int], _instance: EnchantInstance) -> Array[int]:
	var result: Array[int] = []
	if faces.is_empty():
		return result
	var max_face: int = faces.max()
	for face: int in faces:
		# face <= max / 2 를 정수로 정확히 판정 (홀수 최댓값 대응)
		if face * 2 > max_face:
			result.append(face)
	return result
