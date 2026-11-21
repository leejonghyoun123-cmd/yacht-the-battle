class_name TrespassItem
extends UserItemData
## 무단 침입 통행증: 라운드당 1회, 첫 굴림 뒤에도 출전 주사위 1개를 가방 주사위와 교체할 수 있다.
## 들어온 주사위는 바로 1번 굴려 결과를 채운다 (재굴림 횟수 소모 없음).

const STATE_USED_ROUND: String = "used_round"


func allows_rolling_swap(item: ItemInstance) -> bool:
	return int(item.state.get(STATE_USED_ROUND, 0)) == 0


func on_round_end(item: ItemInstance, _session: GameSession) -> void:
	item.state[STATE_USED_ROUND] = 0


func get_state_text(item: ItemInstance) -> String:
	return "이번 라운드 사용함" if int(item.state.get(STATE_USED_ROUND, 0)) != 0 else "이번 라운드 사용 가능"
