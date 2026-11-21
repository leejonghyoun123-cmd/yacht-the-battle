class_name DiceRollResolver
extends RefCounted
## 활성 주사위 5개 일괄 굴림 해석기 (02 문서의 5-Pass 순서).
##   Pass 1: 일반 주사위 굴림 + 슬롯 연산
##   Pass 2: 자석 주사위            — 성질 시스템 구현 시 추가
##   Pass 3: Cross-Dice 인첸트 (좌→우) — 인첸트 확장 시 추가
##   Pass 4: 거울 주사위 (좌→우)     — 성질 시스템 구현 시 추가
##   Pass 5: 족보 연동 인첸트        — 인첸트 확장 시 추가
## 재굴림: held[i] == true인 주사위는 이전 원시 눈금을 유지한 채 연산만 다시 한다.


## dice: 활성 슬롯 주사위 배열 (보통 5개)
## rng: 시드가 주입된 결정론적 RNG
## held / previous: 재굴림 시 고정할 주사위와 직전 결과 (첫 굴림이면 비워 둔다)
static func resolve(
		dice: Array[DiceInstance],
		rng: RandomNumberGenerator,
		round_number: int,
		held: Array[bool] = [],
		previous: Array[DiceRollResult] = [],
		modifiers: Dictionary = {}) -> Array[DiceRollResult]:
	var results: Array[DiceRollResult] = []
	# Pass 1: 일반 주사위
	for i: int in range(dice.size()):
		var ctx: RollContext = RollContext.new(rng, round_number)
		ctx.active_index = i
		_apply_modifiers(ctx, modifiers)
		var keep: bool = i < held.size() and held[i] and i < previous.size() and previous[i] != null
		if keep:
			dice[i].run_pipeline(ctx, previous[i].raw_roll)
		else:
			dice[i].roll(ctx)
		results.append(DiceRollResult.from_context(i, ctx))
	return results


## 보스 등 굴림 규칙 수정치 적용
##   "disabled_slots": Array[int]  — 9R 침묵의 시계탑 (슬롯 1 정지)
##   "tax_multipliers": bool       — 12R 탐욕의 수금원 (2번째 이후 곱연산 절반)
static func _apply_modifiers(ctx: RollContext, modifiers: Dictionary) -> void:
	if modifiers.has("disabled_slots"):
		var slots: Array[int] = []
		for s: int in modifiers["disabled_slots"]:
			slots.append(s)
		ctx.disabled_slot_indices = slots
	if modifiers.get("tax_multipliers", false):
		ctx.tax_extra_multipliers = true


## 결과 배열 → 확정 소환값 배열 (얏츠판 입력용)
static func to_summon_values(results: Array[DiceRollResult]) -> Array[int]:
	var values: Array[int] = []
	for r: DiceRollResult in results:
		values.append(r.summon_value)
	return values
