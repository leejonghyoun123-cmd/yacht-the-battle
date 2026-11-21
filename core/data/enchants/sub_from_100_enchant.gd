class_name SubFrom100Enchant
extends EnchantData
## 100에서 마이너스: 현재 값을 100 - X로 변경 (02: 전설, 7라운드부터 상점 등장)
## 결과가 0 이하이면 RollContext가 즉시 1로 보정한다.

@export var base_value: float = 100.0


func _init() -> void:
	phase = Phase.POST_ROLL
	rarity = Rarity.LEGENDARY
	min_unlock_round = 7


func apply_post_roll(ctx: RollContext, _instance: EnchantInstance) -> void:
	var base_fixed: int = FixedNum.from_float(base_value)
	ctx.set_value(FixedNum.add(base_fixed, -ctx.value), display_name, FixedNum.to_text(base_fixed) + " - X")
