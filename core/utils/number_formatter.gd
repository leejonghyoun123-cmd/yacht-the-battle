class_name NumberFormatter
extends RefCounted
## 큰 숫자 축약 표기 유틸리티. 모든 UI 숫자 출력은 이 함수를 거친다.
## 예) 999 → "999", 1500 → "1.5K", 1234567 → "1.2M", 13.5 → "13.5"

const SUFFIXES: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi"]


## 일반 정수/실수 값 축약
static func format_num(val: float) -> String:
	var negative: bool = val < 0.0
	var abs_val: float = absf(val)
	if abs_val < 1000.0:
		return ("-" if negative else "") + _trim(abs_val)
	var tier: int = 0
	while abs_val >= 1000.0 and tier < SUFFIXES.size() - 1:
		abs_val /= 1000.0
		tier += 1
	# 반올림으로 1000.0K 같은 표기가 나오면 다음 단위로 올린다
	if snappedf(abs_val, 0.1) >= 1000.0 and tier < SUFFIXES.size() - 1:
		abs_val /= 1000.0
		tier += 1
	return ("-" if negative else "") + _trim(abs_val) + SUFFIXES[tier]


## FixedNum(값×10) 값 축약
static func format_fixed(fixed_value: int) -> String:
	if absi(fixed_value) < 1000 * FixedNum.SCALE:
		return FixedNum.to_text(fixed_value)
	return format_num(float(fixed_value) / float(FixedNum.SCALE))


## 소수점 1자리까지, .0은 생략
static func _trim(v: float) -> String:
	var snapped_v: float = snappedf(v, 0.1)
	if is_equal_approx(snapped_v, roundf(snapped_v)):
		return str(int(roundf(snapped_v)))
	return "%.1f" % snapped_v
