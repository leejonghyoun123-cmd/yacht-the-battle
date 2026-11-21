class_name CorrectionTapeItem
extends UserItemData
## 수정 테이프 (1회용): 이미 기록한 얏츠판 칸 1개를 미기록으로 되돌린다.


func can_activate(_item: ItemInstance) -> bool:
	return true


func get_choices(_item: ItemInstance, session: GameSession) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cat: int in session.yacht.recorded.keys():
		out.append({ "value": cat, "label": YachtBoard.category_name(cat) })
	return out


func activate_choice(_item: ItemInstance, session: GameSession, value: Variant) -> String:
	if session.yacht.unrecord(int(value)):
		return "수정 테이프: [%s] 칸을 지웠습니다" % YachtBoard.category_name(int(value))
	return ""


func get_activate_label() -> String:
	return "사용"
