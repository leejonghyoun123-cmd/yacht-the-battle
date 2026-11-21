class_name WeightedDiceItem
extends UserItemData
## 속임 무게추: 대상 주사위의 가장 큰 면이 나올 확률(가중치)을 크게 올린다 (영구)

@export var weight: float = 3.0


func apply_to_dice(dice: DiceInstance, _item: ItemInstance) -> void:
	var faces: Array[int] = dice.get_modified_faces()
	var weights: Dictionary = dice.runtime_state.get(DiceInstance.STATE_FACE_WEIGHTS, {})
	var top: int = faces.max()
	weights[top] = float(weights.get(top, 1.0)) * weight
	dice.runtime_state[DiceInstance.STATE_FACE_WEIGHTS] = weights
