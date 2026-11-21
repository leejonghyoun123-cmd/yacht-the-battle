class_name PokerTrait
extends DiceTraitData
## 포커카드 (2면 주사위 전용). 면을 1(A) ~ 13(K)로 바꾼다.
## A가 나오면 거인, K가 나오면 킹을 배치할 수 있다 (일반 병과도 그대로 가능).
## 수트(♠♥♦♣)는 변환 시 1회 추첨해 주사위에 기록한다. (수트 스탯 효과는 다음 단계에서 연결)

enum SuitType { SPADE, HEART, DIAMOND, CLOVER }
const SUIT_SYMBOLS: Array[String] = ["♠", "♥", "♦", "♣"]
const SUIT_NAMES: Array[String] = ["스페이드", "하트", "다이아", "클로버"]
const STATE_SUIT: String = "poker_suit"

@export var face_count: int = 13
## 눈금 → 해금 병과
@export var royal_units: Dictionary = { 1: &"giant", 13: &"king" }


func can_attach_to(dice: DiceInstance) -> bool:
	return super.can_attach_to(dice) and dice.data.faces.size() == 2


func on_attach(dice: DiceInstance, rng: RandomNumberGenerator) -> void:
	dice.runtime_state[STATE_SUIT] = rng.randi_range(0, SUIT_SYMBOLS.size() - 1)


func modify_base_faces(_faces: Array[int], _dice: DiceInstance) -> Array[int]:
	var out: Array[int] = []
	for i: int in range(1, face_count + 1):
		out.append(i)
	return out


func get_unlocked_units(raw_roll: int, _dice: DiceInstance) -> Array[StringName]:
	var out: Array[StringName] = []
	if royal_units.has(raw_roll):
		out.append(StringName(royal_units[raw_roll]))
	return out


func face_label(value: int) -> String:
	match value:
		1:
			return "A"
		11:
			return "J"
		12:
			return "Q"
		13:
			return "K"
	return str(value)


static func get_suit(dice: DiceInstance) -> int:
	return int(dice.runtime_state.get(STATE_SUIT, 0))


func get_badge_text(dice: DiceInstance) -> String:
	return SUIT_SYMBOLS[get_suit(dice)] + badge


func get_requirement_text() -> String:
	return "2면 주사위 · 성질 없음"
