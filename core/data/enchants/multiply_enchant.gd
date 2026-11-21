class_name MultiplyEnchant
extends EnchantData
## 곱연산: 현재 값 × factor (02: 일반 ×1.5 / 고급 ×2 / 희귀 ×3)

@export var factor: float = 1.5


func _init() -> void:
	phase = Phase.POST_ROLL
	is_multiplier = true


func apply_post_roll(ctx: RollContext, _instance: EnchantInstance) -> void:
	ctx.apply_multiplier(factor, display_name)


func get_icon_text() -> String:
	return "×" + FixedNum.to_text(FixedNum.from_float(factor))
