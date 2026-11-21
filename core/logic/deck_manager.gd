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
		# 이번 라운드에 굴린 주사위 기록 (이 주사위들의 인첸트는 라운드가 끝날 때까지 고정)
		rolled_dice = active.duplicate()
		lock_changed.emit(true)


func unlock() -> void:
	if is_deck_locked:
		is_deck_locked = false
		rolled_dice.clear()
		lock_changed.emit(false)


## 이번 라운드에 굴린 주사위 (인첸트 장착·해제·이동 불가)
var rolled_dice: Array[DiceInstance] = []


## 이 주사위의 인첸트를 바꿀 수 있는가 (이번 라운드에 굴리지 않았으면 가능)
func can_edit_dice(dice: DiceInstance) -> bool:
	return dice != null and not rolled_dice.has(dice)


## 활성+예비 전체 주사위
func all_dice() -> Array[DiceInstance]:
	var result: Array[DiceInstance] = active.duplicate()
	for d: DiceInstance in reserve:
		if d != null:
			result.append(d)
	return result


## 인첸트 이동: 주사위 A의 슬롯 → 주사위 B의 슬롯 (대상에 인첸트가 있으면 서로 맞바꿈)
func transfer_enchant(from_dice: DiceInstance, from_slot: int, to_dice: DiceInstance, to_slot: int) -> bool:
	if not can_edit_dice(from_dice) or not can_edit_dice(to_dice):
		return false
	if from_slot < 0 or from_slot >= from_dice.unlocked_slots or to_slot < 0 or to_slot >= to_dice.unlocked_slots:
		return false
	if from_dice == to_dice and from_slot == to_slot:
		return false
	var moving: EnchantInstance = from_dice.slots[from_slot]
	if moving == null:
		return false
	from_dice.slots[from_slot] = to_dice.slots[to_slot]
	to_dice.slots[to_slot] = moving
	deck_changed.emit()
	return true


## 인첸트를 빈 슬롯에 장착 (상점 구매)
func equip_enchant(dice: DiceInstance, slot: int, instance: EnchantInstance) -> bool:
	if not can_edit_dice(dice):
		return false
	if dice.equip(instance, slot):
		deck_changed.emit()
		return true
	return false


## 인첸트 제거 (판매). 제거된 인첸트 반환
func remove_enchant(dice: DiceInstance, slot: int) -> EnchantInstance:
	if not can_edit_dice(dice):
		return null
	var removed: EnchantInstance = dice.unequip(slot)
	if removed != null:
		deck_changed.emit()
	return removed


## 장착 가능한 빈 슬롯이 하나라도 있는가 (인첸트 구매 가능 여부)
func has_free_enchant_slot() -> bool:
	for d: DiceInstance in all_dice():
		if not can_edit_dice(d):
			continue
		for i: int in range(d.unlocked_slots):
			if d.slots[i] == null:
				return true
	return false


## 가방(예비)의 첫 빈칸에 주사위 추가
func add_to_reserve(dice: DiceInstance) -> bool:
	for i: int in range(reserve_unlocked):
		if reserve[i] == null:
			reserve[i] = dice
			deck_changed.emit()
			return true
	return false


func has_reserve_space() -> bool:
	for i: int in range(reserve_unlocked):
		if reserve[i] == null:
			return true
	return false


func first_reserve_index() -> int:
	for i: int in range(reserve_unlocked):
		if reserve[i] != null:
			return i
	return -1


## 주사위 제거 (판매). 활성 주사위는 가방의 첫 주사위로 채운다 — 채울 주사위가 없으면 실패.
## 이번 라운드에 굴린 주사위는 제거 불가.
func remove_dice(dice: DiceInstance) -> bool:
	if not can_edit_dice(dice):
		return false
	var ai: int = active.find(dice)
	if ai >= 0:
		if is_deck_locked:
			return false
		var ri: int = first_reserve_index()
		if ri < 0:
			return false
		active[ai] = reserve[ri]
		reserve[ri] = null
		deck_changed.emit()
		return true
	var rj: int = reserve.find(dice)
	if rj >= 0:
		reserve[rj] = null
		deck_changed.emit()
		return true
	return false


## 가방 속 주사위가 들어 있는 칸 번호들
func reserve_filled_indices() -> Array[int]:
	var result: Array[int] = []
	for i: int in range(reserve_unlocked):
		if reserve[i] != null:
			result.append(i)
	return result


## [전체 교체] 가방 주사위 수만큼 고른 출전 주사위들과 맞바꾼다.
## 가방이 5개로 가득이면 고를 필요 없이 전부(active_indices 무시).
func swap_selected(active_indices: Array[int]) -> bool:
	if not can_edit():
		return false
	var filled: Array[int] = reserve_filled_indices()
	if filled.is_empty():
		return false
	if filled.size() >= active.size():
		return swap_active_and_reserve()
	if active_indices.size() != filled.size():
		return false
	for k: int in range(filled.size()):
		var ai: int = active_indices[k]
		if ai < 0 or ai >= active.size():
			return false
	for k: int in range(filled.size()):
		var temp: DiceInstance = active[active_indices[k]]
		active[active_indices[k]] = reserve[filled[k]]
		reserve[filled[k]] = temp
	deck_changed.emit()
	return true


## 가방 등급에 맞춰 예비 슬롯 수 설정 (줄이지는 않음)
func set_reserve_slots(count: int) -> void:
	var target: int = clampi(count, reserve_unlocked, GameBalance.MAX_RESERVE_SLOTS)
	if target != reserve_unlocked:
		reserve_unlocked = target
		deck_changed.emit()


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


## 인첸트 슬롯 순서 변경 (이번 라운드에 굴린 주사위는 불가, 가방 속 주사위는 가능)
func move_enchant(dice: DiceInstance, from: int, to: int) -> bool:
	if not can_edit_dice(dice):
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
