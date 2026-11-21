class_name GameBalance
extends RefCounted
## 임시 밸런스 수치 모음. 플레이하며 조정할 값은 모두 여기서만 바꾼다.

# --- 플레이어 ---
const START_GOLD: int = 300
const START_HP: int = 250
const MAX_HP_CAP: int = 750

# --- 라운드 경제 ---
## 다음 라운드로 넘어갈 때 지급하는 기본 수입
const ROUND_INCOME: int = 100
const WIN_BONUS: int = 50
## 소비칸 판매가 (환산 1명당)
const CONSUMABLE_SALE_PER_UNIT: int = 5
## 패배 시 적 생존 환산 1명당 피해
const DAMAGE_PER_ENEMY_UNIT: int = 1
## 중첩칸(고정 유닛) 판매가 (총 누적 인원 1명당). 소비칸(5원)보다 낮게 둔다:
## 중첩칸은 위험 없이 영구 누적되므로 같은 값이면 소비칸을 쓸 이유가 사라진다.
const STACK_SELL_PER_UNIT: int = 2

# --- 연승·연패 보상 (기획서 00 5장) ---
## [연속 횟수, 보상] — 횟수 이상이면 해당 보상 (위에서부터 큰 값 우선)
const WIN_STREAK_REWARDS: Array[Vector2i] = [Vector2i(5, 350), Vector2i(3, 200), Vector2i(2, 100)]
const LOSS_STREAK_REWARDS: Array[Vector2i] = [Vector2i(5, 200), Vector2i(4, 150), Vector2i(3, 100), Vector2i(2, 50)]
## 5연패 이상 시 무료 상점 리롤
const LOSS_STREAK_FREE_REROLL: int = 5

# --- 굴림 ---
## 첫 굴림 이후 가능한 재굴림 횟수 (기획서 "총 3회 재굴림")
const REROLLS_PER_ROUND: int = 3
## 아이템·보스 보정 후에도 최소 보장되는 재굴림 횟수
const MIN_REROLLS: int = 1

# --- 덱 ---
const ACTIVE_DICE_COUNT: int = 5
const MAX_RESERVE_SLOTS: int = 5
const START_RESERVE_SLOTS: int = 2

# --- 상점 (Step 2 이후 사용) ---
const ENCHANT_PRICE_BY_RARITY: Array[int] = [100, 200, 400, 800]
const SHOP_REROLL_COST: int = 50


## 라운드별 피격 데미지 상한 (0 = 상한 없음). 06 레벨 디자인 기준.
static func get_damage_cap(round_number: int) -> int:
	if round_number <= 6:
		return 75
	if round_number <= 12:
		return 100
	return 0
