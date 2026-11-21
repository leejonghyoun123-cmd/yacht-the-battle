class_name DiceRollResult
extends RefCounted
## 주사위 1개의 굴림 결과 (UI·얏츠판·소환에 전달되는 읽기 전용 데이터)

var dice_index: int = 0
var raw_roll: int = 0
## 연산 최종값 (FixedNum, 소수점 1자리 포함)
var final_value: int = 0
## 확정 소환값 (반올림된 정수, 최소 1) — 얏츠판 판정과 소환 인원에 사용
var summon_value: int = 0
var logs: Array[Dictionary] = []


static func from_context(index: int, ctx: RollContext) -> DiceRollResult:
	var r: DiceRollResult = DiceRollResult.new()
	r.dice_index = index
	r.raw_roll = ctx.raw_roll
	r.final_value = ctx.value
	r.summon_value = ctx.get_summon_value()
	r.logs = ctx.logs
	return r


## 로그를 "6 → +3 → 9 → ×2 → 18" 형태 문자열로 (디버그·테스트용)
func describe() -> String:
	var parts: PackedStringArray = []
	for entry: Dictionary in logs:
		if entry["skipped"]:
			parts.append("[%s 미발동: %s]" % [entry["source"], entry["reason"]])
		elif entry["source"] == "원시 눈금":
			parts.append(FixedNum.to_text(entry["value"]))
		elif String(entry["op"]).begins_with("면 "):
			parts.append("{%s %s}" % [entry["source"], entry["op"]])
		else:
			var clamp_mark: String = "(1로 보정)" if entry["clamped"] else ""
			parts.append("%s → %s%s" % [entry["op"], FixedNum.to_text(entry["value"]), clamp_mark])
	return " ".join(parts) + "  ⇒ 소환 " + str(summon_value)
