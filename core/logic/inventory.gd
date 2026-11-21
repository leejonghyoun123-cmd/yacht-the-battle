class_name Inventory
extends RefCounted
## 보유 유저 아이템·타로카드 (UI 없는 순수 로직)
##   아이템: 최대 MAX_ITEMS개, priority 순으로 굴림 파이프라인에 들어간다
##   타로: 손패(미사용) 최대 MAX_TAROT_HAND장 / 예약(전투 소모품) 최대 MAX_RESERVED장
##   유닛칸 타로는 BoardState.slot_modifiers에, 더 타워는 towers 수로, 저스티스는 PlayerState 실드로 남는다

signal changed

const MAX_ITEMS: int = 6
const MAX_TAROT_HAND: int = 3
const MAX_RESERVED: int = 2

var items: Array[ItemInstance] = []
var tarot_hand: Array[TarotCardData] = []
var tarot_reserved: Array[TarotCardData] = []
## 설치한 더 타워 수
var towers: int = 0
var tower_card: TarotCardData = null
## 칸별로 붙인 타로 (표시용) { cell_index: Array[TarotCardData] }
var cell_tarots: Dictionary = {}


func has_item_space() -> bool:
	return items.size() < MAX_ITEMS


func has_tarot_space() -> bool:
	return tarot_hand.size() < MAX_TAROT_HAND


func owns_item(id: StringName) -> bool:
	for it: ItemInstance in items:
		if it.data.id == id:
			return true
	return false


## 우선순위 순 정렬된 목록 (굴림 파이프라인용)
func get_sorted_items() -> Array:
	var sorted: Array = items.duplicate()
	sorted.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool: return a.data.priority < b.data.priority)
	return sorted


func get_reroll_bonus() -> int:
	var total: int = 0
	for it: ItemInstance in items:
		total += it.data.get_reroll_bonus(it)
	return total


func has_forgery() -> bool:
	for it: ItemInstance in items:
		if it.data.enables_forgery():
			return true
	return false


func remove_expired() -> void:
	for i: int in range(items.size() - 1, -1, -1):
		if bool(items[i].state.get("expired", false)):
			items.remove_at(i)
	changed.emit()


## 내 팀 정예 압축 규칙 (유압 압축기). 여러 개면 가장 낮은 기준·가장 높은 보정
func get_compression() -> Dictionary:
	var out: Dictionary = {}
	for it: ItemInstance in items:
		var c: Dictionary = it.data.get_compression(it)
		if c.is_empty():
			continue
		if not out.has("threshold") or int(c["threshold"]) < int(out["threshold"]):
			out["threshold"] = c["threshold"]
		out["bonus"] = maxf(float(out.get("bonus", 0.0)), float(c["bonus"]))
	return out


## 지금 쓸 수 있는 무단 침입 통행증 (없으면 null)
func get_rolling_swap_item() -> ItemInstance:
	for it: ItemInstance in items:
		if it.data.allows_rolling_swap(it):
			return it
	return null
