class_name FinalBonusItem
extends UserItemData
## 최종값 보정 아이템 (성질까지 끝난 뒤):
##   EMPTY_SLOT  빈 슬롯의 미학 — 개방됐지만 빈 인첸트 슬롯 1칸당 ×(1 + 0.25)
##   BENCH       벤치 응원봉     — 가방 속 주사위 1개당 ×(1 + 0.1)
##   OVERFLOW    오버플로우 배터리 — 연산 중 0 아래로 떨어진 양을 최종값에 더함
##   LAST_DIGIT  끝자리 세탁기    — 최종값 1의 자리를 9로 올림 (12 → 19)

enum Mode { EMPTY_SLOT, BENCH, OVERFLOW, LAST_DIGIT }
@export var mode: Mode = Mode.EMPTY_SLOT
@export var per_unit_bonus: float = 0.25


func on_final(ctx: RollContext, _item: ItemInstance, dice: DiceInstance) -> void:
	match mode:
		Mode.EMPTY_SLOT:
			var empty: int = 0
			for i: int in range(dice.unlocked_slots):
				if dice.slots[i] == null:
					empty += 1
			if empty > 0:
				DiceTraitData.multiply(ctx, 1.0 + per_unit_bonus * float(empty), display_name)
		Mode.BENCH:
			if ctx.bench_count > 0:
				DiceTraitData.multiply(ctx, 1.0 + per_unit_bonus * float(ctx.bench_count), display_name)
		Mode.OVERFLOW:
			if ctx.underflow_bank > 0:
				ctx.set_value(FixedNum.add(ctx.value, ctx.underflow_bank), display_name, "+" + FixedNum.to_text(ctx.underflow_bank))
		Mode.LAST_DIGIT:
			var v: int = ctx.get_summon_value()
			if v % 10 != 9:
				ctx.set_value(FixedNum.from_int(v - v % 10 + 9), display_name, "끝자리 9")
