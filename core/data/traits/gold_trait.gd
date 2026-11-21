class_name GoldTrait
extends MultiplyTrait
## 황금 주사위: 최종 소환값 ×0.7, 확정 시 최종 연산값의 50%만큼 골드 (GoldSource.DICE_TRAIT)

@export var gold_ratio: float = 0.5


func on_confirm(_dice: DiceInstance, result: DiceRollResult, session: GameSession) -> String:
	var gold: int = int(floorf(float(result.final_value) / 10.0 * gold_ratio))
	if gold <= 0:
		return ""
	session.player.add_gold(gold, PlayerState.GoldSource.DICE_TRAIT)
	return "황금 주사위: +%d원" % gold
