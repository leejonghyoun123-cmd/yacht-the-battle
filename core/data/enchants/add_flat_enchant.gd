class_name AddFlatEnchant
extends EnchantData
## 합연산: 현재 값 + amount (02: 일반 +3 / 고급 +7 / 희귀 +15)

@export var amount: float = 3.0


func _init() -> void:
	phase = Phase.POST_ROLL


func apply_post_roll(ctx: RollContext, _instance: EnchantInstance) -> void:
	ctx.add_value(FixedNum.from_float(amount), display_name)


func get_icon_text() -> String:
	return "+" + FixedNum.to_text(FixedNum.from_float(amount))
