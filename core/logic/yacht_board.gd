class_name YachtBoard
extends RefCounted
## 얏츠판: 족보 판정·기록·프레스티지. UI와 무관한 순수 로직.
## 판정은 확정 소환값(정수)의 1의 자리로 하고, "합"도 1의 자리 합이다.
##   - 1의 자리 0: 상단 해당 없음 / 스트레이트는 0~9 연속(9→0 순환 없음) / 포카드·풀하우스·얏츠에선 일반 숫자
## 매 라운드 1항목 필수 기록, 족보가 맞지 않으면 0원 기록.
## 10항목을 모두 채우면 즉시 프레스티지 +1, 보드 초기화, 이후 보상 2^프레스티지 배.

signal category_recorded(category: Category, gold: int)
signal prestige_triggered(new_level: int)

enum Category {
	ACES, TWOS, THREES, FOURS, FIVES,
	FOUR_OF_A_KIND, FULL_HOUSE, SMALL_STRAIGHT, LARGE_STRAIGHT, YACHT,
}

const CATEGORY_NAMES: Dictionary = {
	Category.ACES: "에이스",
	Category.TWOS: "투",
	Category.THREES: "쓰리",
	Category.FOURS: "포",
	Category.FIVES: "파이브",
	Category.FOUR_OF_A_KIND: "포오브카인드",
	Category.FULL_HOUSE: "풀하우스",
	Category.SMALL_STRAIGHT: "스몰 스트레이트",
	Category.LARGE_STRAIGHT: "라지 스트레이트",
	Category.YACHT: "얏츠",
}

# --- 보상 수치 (기획서 00 5장) ---
const GOLD_PER_PIP: int = 10
const BONUS_FOUR_OF_A_KIND: int = 75
const BONUS_FULL_HOUSE: int = 150
const BONUS_SMALL_STRAIGHT: int = 250
const BONUS_LARGE_STRAIGHT: int = 500
const YACHT_BASE: int = 500
const YACHT_PER_ROUND: int = 250
## 2^62 이상은 int64 범위를 넘으므로 배율 지수 상한
const MAX_PRESTIGE_SHIFT: int = 62

var prestige_level: int = 0
## 이번 사이클 기록 { Category: 지급 골드 }
var recorded: Dictionary = {}


func is_recorded(category: Category) -> bool:
	return recorded.has(category)


func get_reward_multiplier() -> int:
	return 1 << mini(prestige_level, MAX_PRESTIGE_SHIFT)


## 미기록 항목별 예상 골드 (프레스티지 배율 포함) { Category: gold }
func preview(values: Array[int], round_number: int) -> Dictionary:
	var result: Dictionary = {}
	for category: int in Category.values():
		if not is_recorded(category):
			result[category] = _apply_multiplier(score_base(category, values, round_number))
	return result


## 항목 기록. 이미 기록된 항목이면 -1. 지급할 골드를 반환한다.
## (골드 지급 자체는 경제 시스템이 담당하므로 여기서는 금액만 계산)
func record(category: Category, values: Array[int], round_number: int) -> int:
	if is_recorded(category):
		return -1
	var gold: int = _apply_multiplier(score_base(category, values, round_number))
	recorded[category] = gold
	category_recorded.emit(category, gold)
	if recorded.size() >= Category.size():
		prestige_level += 1
		recorded.clear()
		prestige_triggered.emit(prestige_level)
	return gold


## 프레스티지 배율 적용 전 기본 보상. 족보 불성립 시 0.
static func score_base(category: Category, values: Array[int], round_number: int) -> int:
	var digits: Array[int] = to_digits(values)
	var counts: Array[int] = _count_digits(digits)
	var digit_sum: int = 0
	for d: int in digits:
		digit_sum += d
	match category:
		Category.ACES, Category.TWOS, Category.THREES, Category.FOURS, Category.FIVES:
			var face: int = int(category) + 1
			return counts[face] * face * GOLD_PER_PIP
		Category.FOUR_OF_A_KIND:
			return digit_sum * GOLD_PER_PIP + BONUS_FOUR_OF_A_KIND if counts.max() >= 4 else 0
		Category.FULL_HOUSE:
			return digit_sum * GOLD_PER_PIP + BONUS_FULL_HOUSE if _is_full_house(counts) else 0
		Category.SMALL_STRAIGHT:
			return digit_sum * GOLD_PER_PIP + BONUS_SMALL_STRAIGHT if _longest_run(counts) >= 4 else 0
		Category.LARGE_STRAIGHT:
			return digit_sum * GOLD_PER_PIP + BONUS_LARGE_STRAIGHT if _longest_run(counts) >= 5 else 0
		Category.YACHT:
			return YACHT_BASE + round_number * YACHT_PER_ROUND if counts.max() >= 5 else 0
	return 0


## 확정 소환값 → 1의 자리 배열
static func to_digits(values: Array[int]) -> Array[int]:
	var digits: Array[int] = []
	for v: int in values:
		digits.append(absi(v) % 10)
	return digits


func _apply_multiplier(base: int) -> int:
	var mult: int = get_reward_multiplier()
	if base > 0 and base > FixedNum.MAX / mult:
		return FixedNum.MAX
	return base * mult


static func _count_digits(digits: Array[int]) -> Array[int]:
	var counts: Array[int] = []
	counts.resize(10)
	counts.fill(0)
	for d: int in digits:
		counts[d] += 1
	return counts


## 정확히 3개 + 2개 (5개 동일은 풀하우스가 아님)
static func _is_full_house(counts: Array[int]) -> bool:
	var has_three: bool = false
	var has_two: bool = false
	for c: int in counts:
		if c == 3:
			has_three = true
		elif c == 2:
			has_two = true
	return has_three and has_two


## 0~9 범위에서 연속으로 존재하는 숫자의 최대 길이 (9→0 순환 없음)
static func _longest_run(counts: Array[int]) -> int:
	var best: int = 0
	var run: int = 0
	for d: int in range(10):
		if counts[d] > 0:
			run += 1
			best = maxi(best, run)
		else:
			run = 0
	return best
