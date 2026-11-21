class_name ConditionalMathItem
extends TriggerFaceItem
## +? 곱?: 지정 눈금이 나오면 +10 또는 ×2 (획득 시 둘 중 하나가 정해짐, priority 20)

const STATE_MULT: String = "is_mult"
@export var add_amount: int = 10
@export var mult_factor: float = 2.0


func on_acquire(item: ItemInstance, session: GameSession) -> String:
	var text: String = super.on_acquire(item, session)
	item.state[STATE_MULT] = session.rng.randf() < 0.5
	return text + (" · ×%s" % str(mult_factor) if item.state[STATE_MULT] else " · +%d" % add_amount)


func on_raw_trigger(ctx: RollContext, item: ItemInstance, _dice: DiceInstance) -> void:
	if not is_triggered(ctx, item):
		return
	if bool(item.state.get(STATE_MULT, false)):
		DiceTraitData.multiply(ctx, mult_factor, display_name)
	else:
		ctx.set_value(FixedNum.add(ctx.value, FixedNum.from_int(add_amount)), display_name, "+%d" % add_amount)


func get_label(item: ItemInstance) -> String:
	var op: String = ("×%s" % str(mult_factor)) if bool(item.state.get(STATE_MULT, false)) else ("+%d" % add_amount)
	return "%s [%d → %s]" % [display_name, get_face(item), op]
