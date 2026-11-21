class_name StarterDeck
extends RefCounted
## 프로토타입용 시작 덱. 상점이 생기기 전까지 인첸트 순서 조작·덱 스왑을 바로 시험할 수 있게
## 미리 인첸트를 장착해 둔다. (정식 게임의 시작 덱은 상점 구현 때 다시 정한다)

const D6: String = "res://data/dice/d6.tres"
const D20: String = "res://data/dice/d20.tres"
const ADD3: String = "res://data/enchants/add_common.tres"
const ADD7: String = "res://data/enchants/add_uncommon.tres"
const MUL15: String = "res://data/enchants/mul_common.tres"
const MUL2: String = "res://data/enchants/mul_uncommon.tres"
const MUL3: String = "res://data/enchants/mul_rare.tres"
const ECHO: String = "res://data/enchants/echo_slot.tres"
const LOWER: String = "res://data/enchants/remove_lower_half.tres"
const SUB100: String = "res://data/enchants/sub_from_100.tres"


static func build_into(deck: DeckManager) -> void:
	var active: Array[DiceInstance] = [
		_make(D6, []),
		_make(D6, [ADD3, MUL2]),
		_make(D6, [MUL2, ADD3]),
		_make(D6, [LOWER, ADD3, ECHO]),
		_make(D6, [MUL15, ECHO]),
	]
	deck.set_active(active)
	deck.set_reserve(0, _make(D20, [ADD7]))
	deck.set_reserve(1, _make(D6, [MUL3, SUB100]))


## 정식 시작 덱: 인첸트 없는 6면 주사위 5개 + 빈 예비 2칸 (GameSession이 사용)
static func build_plain_into(deck: DeckManager) -> void:
	var active: Array[DiceInstance] = []
	for i: int in range(GameBalance.ACTIVE_DICE_COUNT):
		active.append(_make(D6, []))
	deck.set_active(active)


static func _make(dice_path: String, enchant_paths: Array) -> DiceInstance:
	var d: DiceInstance = DiceInstance.new(load(dice_path) as DiceData)
	var slot: int = 0
	for path: String in enchant_paths:
		d.equip(EnchantInstance.new(load(path) as EnchantData), slot)
		slot += 1
	return d
