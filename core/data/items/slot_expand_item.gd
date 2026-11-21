class_name SlotExpandItem
extends UserItemData
## 조각칼(+1) / 핸드드릴(+2): 대상 주사위 인첸트 슬롯 영구 확장 (최대 5칸)

@export var amount: int = 1


func can_apply_to(dice: DiceInstance) -> bool:
	return dice.unlocked_slots < DiceInstance.MAX_SLOTS


func apply_to_dice(dice: DiceInstance, _item: ItemInstance) -> void:
	dice.unlock_slots(amount)
