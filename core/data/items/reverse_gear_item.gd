class_name ReverseGearItem
extends UserItemData
## 역방향 기어: 대상 주사위의 인첸트 슬롯을 5→1 역순으로 연산 (영구, 보스 9R 정지는 물리 슬롯 1 기준 유지)


func can_apply_to(dice: DiceInstance) -> bool:
	return not bool(dice.runtime_state.get(DiceInstance.STATE_REVERSE_SLOTS, false))


func apply_to_dice(dice: DiceInstance, _item: ItemInstance) -> void:
	dice.runtime_state[DiceInstance.STATE_REVERSE_SLOTS] = true
