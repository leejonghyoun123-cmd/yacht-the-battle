class_name LuckySevenEnchant
extends EnchantData
## 럭키 세븐: 현재 값의 1의 자리가 7이면 ×4


func _init() -> void:
	phase = Phase.POST_ROLL
	rarity = Rarity.RARE


func apply_post_roll(ctx: RollContext, _instance: EnchantInstance) -> void:
	if FixedNum.int_part(ctx.value) % 10 == 7:
		ctx.apply_multiplier(4.0, display_name)
	else:
		ctx.log_skip(display_name, "1의 자리가 7이 아님")


func get_icon_text() -> String:
	return "7"
