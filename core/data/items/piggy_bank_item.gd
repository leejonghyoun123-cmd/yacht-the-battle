class_name PiggyBankItem
extends UserItemData
## 돼지저금통(+150/라운드) / 주사위저금통(+50/라운드, 깰 때 1~6배): 준비 단계에 [깨기]로 전액 획득 후 사라짐

const STATE_BANK: String = "bank"
@export var per_round: int = 150
## true면 깰 때 1~6 랜덤 배수
@export var dice_multiplier: bool = false


func on_round_end(item: ItemInstance, _session: GameSession) -> void:
	item.state[STATE_BANK] = int(item.state.get(STATE_BANK, 0)) + per_round


func can_activate(item: ItemInstance) -> bool:
	return int(item.state.get(STATE_BANK, 0)) > 0


func get_activate_label() -> String:
	return "깨기"


func activate(item: ItemInstance, session: GameSession) -> String:
	var bank: int = int(item.state.get(STATE_BANK, 0))
	var mult: int = session.rng.randi_range(1, 6) if dice_multiplier else 1
	var gold: int = session.player.add_gold(bank * mult, PlayerState.GoldSource.PIGGY_BANK)
	return "%s 깨기: %s+%d원" % [display_name, ("×%d → " % mult) if dice_multiplier else "", gold]


func get_state_text(item: ItemInstance) -> String:
	return "적립금 %d원" % int(item.state.get(STATE_BANK, 0))
