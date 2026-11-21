class_name BossRules
extends RefCounted
## 소환 시점에 적용되는 보스 기믹 (얏츠판 판정 이후, 소환 인원에만 적용).
##   3R 검열관의 저울: 원시 눈금 3 이하 → 소환값 50% 감소
##   6R 홀짝의 심판관: 최종값이 짝수 → 소환 인원 40% 감소
## 9R(슬롯 1 정지)·12R(곱연산 과세)·15R(재굴림 감소)은 굴림 연산 단계 기믹이라 별도로 연결한다.
## 결과는 반올림, 최소 1명.

const CENSOR_ROUND: int = 3
const CENSOR_RAW_MAX: int = 3
const CENSOR_MULTIPLIER: float = 0.5
const PARITY_ROUND: int = 6
const PARITY_MULTIPLIER: float = 0.6


## 반환: { "value": 최종 소환 인원, "reason": 적용된 기믹 설명(없으면 "") }
static func modify_summon(round_number: int, result: DiceRollResult, immune: bool = false) -> Dictionary:
	var value: int = result.summon_value
	if immune:
		return { "value": value, "reason": "" }
	if round_number == CENSOR_ROUND and result.raw_roll <= CENSOR_RAW_MAX:
		return { "value": _scaled(value, CENSOR_MULTIPLIER), "reason": "검열관의 저울: 눈금 %d ≤ 3 → 50%% 감소" % result.raw_roll }
	if round_number == PARITY_ROUND and value % 2 == 0:
		return { "value": _scaled(value, PARITY_MULTIPLIER), "reason": "홀짝의 심판관: 짝수 → 40% 감소" }
	return { "value": value, "reason": "" }


static func _scaled(value: int, factor: float) -> int:
	return maxi(1, FixedNum.round_to_int(FixedNum.mul_float(FixedNum.from_int(value), factor)))
