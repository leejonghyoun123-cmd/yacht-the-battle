class_name DeckManager
extends RefCounted
## 이중 덱: 활성 슬롯 5칸(항상 가득 참) + 예비 슬롯 최대 5칸(초기 2칸 개방).
## 라운드 첫 굴림 후에는 is_deck_locked = true가 되어 교체·스왑·인첸트 순서 변경이 막힌다.

signal deck_changed
signal lock_changed(locked: bool)

var active: Array[DiceInstance] = []
## 예비 슬롯 (항상 MAX_RESERVE_SLOTS 길이, 빈칸은 null)
var reserve: Array[DiceInstance] = []
var reserve_unlocked: int = GameBalance.START_RESERVE_SLOTS
var is_deck_locked: bool = false


func _init() -> void:
	reserve.resize(GameBalance.MAX_RESERVE_SLOTS)


## 활성 주사위 5개 설정 (덱 구성 시 1회)
func set_active(dice: Array[DiceInstance]) -> void:
	active = dice.duplicate()
	deck_changed.emit()


func set_reserve(index: int, dice: DiceInstance) -> bool:
	if index < 0 or index >= reserve_unlocked:
		return false
	reserve[index] = dice
	deck_changed.emit()
	return true


func can_edit() -> bool:
	return not is_deck_locked


func lock() -> void:
	if not is_deck_locked:
		is_deck_locked = true
		lock_changed.emit(true)


func unlock() -> void:
	if is_deck_locked:
		is_deck_locked = false
		lock_changed.emit(false)


## 활성 1개 ↔ 예비 1개 교체. 예비가 빈칸이면 실패 (활성 5개 유지).
func swap_slots(active_index: int, reserve_index: int) -> bool:
	if not can_edit():
		return false
	if active_index < 0 or active_index >= active.size():
		return false
	if reserve_index < 0 or reserve_index >= reserve_unlocked or reserve[reserve_index] == null:
		return false
	var temp: DiceInstance = active[active_index]
	active[active_index] = reserve[reserve_index]
	reserve[reserve_index] = temp
	deck_changed.emit()
	return true


## [덱 스왑] 활성 i번 ↔ 예비 i번을 개방된 예비 칸 수만큼 한 번에 교체 (예비 빈칸은 건너뜀).
func swap_active_and_reserve() -> bool:
	if not can_edit():
		return false
	var swapped: bool = false
	for i: int in range(mini(reserve_unlocked, active.size())):
		if reserve[i] == null:
			continue
		var temp: DiceInstance = active[i]
		active[i] = reserve[i]
		reserve[i] = temp
		swapped = true
	if swapped:
		deck_changed.emit()
	return swapped


## 인첸트 슬롯 순서 변경 (덱 잠금 시 불가)
func move_enchant(dice: DiceInstance, from: int, to: int) -> bool:
	if not can_edit():
		return false
	if dice.move_enchant(from, to):
		deck_changed.emit()
		return true
	return false


## 예비 슬롯 영구 확장 (가방 아이템)
func unlock_reserve_slots(count: int) -> int:
	var before: int = reserve_unlocked
	reserve_unlocked = clampi(reserve_unlocked + count, 0, GameBalance.MAX_RESERVE_SLOTS)
	if reserve_unlocked != before:
		deck_changed.emit()
	return reserve_unlocked - before
