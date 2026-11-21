class_name EvenNobleEnchant
extends EnchantData
## 짝수 귀족: 현재 값(정수부)이 짝수면 ×2.5, 홀수면 변화 없음


func _init() -> void:
	phase = Phase.POST_ROLL
	rarity = Rarity.RARE


func apply_post_roll(ctx: RollContext, _instance: EnchantInstance) -> void:
	if FixedNum.int_part(ctx.value) % 2 == 0:
		ctx.apply_multiplier(2.5, display_name)
	else:
		ctx.log_skip(display_name, "홀수라 변화 없음")


func get_icon_text() -> String:
	return "짝"
