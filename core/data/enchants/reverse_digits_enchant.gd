class_name ReverseDigitsEnchant
extends EnchantData
## 숫자 뒤집기: 정수부 자릿수를 좌우 반전 (19 → 91, 100 → 1). 소수점 이하는 버린다.


func _init() -> void:
	phase = Phase.POST_ROLL
	rarity = Rarity.UNCOMMON


func apply_post_roll(ctx: RollContext, _instance: EnchantInstance) -> void:
	var text: String = str(FixedNum.int_part(ctx.value))
	var reversed: String = ""
	for i: int in range(text.length() - 1, -1, -1):
		reversed += text[i]
	ctx.set_value(FixedNum.from_int(reversed.to_int()), display_name, "↔ " + reversed)


func get_icon_text() -> String:
	return "↔"
