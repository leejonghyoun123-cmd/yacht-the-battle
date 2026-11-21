class_name InsuranceItem
extends UserItemData
## 패배 보험 증서: 전투에서 지면 이번 라운드에 새로 소환한 인원의 40%만큼 골드 환급.
## (9칸 모두 중첩칸이 된 뒤 "소비칸 보험"에서 바뀜)

@export var refund_ratio: float = 0.4


func on_settle(_item: ItemInstance, session: GameSession, result: BattleResult, _summary: Dictionary) -> String:
	if result.winner != 1:
		return ""
	var gold: int = int(floorf(float(session.battle_new_summon_total) * refund_ratio))
	if gold <= 0:
		return ""
	session.player.add_gold(gold, PlayerState.GoldSource.OTHER)
	return "패배 보험: +%d원" % gold
