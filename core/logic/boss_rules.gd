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


const SILENCE_ROUND: int = 9
const TAX_ROUND: int = 12
const FINAL_ROUND: int = 15
const FINAL_REROLL_PENALTY: int = 1


## 굴림 연산 단계 기믹 (RoundFlow.roll_modifiers로 전달)
##   9R 침묵의 시계탑: 모든 출전 주사위의 인첸트 슬롯 1번 비활성
##   12R 탐욕의 수금원: 한 주사위의 2번째 이후 곱연산 배수 절반
static func roll_modifiers(round_number: int) -> Dictionary:
	if round_number == SILENCE_ROUND:
		return { "disabled_slots": [0] }
	if round_number == TAX_ROUND:
		return { "tax_multipliers": true }
	return {}


## 15R 야추의 군주: 재굴림 1회 감소 (최소 1회 보장은 RoundFlow가 처리)
## 적 타로카드 2장 자동 발동은 타로카드 시스템 단계에서 연결
static func reroll_penalty(round_number: int) -> int:
	return FINAL_REROLL_PENALTY if round_number == FINAL_ROUND else 0


static func _scaled(value: int, factor: float) -> int:
	return maxi(1, FixedNum.round_to_int(FixedNum.mul_float(FixedNum.from_int(value), factor)))
