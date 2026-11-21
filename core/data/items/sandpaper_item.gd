class_name SandpaperItem
extends UserItemData
## 사포와펜: 고른 주사위에서 숫자 1개를 지우고(밴), 그 주사위의 다른 숫자 1개를 그 자리에 새긴다 (영구).
## 예: 6면에서 1을 지우고 6을 새기면 [6,2,3,4,5,6]. runtime_state["face_replace"]에 기록.


func get_dice_choices(dice: DiceInstance, picks: Array) -> Array[Dictionary]:
	var faces: Array[int] = dice.get_modified_faces()
	var unique: Array[int] = []
	for f: int in faces:
		if not unique.has(f):
			unique.append(f)
	unique.sort()
	var out: Array[Dictionary] = []
	if picks.is_empty():
		if unique.size() < 2:
			return out
		for f: int in unique:
			out.append({ "value": f, "label": "%s 지우기" % dice.face_label(f) })
	elif picks.size() == 1:
		for f: int in unique:
			if f != int(picks[0]):
				out.append({ "value": f, "label": "%s 새기기" % dice.face_label(f) })
	return out


func can_apply_to(dice: DiceInstance) -> bool:
	return dice.get_modified_faces().size() >= 2


func apply_to_dice(dice: DiceInstance, item: ItemInstance) -> void:
	var picks: Array = item.state.get("picks", [])
	if picks.size() < 2:
		return
	var list: Array = dice.runtime_state.get(DiceInstance.STATE_FACE_REPLACE, [])
	list.append(Vector2i(int(picks[0]), int(picks[1])))
	dice.runtime_state[DiceInstance.STATE_FACE_REPLACE] = list
