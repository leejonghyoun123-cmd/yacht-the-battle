class_name LoveFiftyItem
extends TriggerFaceItem
## 50이좋아: 지정 눈금이 나오면 연산 시작값을 50으로 (priority 10 — 추가 연산보다 먼저)


func on_raw_trigger(ctx: RollContext, item: ItemInstance, _dice: DiceInstance) -> void:
	if is_triggered(ctx, item):
		ctx.set_value(FixedNum.from_int(50), display_name, "=50")
