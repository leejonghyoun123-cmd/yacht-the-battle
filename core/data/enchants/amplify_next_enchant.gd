class_name AmplifyNextEnchant
extends EnchantData
## 증폭 코어: 바로 다음 슬롯의 합연산/곱연산 수치를 1.5배 강화 (다음 슬롯 1개에만, 그 뒤 자동 초기화)

@export var power: float = 1.5


func _init() -> void:
	phase = Phase.POST_ROLL
	rarity = Rarity.UNCOMMON


func apply_post_roll(ctx: RollContext, _instance: EnchantInstance) -> void:
	ctx.pending_power_multiplier = power
	ctx.log_step(display_name, "다음 슬롯 ×%s 강화" % str(power))


func get_icon_text() -> String:
	return "⚡"
