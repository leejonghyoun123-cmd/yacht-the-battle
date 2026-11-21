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
## 리롤 가격: 한 라운드 안에서 할수록 25 → 50 → 75원… (다음 라운드에 25원부터)
const SHOP_REROLL_BASE_COST: int = 25
const SHOP_REROLL_COST_STEP: int = 25
## 판매가 = 구매가 × 비율
const SELL_RATIO: float = 0.5

const FOOD_PRICE: int = 150
const FOOD_MAX_HP_BONUS: int = 50
const WALL_PRICE: int = 100
## 식량·성벽을 같은 라운드에 또 살 때마다 붙는 추가 가격 (라운드가 바뀌면 원래 가격)
const REPEAT_PURCHASE_STEP: int = 100
## 성벽증축 임시 실드 = 기본 + 라운드 × 증가량 (해당 라운드만)
const WALL_SHIELD_BASE: int = 20
const WALL_SHIELD_PER_ROUND: int = 10

## 다면 주사위 가격 (기본 6면은 판매가 계산용)
const DICE_PRICES: Dictionary = { &"d2": 150, &"d4": 100, &"d6": 60, &"d20": 300, &"d100": 700 }
## 상점 다면 주사위 등장 가중치
const DICE_SHOP_WEIGHTS: Dictionary = { &"d2": 30, &"d4": 30, &"d20": 30, &"d100": 10 }
## 인첸트 등급별 등장 가중치 (일반·고급·희귀·전설)
const ENCHANT_RARITY_WEIGHTS: Array[int] = [50, 30, 15, 5]

## 가방 등급: 예비 슬롯 수 (가방 없음 = START_RESERVE_SLOTS)
const BAG_TIERS: Array[Dictionary] = [
	{ "name": "작은 가방", "slots": 3, "price": 200 },
	{ "name": "중간 가방", "slots": 4, "price": 400 },
	{ "name": "큰 가방", "slots": 5, "price": 700 },
]

# --- 준비 시간 타이머 ---
const PREP_TIME: float = 90.0
const PREP_EXTENSION: float = 30.0


## 라운드별 피격 데미지 상한 (0 = 상한 없음). 06 레벨 디자인 기준.
static func get_damage_cap(round_number: int) -> int:
	if round_number <= 6:
		return 75
	if round_number <= 12:
		return 100
	return 0
