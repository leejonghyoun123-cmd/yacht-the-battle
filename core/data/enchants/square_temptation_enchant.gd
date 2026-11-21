class_name SquareTemptationEnchant
extends EnchantData
## 제곱의 유혹: 현재 값(정수부)이 10 이하일 때만 X × X, 11 이상이면 미발동

@export var max_value: int = 10


func _init() -> void:
	phase = Phase.POST_ROLL
	rarity = Rarity.RARE


func apply_post_roll(ctx: RollContext, _instance: EnchantInstance) -> void:
	if FixedNum.int_part(ctx.value) > max_value:
		ctx.log_skip(display_name, "현재 값이 %d보다 큼" % max_value)
		return
	ctx.set_value(FixedNum.mul_fixed(ctx.value, ctx.value), display_name, "X²")


func get_icon_text() -> String:
	return "X²"
