class_name DiceRollResolver
extends RefCounted
## 활성 주사위 5개 일괄 굴림 해석기 (02 문서 5-Pass / 03 문서 3-Pass).
##   Pass 1: 일반 주사위 굴림 + 슬롯 연산
##   Pass 2: 자석 주사위 — Pass 1 원시 눈금 최빈값으로 50% 확률 동기화
##   Pass 3: Cross-Dice 인첸트 (좌→우) — 인첸트 확장 시 추가
##   Pass 4: 거울 주사위 (좌→우) — 왼쪽 주사위 최종값 복사 (왼쪽도 거울이면 1)
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
	results.resize(dice.size())
	# Pass 1: 일반 주사위
	for i: int in range(dice.size()):
		if _pass_of(dice[i]) != DiceTraitData.RollPass.NORMAL:
			continue
		var ctx: RollContext = _new_context(i, rng, round_number, modifiers)
		if _is_held(i, held, previous):
			dice[i].run_pipeline(ctx, previous[i].raw_roll)
		else:
			dice[i].roll(ctx)
		results[i] = DiceRollResult.from_context(i, ctx)
	# Pass 2: 자석 주사위
	for i: int in range(dice.size()):
		if _pass_of(dice[i]) != DiceTraitData.RollPass.MAGNET:
			continue
		var ctx: RollContext = _new_context(i, rng, round_number, modifiers)
		if _is_held(i, held, previous):
			dice[i].run_pipeline(ctx, previous[i].raw_roll)
		else:
			var faces: Array[int] = dice[i].get_modified_faces(ctx.disabled_slot_indices)
			var raw: int = faces[rng.randi_range(0, faces.size() - 1)]
			var mode: int = _mode_of(results, i)
			var magnet: MagnetTrait = dice[i].trait_data as MagnetTrait
			if mode > 0 and rng.randf() < magnet.pull_chance:
				raw = mode
			dice[i].run_pipeline(ctx, raw)
			if raw == mode:
				ctx.log_step("자석", "최빈값 %d에 끌림" % mode)
		results[i] = DiceRollResult.from_context(i, ctx)
	# Pass 4: 거울 주사위 (좌→우, 연쇄 복사 차단)
	for i: int in range(dice.size()):
		if _pass_of(dice[i]) != DiceTraitData.RollPass.MIRROR:
			continue
		var ctx: RollContext = _new_context(i, rng, round_number, modifiers)
		var left: DiceRollResult = results[i - 1] if i > 0 else null
		var left_is_mirror: bool = i > 0 and _pass_of(dice[i - 1]) == DiceTraitData.RollPass.MIRROR
		ctx.begin(1)
		if left == null or left_is_mirror:
			ctx.log_skip("거울 주사위", "맨 왼쪽이거나 왼쪽도 거울이라 복사할 수 없음 (1)")
		else:
			ctx.raw_roll = left.raw_roll
			ctx.set_value(left.final_value, "거울 주사위", "왼쪽 복사")
		results[i] = DiceRollResult.from_context(i, ctx)
	return results


static func _pass_of(d: DiceInstance) -> DiceTraitData.RollPass:
	return d.trait_data.roll_pass if d.trait_data != null else DiceTraitData.RollPass.NORMAL


static func _is_held(i: int, held: Array[bool], previous: Array[DiceRollResult]) -> bool:
	return i < held.size() and held[i] and i < previous.size() and previous[i] != null


static func _new_context(i: int, rng: RandomNumberGenerator, round_number: int, modifiers: Dictionary) -> RollContext:
	var ctx: RollContext = RollContext.new(rng, round_number)
	ctx.active_index = i
	_apply_modifiers(ctx, modifiers)
	return ctx


## Pass 1 결과의 원시 눈금 최빈값 (자신 제외, 동률이면 큰 수). 없으면 0.
static func _mode_of(results: Array[DiceRollResult], self_index: int) -> int:
	var counts: Dictionary = {}
	for j: int in range(results.size()):
		if j == self_index or results[j] == null:
			continue
		counts[results[j].raw_roll] = int(counts.get(results[j].raw_roll, 0)) + 1
	var best: int = 0
	var best_count: int = 0
	for v: int in counts.keys():
		var c: int = counts[v]
		if c > best_count or (c == best_count and v > best):
			best = v
			best_count = c
	return best


## 보스·아이템 등 굴림 규칙 수정치 적용
##   "disabled_slots": Array[int]  — 9R 침묵의 시계탑 (슬롯 1 정지)
##   "tax_multipliers": bool       — 12R 탐욕의 수금원 (2번째 이후 곱연산 절반)
##   "items": Array[ItemInstance]  — 보유 유저 아이템 (우선순위 순)
##   "bench_count": int            — 가방 속 주사위 수
static func _apply_modifiers(ctx: RollContext, modifiers: Dictionary) -> void:
	if modifiers.has("disabled_slots"):
		var slots: Array[int] = []
		for s: int in modifiers["disabled_slots"]:
			slots.append(s)
		ctx.disabled_slot_indices = slots
	if modifiers.get("tax_multipliers", false):
		ctx.tax_extra_multipliers = true
	if modifiers.has("items"):
		ctx.items = modifiers["items"]
	ctx.bench_count = int(modifiers.get("bench_count", 0))


## 결과 배열 → 확정 소환값 배열 (얏츠판 입력용)
static func to_summon_values(results: Array[DiceRollResult]) -> Array[int]:
	var values: Array[int] = []
	for r: DiceRollResult in results:
		values.append(r.summon_value)
	return values
