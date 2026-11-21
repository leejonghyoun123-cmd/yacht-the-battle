class_name JokerTrait
extends DiceTraitData
## 조커의 랜덤주사위: 굴릴 때마다(재굴림 포함) 결과 1개 추첨 → 확정 시 발동.
##   보상 70%: 랜덤 유저 아이템 / 랜덤 타로카드 / 소환값 ×2 / 최대 체력 30% 회복
##   저주 30%: 현재 체력 20% 감소(최소 1) / 소환값 ×0.5

const STATE_OUTCOME: String = "joker_outcome"
const GOOD: Array[String] = ["item", "tarot", "double", "heal"]
const CURSE: Array[String] = ["hp_cut", "half"]
const NAMES: Dictionary = {
	"item": "보상: 유저 아이템", "tarot": "보상: 타로카드", "double": "보상: 소환값 ×2",
	"heal": "보상: 체력 30% 회복", "hp_cut": "저주: 체력 -20%", "half": "저주: 소환값 ×0.5",
}
@export var curse_chance: float = 0.3


static func get_outcome(dice: DiceInstance) -> String:
	return String(dice.runtime_state.get(STATE_OUTCOME, ""))


func on_rolled(ctx: RollContext, dice: DiceInstance) -> void:
	var curse: bool = ctx.rng != null and ctx.rng.randf() < curse_chance * ctx.negative_effect_multiplier
	var pool: Array[String] = CURSE if curse else GOOD
	var pick: int = ctx.rng.randi_range(0, pool.size() - 1) if ctx.rng != null else 0
	dice.runtime_state[STATE_OUTCOME] = pool[pick]


func on_post_pipeline(ctx: RollContext, dice: DiceInstance) -> void:
	match get_outcome(dice):
		"double":
			multiply(ctx, 2.0, "조커 보상")
		"half":
			multiply(ctx, 0.5, "조커 저주")


func on_confirm(dice: DiceInstance, _result: DiceRollResult, session: GameSession) -> String:
	var outcome: String = get_outcome(dice)
	match outcome:
		"item":
			var it: String = session.grant_random_item()
			return "조커: 아이템 %s 획득" % it if it != "" else "조커: 아이템 칸이 가득 찼습니다"
		"tarot":
			var tc: String = session.grant_random_tarot()
			return "조커: 타로 %s 획득" % tc if tc != "" else "조커: 타로 칸이 가득 찼습니다"
		"heal":
			session.player.heal(int(session.player.max_hp * 0.3))
		"hp_cut":
			var cut: int = mini(int(session.player.hp * 0.2), session.player.hp - 1)
			if cut > 0:
				session.player.take_damage(cut)
	return "조커: " + String(NAMES.get(outcome, "")) if outcome != "" else ""


func get_state_text(dice: DiceInstance) -> String:
	var o: String = get_outcome(dice)
	return String(NAMES.get(o, "")) if o != "" else "굴리면 결과가 정해집니다"
