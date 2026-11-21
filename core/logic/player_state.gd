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
## 고리대금 계약서: 남은 상환 라운드 (얏츠판·연승 보상의 절반을 차감)
var loan_rounds_left: int = 0
var loan_repaid: int = 0
## 저스티스: 매 라운드 리필되는 영구 실드 최대치와 현재값
var justice_shield_max: int = 0
var justice_shield: int = 0


func add_gold(amount: int, source: GoldSource) -> int:
	if amount <= 0:
		return 0
	if loan_rounds_left > 0 and (source == GoldSource.YACHT_BOARD or source == GoldSource.WIN_STREAK):
		var cut: int = amount / 2
		loan_repaid += cut
		amount -= cut
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


## 이번 라운드 임시 실드 (성벽증축). 라운드가 끝나면 0으로 초기화.
var round_shield: int = 0


## 라운드 피격: (상한은 호출 전에 적용) → 임시 실드 먼저 차감 → 남은 만큼 체력 감소.
## 반환: { "shield": 실드로 막은 양, "hp": 실제 체력 피해 }
func take_round_damage(amount: int) -> Dictionary:
	# 성벽증축(임시) → 저스티스(영구 리필) → 체력 순서
	var absorbed: int = mini(maxi(amount, 0), round_shield)
	round_shield -= absorbed
	var rest: int = maxi(amount, 0) - absorbed
	var justice: int = mini(rest, justice_shield)
	justice_shield -= justice
	rest -= justice
	take_damage(rest)
	return { "shield": absorbed + justice, "hp": rest }


## 라운드 시작 시 저스티스 실드 리필
func refill_justice_shield() -> void:
	justice_shield = justice_shield_max


## 최대 체력 증가 (식량축적). 상한 MAX_HP_CAP, 늘어난 만큼 현재 체력도 회복.
func increase_max_hp(amount: int) -> int:
	var before: int = max_hp
	max_hp = mini(GameBalance.MAX_HP_CAP, max_hp + amount)
	var gained: int = max_hp - before
	hp = mini(max_hp, hp + gained)
	hp_changed.emit(hp, max_hp)
	return gained
