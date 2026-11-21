class_name XBottleTrait
extends DiceTraitData
## 1회용 X병 주사위: 가방에 있어도 매 라운드 스택 +25 (최대 500).
## 출전하면 원시 눈금 대신 스택값으로 연산(인첸트 정상 적용)하고, 그 라운드가 끝나면 파괴된다.

const STATE_STACK: String = "xbottle_stack"
@export var stack_per_round: int = 25
@export var max_stack: int = 500


static func stack_of(dice: DiceInstance) -> int:
	return int(dice.runtime_state.get(STATE_STACK, 0))


func override_raw(raw: int, dice: DiceInstance) -> int:
	var stack: int = stack_of(dice)
	return stack if stack > 0 else raw


func on_round_end(dice: DiceInstance, was_rolled: bool, session: GameSession) -> String:
	if was_rolled:
		session.destroy_dice(dice)
		return "X병 주사위를 사용해 파괴되었습니다"
	dice.runtime_state[STATE_STACK] = mini(max_stack, stack_of(dice) + stack_per_round)
	return ""


func get_state_text(dice: DiceInstance) -> String:
	return "누적 스택 %d / %d" % [stack_of(dice), max_stack]
