class_name PlayerState
extends RefCounted
## 플레이어 자원 (골드·체력). UI는 시그널만 구독한다.

signal gold_changed(new_gold: int)
signal hp_changed(hp: int, max_hp: int)

## 골드 출처 태그 (고리대금 계약서 등은 특정 출처만 차감하므로 반드시 구분)
enum GoldSource {
	YACHT_BOARD, WIN_STREAK, ROUND_INCOME, WIN_BONUS,
	PIGGY_BANK, CONSUMABLE_SALE, DICE_TRAIT, LOAN, OTHER,
}

var gold: int = GameBalance.START_GOLD
var hp: int = GameBalance.START_HP
var max_hp: int = GameBalance.START_HP


## 골드 지급. 실제로 더해진 금액을 반환한다 (출처별 보정은 이후 아이템 시스템에서 연결).
func add_gold(amount: int, _source: GoldSource) -> int:
	if amount <= 0:
		return 0
	gold = FixedNum.add(gold, amount)
	gold_changed.emit(gold)
	return amount


func can_afford(amount: int) -> bool:
	return gold >= amount


func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


## 체력 감소. 0 미만으로 내려가지 않는다.
func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	hp = maxi(0, hp - amount)
	hp_changed.emit(hp, max_hp)


func heal(amount: int) -> void:
	if amount <= 0:
		return
	hp = mini(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func is_dead() -> bool:
	return hp <= 0
