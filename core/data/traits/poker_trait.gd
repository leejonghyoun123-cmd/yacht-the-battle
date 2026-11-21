class_name PokerTrait
extends DiceTraitData
## 포커카드 (성질 없는 6면 주사위 전용 — 2면 주사위 삭제로 변경). 면을 1(A) ~ 13(K)로 바꾼다.
## A가 나오면 거인, K가 나오면 킹을 배치할 수 있다 (일반 병과도 그대로 가능).
## 수트(♠♥♦♣)는 변환 시 1회 추첨해 주사위에 기록하고, 이 주사위로 소환한 칸에 수트 보정을 붙인다.
##   ♠ 공격력 ×1.2 / ♥ 최대 체력 ×1.2 / ♦ 전투 시작 시 최대 체력 20% 실드 / ♣ 공격 속도 ×1.2
## 로열 눈금(A·J·Q·K)은 그 칸 유닛에 최상위 정예 강화(공격력·체력 +30%, 크기 +20%)를 붙인다.

enum SuitType { SPADE, HEART, DIAMOND, CLOVER }
const SUIT_SYMBOLS: Array[String] = ["♠", "♥", "♦", "♣"]
const SUIT_NAMES: Array[String] = ["스페이드", "하트", "다이아", "클로버"]
const STATE_SUIT: String = "poker_suit"
const ROYAL_FACES: Array[int] = [1, 11, 12, 13]

@export var face_count: int = 13
## 눈금 → 해금 병과
@export var royal_units: Dictionary = { 1: &"giant", 13: &"king" }

## 수트·로열 보정 (같은 인스턴스를 써야 한 칸에 중복으로 쌓이지 않는다)
static var _suit_mods: Array[StatModifier] = []
static var _royal_mod: StatModifier = null


static func get_suit_modifier(suit: int) -> StatModifier:
	if _suit_mods.is_empty():
		_suit_mods = [
			StatModifier.make("♠ 스페이드: 공격력 ×1.2", { "attack_mult": 1.2 }),
			StatModifier.make("♥ 하트: 최대 체력 ×1.2", { "hp_mult": 1.2 }),
			StatModifier.make("♦ 다이아: 체력 20% 실드", { "shield_ratio": 0.2 }),
			StatModifier.make("♣ 클로버: 공격 속도 ×1.2", { "haste_mult": 1.2 }),
		]
	return _suit_mods[clampi(suit, 0, 3)]


static func get_royal_modifier() -> StatModifier:
	if _royal_mod == null:
		_royal_mod = StatModifier.make("로열: 공격력·체력 +30%, 크기 +20%", { "attack_mult": 1.3, "hp_mult": 1.3, "size_mult": 1.2 })
	return _royal_mod


func can_attach_to(dice: DiceInstance) -> bool:
	return super.can_attach_to(dice) and dice.data.faces.size() == 6


func get_requirement_text() -> String:
	return "6면 주사위 · 성질 없음"


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


func get_cell_modifiers(raw_roll: int, dice: DiceInstance) -> Array[StatModifier]:
	var out: Array[StatModifier] = [get_suit_modifier(get_suit(dice))]
	if ROYAL_FACES.has(raw_roll):
		out.append(get_royal_modifier())
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


static func is_red(suit: int) -> bool:
	return suit == SuitType.HEART or suit == SuitType.DIAMOND


func get_badge_text(dice: DiceInstance) -> String:
	return SUIT_SYMBOLS[get_suit(dice)] + badge


func get_state_text(dice: DiceInstance) -> String:
	return "수트 %s %s" % [SUIT_SYMBOLS[get_suit(dice)], SUIT_NAMES[get_suit(dice)]]


func get_missing_text() -> String:
	return "성질 없는 6면주사위를 보유하고있어야 구매가 가능합니다"
