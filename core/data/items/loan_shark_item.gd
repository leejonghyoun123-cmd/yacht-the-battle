class_name LoanSharkItem
extends UserItemData
## 고리대금 계약서: 획득 즉시 +800원. 이후 3라운드 동안 얏츠판·연승 보상의 50%를 자동 상환 (PlayerState.add_gold)

@export var loan: int = 800
@export var rounds: int = 3


func on_acquire(_item: ItemInstance, session: GameSession) -> String:
	session.player.add_gold(loan, PlayerState.GoldSource.LOAN)
	session.player.loan_rounds_left += rounds
	return "고리대금: +%d원 (3라운드 상환)" % loan


func on_round_end(item: ItemInstance, session: GameSession) -> void:
	if session.player.loan_rounds_left > 0:
		session.player.loan_rounds_left -= 1
	if session.player.loan_rounds_left <= 0:
		item.state["expired"] = true


func get_state_text(_item: ItemInstance) -> String:
	return "상환 중"
