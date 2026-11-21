class_name DiceMirrorItem
extends UserItemData
## 주사위 복제 거울: 얏츠판 기록 시 가방 맨 앞 주사위의 기대값만큼 1회 추가 소환 (쿨타임 3라운드, 원본 소모 없음)

const STATE_COOLDOWN: String = "cooldown"
@export var cooldown_rounds: int = 3


func on_record(item: ItemInstance, session: GameSession) -> String:
	if int(item.state.get(STATE_COOLDOWN, 0)) > 0:
		return ""
	var first: int = session.deck.first_reserve_index()
	if first < 0:
		return ""
	var source: DiceInstance = session.deck.reserve[first]
	var value: int = source.simulate_expected_value(session.get_round())
	session.add_bonus_summon(value, display_name)
	item.state[STATE_COOLDOWN] = cooldown_rounds
	return "주사위 복제 거울: %d명 추가 소환" % value


func on_round_end(item: ItemInstance, _session: GameSession) -> void:
	var cd: int = int(item.state.get(STATE_COOLDOWN, 0))
	if cd > 0:
		item.state[STATE_COOLDOWN] = cd - 1


func get_state_text(item: ItemInstance) -> String:
	var cd: int = int(item.state.get(STATE_COOLDOWN, 0))
	return "쿨타임 %d라운드" % cd if cd > 0 else "사용 가능"
