class_name CeilToTenEnchant
extends EnchantData
## 10의 자리 올림: 가장 가까운 10의 배수로 올림 (11 → 20, 20 → 20, 13.5 → 20)


func _init() -> void:
	phase = Phase.POST_ROLL


func apply_post_roll(ctx: RollContext, _instance: EnchantInstance) -> void:
	var unit: int = FixedNum.from_int(10)
	var rem: int = ctx.value % unit
	if rem == 0:
		ctx.log_step(display_name, "이미 10의 배수")
		return
	ctx.set_value(FixedNum.add(ctx.value, unit - rem), display_name, "↑10")


func get_icon_text() -> String:
	return "↑10"
