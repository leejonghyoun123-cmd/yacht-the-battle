class_name InsuranceItem
extends UserItemData
## 소비칸 보험 증서: 전투에서 지면 소비칸에 소환했던 환산 인원의 40%만큼 골드 환급

@export var refund_ratio: float = 0.4


func on_settle(_item: ItemInstance, session: GameSession, result: BattleResult, _summary: Dictionary) -> String:
	if result.winner != 1:
		return ""
	var gold: int = int(floorf(float(session.battle_consumable_total) * refund_ratio))
	if gold <= 0:
		return ""
	session.player.add_gold(gold, PlayerState.GoldSource.OTHER)
	return "소비칸 보험: +%d원" % gold
