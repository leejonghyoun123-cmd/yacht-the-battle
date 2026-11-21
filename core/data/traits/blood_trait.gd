class_name BloodTrait
extends MultiplyTrait
## 피주사위: 최종 소환값 ×2.5. 확정 시 원시 눈금만큼 체력 소모 (1회 최대 50, 체력 1 미만으로는 안 내려감)

@export var max_hp_cost: int = 50


func on_confirm(_dice: DiceInstance, result: DiceRollResult, session: GameSession) -> String:
	var cost: int = mini(result.raw_roll, max_hp_cost)
	var actual: int = mini(cost, session.player.hp - 1)
	if actual <= 0:
		return ""
	session.player.take_damage(actual)
	return "피주사위: 체력 -%d" % actual
