class_name FairyTrait
extends DiceTraitData
## 요정의 주사위: 확정 시 원시 눈금만큼 체력 회복 (1회 최대 30, 최대 체력 초과 불가)

@export var max_heal: int = 30


func on_confirm(_dice: DiceInstance, result: DiceRollResult, session: GameSession) -> String:
	var before: int = session.player.hp
	session.player.heal(mini(result.raw_roll, max_heal))
	var healed: int = session.player.hp - before
	return ("요정의 주사위: 체력 +%d" % healed) if healed > 0 else ""
