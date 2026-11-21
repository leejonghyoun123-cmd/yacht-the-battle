class_name BattleSettlement
extends RefCounted
## 솔로 전투 정산 (팀 0 = 플레이어, 팀 1 = 적).
##   승리: 기본 승리 보너스 + 연승 보상 + 소비칸 생존자 판매(환산 1명당 5원)
##   패배: 적 생존 환산 인원만큼 체력 피해(라운드 상한 적용) + 연패 보상
##   무승부: 피해·보상 없음
## 공통: 소비칸 비우기, 중첩칸은 보존 정책에 따라 정리.


## 반환: 화면 표시용 요약 Dictionary
static func settle_solo(result: BattleResult, player: PlayerState, board: BoardState,
		streak: StreakState, round_number: int) -> Dictionary:
	var summary: Dictionary = {
		"winner": result.winner, "reason": result.reason,
		"win_bonus": 0, "streak_bonus": 0, "sale_count": 0, "sale_gold": 0,
		"damage": 0, "damage_raw": 0,
	}
	if result.winner == 0:
		summary["win_bonus"] = player.add_gold(GameBalance.WIN_BONUS, PlayerState.GoldSource.WIN_BONUS)
		summary["streak_bonus"] = player.add_gold(streak.record_win(), PlayerState.GoldSource.WIN_STREAK)
		var sale_count: int = result.get_consumable_survivors(0, board)
		summary["sale_count"] = sale_count
		summary["sale_gold"] = player.add_gold(_mul(sale_count, GameBalance.CONSUMABLE_SALE_PER_UNIT), PlayerState.GoldSource.CONSUMABLE_SALE)
	elif result.winner == 1:
		var raw_damage: int = _mul(result.get_survivor_total(1), GameBalance.DAMAGE_PER_ENEMY_UNIT)
		var cap: int = GameBalance.get_damage_cap(round_number)
		var damage: int = mini(raw_damage, cap) if cap > 0 else raw_damage
		summary["damage_raw"] = raw_damage
		summary["damage"] = damage
		player.take_damage(damage)
		# 연패 보상은 고리대금 계약서 차감 대상(얏츠판·연승)이 아니므로 OTHER로 태깅
		summary["streak_bonus"] = player.add_gold(streak.record_loss(), PlayerState.GoldSource.OTHER)
	board.clear_consumables()
	board.apply_stack_retention(result.survivors_by_cell[0])
	return summary


static func _mul(a: int, b: int) -> int:
	if a > 0 and b > 0 and a > FixedNum.MAX / b:
		return FixedNum.MAX
	return a * b
