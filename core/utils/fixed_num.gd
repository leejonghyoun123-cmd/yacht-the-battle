class_name FixedNum
extends RefCounted
## 소수점 1자리 고정소수점 숫자 유틸리티.
## 값은 "실제값 × 10"인 int로 저장한다. 예) 13.5 → 135
## 모든 주사위 연산은 이 클래스를 거친다. 나중에 int64를 넘는 큰 수가 필요해지면
## 이 클래스만 교체하면 되도록 숫자 연산을 한 곳에 모아 둔다.
## int64 상한/하한에서 포화(saturate)되어 오버플로로 음수가 되는 일을 막는다.

const SCALE: int = 10
const ONE: int = 10
const MAX: int = 9223372036854775807
const MIN: int = -9223372036854775807
## 배율 연산 정밀도 (1.5배 → 1500)
const MILLI: int = 1000


## 정수 실제값 → 고정소수점
static func from_int(real_value: int) -> int:
	if real_value > MAX / SCALE:
		return MAX
	if real_value < MIN / SCALE:
		return MIN
	return real_value * SCALE


## 실수 실제값 → 고정소수점 (소수점 2자리 이하는 반올림)
static func from_float(real_value: float) -> int:
	var scaled: float = real_value * float(SCALE)
	if scaled >= float(MAX):
		return MAX
	if scaled <= float(MIN):
		return MIN
	return roundi(scaled)


## 포화 덧셈 (b가 음수면 뺄셈)
static func add(a: int, b: int) -> int:
	if b > 0 and a > MAX - b:
		return MAX
	if b < 0 and a < MIN - b:
		return MIN
	return a + b


## 정수 배율(천분율) 곱셈. 1.5배 → milli = 1500. 결과의 0.1 미만은 버림.
## 정수 연산만 사용하므로 PC마다 결과가 같다 (멀티 동기화 안전).
static func mul_milli(a: int, milli: int) -> int:
	if a == 0 or milli == 0:
		return 0
	if a < 0:
		return -mul_milli(-a, milli) if a != MIN else MIN
	if milli < 0:
		return -mul_milli(a, -milli)
	var quotient: int = a / MILLI
	var remainder: int = a % MILLI
	if quotient > 0 and quotient > MAX / milli:
		return MAX
	var high: int = quotient * milli
	# remainder < 1000 이므로 milli가 9.2e15 미만이면 안전
	var low: int = (remainder * milli) / MILLI
	return add(high, low)


## 실수 배율 곱셈 (배율은 소수점 3자리까지 유효)
static func mul_float(a: int, factor: float) -> int:
	return mul_milli(a, roundi(factor * float(MILLI)))


## 두 고정소수점 값의 곱 (예: 제곱의 유혹 X*X)
static func mul_fixed(a: int, b: int) -> int:
	const RATIO: int = MILLI / SCALE  # 고정소수점 b(×10) → 천분율(×1000)
	if absi(b) > MAX / RATIO:
		return MAX if (a >= 0) == (b >= 0) else MIN
	return mul_milli(a, b * RATIO)


## 정수부 (홀짝·1의 자리 등 조건 판정용). 13.5 → 13
static func int_part(v: int) -> int:
	return v / SCALE


## 최종 소환값 확정용 반올림. 13.5 → 14, 13.4 → 13
static func round_to_int(v: int) -> int:
	if v >= 0:
		return (v / SCALE) + (1 if v % SCALE >= 5 else 0)
	return -round_to_int(-v)


## 화면 표시용 문자열. 135 → "13.5", 130 → "13"
static func to_text(v: int) -> String:
	var sign_text: String = "-" if v < 0 else ""
	var abs_v: int = absi(v) if v != MIN else MAX
	var whole: int = abs_v / SCALE
	var frac: int = abs_v % SCALE
	if frac == 0:
		return sign_text + str(whole)
	return sign_text + str(whole) + "." + str(frac)
