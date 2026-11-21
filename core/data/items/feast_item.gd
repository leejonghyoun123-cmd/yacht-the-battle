class_name FeastItem
extends TriggerFaceItem
## ?의 향연: 지정 눈금이 나오면 보너스 1개 (priority 30) — 이번 굴림 ×2 / 확정 시 골드 +60 / 확정 시 임시 실드 +25
## 골드·실드는 얏츠판 기록(확정) 때 지급 (주사위 runtime_state["feast"]에 예약)

const STATE_PENDING: String = "feast"
const REWARDS: Array[String] = ["double", "gold", "shield"]
@export var gold: int = 60
@export var shield: int = 25


func on_raw_trigger(ctx: RollContext, item: ItemInstance, dice: DiceInstance) -> void:
	dice.runtime_state.erase(STATE_PENDING)
	if not is_triggered(ctx, item) or ctx.rng == null:
		return
	var pick: String = REWARDS[ctx.rng.randi_range(0, REWARDS.size() - 1)]
	if pick == "double":
		DiceTraitData.multiply(ctx, 2.0, display_name)
	else:
		dice.runtime_state[STATE_PENDING] = pick
		ctx.log_step(display_name, "확정 시 " + ("골드 +%d" % gold if pick == "gold" else "실드 +%d" % shield))


## 확정 시 예약 보상 지급 (GameSession이 호출)
func pay_pending(dice: DiceInstance, session: GameSession) -> String:
	var pending: String = String(dice.runtime_state.get(STATE_PENDING, ""))
	dice.runtime_state.erase(STATE_PENDING)
	match pending:
		"gold":
			session.player.add_gold(gold, PlayerState.GoldSource.OTHER)
			return "?의 향연: +%d원" % gold
		"shield":
			session.player.round_shield += shield
			return "?의 향연: 실드 +%d" % shield
	return ""
