class_name ThresholdSwitchEnchant
extends EnchantData
## 최댓값 절단기: 현재 값이 50 이하이면 +20, 50 초과이면 ×1.5

@export var threshold: int = 50
@export var low_add: float = 20.0
@export var high_factor: float = 1.5


func _init() -> void:
	phase = Phase.POST_ROLL
	rarity = Rarity.UNCOMMON


func apply_post_roll(ctx: RollContext, _instance: EnchantInstance) -> void:
	if ctx.value <= FixedNum.from_int(threshold):
		ctx.add_value(FixedNum.from_float(low_add), display_name)
	else:
		ctx.apply_multiplier(high_factor, display_name)


func get_icon_text() -> String:
	return "50|"
