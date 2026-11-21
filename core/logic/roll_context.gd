class_name RollContext
extends RefCounted
## 주사위 1개의 굴림 1회 연산 상태.
## 모든 인첸트·아이템·성질은 int가 아니라 이 객체를 통과하며 값을 바꾼다.
## 값(value)은 FixedNum(실제값×10) 단위다.

## 결정론적 RNG (멀티 동기화를 위해 전역 randi() 사용 금지)
var rng: RandomNumberGenerator
var round_number: int = 1
## 이 주사위의 활성 슬롯 위치 (0~4, Cross-Dice 인첸트용)
var active_index: int = 0

var raw_roll: int = 0
var value: int = 0

## 연산 단계 로그. UI에서 6 → 9 → 18 연출에 사용.
## { "source": String, "op": String, "value": int(FixedNum), "skipped": bool, "reason": String, "clamped": bool }
var logs: Array[Dictionary] = []

# --- 보스·특수 규칙 플래그 (Step 1에서는 기본값만 사용) ---
var immune_to_boss_gimmicks: bool = false
## 9R 보스: 비활성화할 물리 슬롯 인덱스
var disabled_slot_indices: Array[int] = []
## 12R 보스: 2번째 이후 곱연산 배수 절반
var tax_extra_multipliers: bool = false
var multiplier_count: int = 0
## 부정적 효과 절반 경감 누적 배율
var negative_effect_multiplier: float = 1.0
## 증폭 코어: 현재 슬롯에 적용 중인 합/곱 강화 배율 (슬롯마다 1.0으로 초기화)
var next_slot_power_multiplier: float = 1.0
## 증폭 코어가 "다음 슬롯"을 위해 예약한 배율. 슬롯 루프가 다음 슬롯 시작 시 꺼내 쓴다.
var pending_power_multiplier: float = 1.0
## 0 이하로 떨어졌던 음수량 누적 (오버플로우 배터리 연동용, FixedNum)
var underflow_bank: int = 0
## 보유 유저 아이템 (우선순위 정렬된 ItemInstance 목록, 해석기가 넣어 준다)
var items: Array = []
## 가방(예비 슬롯)에 있는 주사위 수 (벤치 응원봉)
var bench_count: int = 0


func _init(p_rng: RandomNumberGenerator = null, p_round: int = 1) -> void:
	rng = p_rng
	round_number = p_round


## 원시 눈금으로 연산 시작
func begin(p_raw_roll: int) -> void:
	raw_roll = p_raw_roll
	value = FixedNum.from_int(p_raw_roll)
	_push_log("원시 눈금", str(p_raw_roll), false, "", false)


## 값을 직접 지정 (100 - X 등). 0 이하이면 즉시 1로 보정.
func set_value(new_value: int, source: String, op: String) -> void:
	var clamped: bool = false
	if new_value <= 0:
		underflow_bank = FixedNum.add(underflow_bank, -new_value)
		new_value = FixedNum.ONE
		clamped = true
	value = new_value
	_push_log(source, op, false, "", clamped)


## 합연산. amount는 FixedNum 단위. 증폭 코어 배율 반영.
func add_value(amount: int, source: String) -> void:
	var boosted: int = FixedNum.mul_float(amount, next_slot_power_multiplier)
	var sign_text: String = "+" if boosted >= 0 else ""
	set_value(FixedNum.add(value, boosted), source, sign_text + FixedNum.to_text(boosted))


## 곱연산. 모든 곱연산 인첸트는 반드시 이 함수를 거친다 (12R 고배율 과세 일괄 처리).
func apply_multiplier(factor: float, source: String) -> void:
	var effective: float = 1.0 + (factor - 1.0) * next_slot_power_multiplier
	if tax_extra_multipliers and not immune_to_boss_gimmicks and multiplier_count >= 1:
		effective = maxf(1.0, 1.0 + (effective - 1.0) * 0.5)
	multiplier_count += 1
	set_value(FixedNum.mul_float(value, effective), source, "×" + _factor_text(effective))


## 값 변화 없는 단계 기록 (굴림 전 면 변형 등)
func log_step(source: String, op: String) -> void:
	_push_log(source, op, false, "", false)


## 미발동 슬롯 기록 (UI에서 "미발동" 표기용)
func log_skip(source: String, reason: String) -> void:
	_push_log(source, "", true, reason, false)


## 최종 소환값 (확정 시 1회 반올림, 최소 1)
func get_summon_value() -> int:
	return maxi(1, FixedNum.round_to_int(value))


func _push_log(source: String, op: String, skipped: bool, reason: String, clamped: bool) -> void:
	logs.append({
		"source": source,
		"op": op,
		"value": value,
		"skipped": skipped,
		"reason": reason,
		"clamped": clamped,
	})


static func _factor_text(factor: float) -> String:
	var snapped_factor: float = snappedf(factor, 0.01)
	if is_equal_approx(snapped_factor, roundf(snapped_factor)):
		return str(int(roundf(snapped_factor)))
	return str(snapped_factor)
