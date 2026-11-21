class_name OddZealotEnchant
extends EnchantData
## 홀수 광신도: 현재 값(정수부)이 홀수면 ×2.5, 짝수면 +1


func _init() -> void:
	phase = Phase.POST_ROLL
	rarity = Rarity.RARE


func apply_post_roll(ctx: RollContext, _instance: EnchantInstance) -> void:
	if FixedNum.int_part(ctx.value) % 2 == 1:
		ctx.apply_multiplier(2.5, display_name)
	else:
		ctx.add_value(FixedNum.ONE, display_name)


func get_icon_text() -> String:
	return "홀"
