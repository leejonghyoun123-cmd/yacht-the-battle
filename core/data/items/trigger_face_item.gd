class_name TriggerFaceItem
extends UserItemData
## 특정 원시 눈금 트리거 아이템의 공통 부분. 획득 시 지정 눈금(1~6)을 정한다.

const STATE_FACE: String = "face"


func on_acquire(item: ItemInstance, session: GameSession) -> String:
	item.state[STATE_FACE] = session.rng.randi_range(1, 6)
	return "%s: 지정 눈금 %d" % [display_name, int(item.state[STATE_FACE])]


static func get_face(item: ItemInstance) -> int:
	return int(item.state.get(STATE_FACE, 6))


func get_label(item: ItemInstance) -> String:
	return "%s [%d]" % [display_name, get_face(item)]


func is_triggered(ctx: RollContext, item: ItemInstance) -> bool:
	return ctx.raw_roll == get_face(item)
