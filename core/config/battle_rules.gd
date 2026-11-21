class_name BattleRules
extends RefCounted
## 전투·정예 압축 규칙의 단일 출처.
## 압축 임계값(50)을 다른 코드에 직접 쓰지 말고 반드시 여기서 읽는다 (유압 압축기 아이템 대비).

## 정예 압축 임계값 (유압 압축기 보유 시 25로 바뀔 수 있음)
static var compression_threshold: int = 50
## 압축 스탯 추가 보정 (유압 압축기: 1.15)
static var compression_stat_bonus: float = 1.0

## 압축 배수 티어 기준 (Tier 2 은색 / 3 금색 / 4 붉은색)
const TIER_THRESHOLDS: Array[float] = [2.0, 5.0, 15.0]
const TIER_SCALES: Array[float] = [1.0, 1.25, 1.5, 1.8]

# --- 시뮬레이션 시간 (모두 시뮬레이션 초 단위, 실제 시계와 무관) ---
const SIM_DT: float = 1.0 / 30.0
## 진열 완료 후 호각까지 대기
const WHISTLE_DELAY: float = 3.0
## 교전 제한 시간
const FIGHT_TIME_LIMIT: float = 60.0
## 달려나와 진열하는 데 허용하는 최대 시간 (넘으면 제자리로 즉시 정렬)
const DEPLOY_MAX_TIME: float = 8.0
## 목표 재탐색 주기 (유닛마다 시차를 두어 부하 분산)
const RETARGET_INTERVAL: float = 0.25
## 광역 피해 가장자리 배율 (캐논 너프: 밀집 대형 전체를 같은 피해로 쓸어 버리지 않게)
const SPLASH_EDGE_DAMAGE: float = 0.4
## 받는 피해 최소 배율 (피해 경감 합산 상한 75%)
const MIN_DAMAGE_TAKEN: float = 0.25

# --- 거인 합체 ---
const GIANT_ONE_MAX: int = 30
const GIANT_TWO_MAX: int = 100


static func get_compression_threshold() -> int:
	return compression_threshold


## 칸 총 인원 → { "spawn": 실제 스폰 수, "ratio": 1개체당 환산 인원 }
static func get_spawn_plan(total_count: int, is_giant: bool, is_unique: bool = false) -> Dictionary:
	if total_count <= 0:
		return { "spawn": 0, "ratio": 0.0 }
	# 킹: 칸 인원(=누적 K 수)과 상관없이 1명, 환산 1명
	if is_unique:
		return { "spawn": 1, "ratio": 1.0 }
	if is_giant:
		var giants: int = 1 if total_count <= GIANT_ONE_MAX else (2 if total_count <= GIANT_TWO_MAX else 3)
		return { "spawn": giants, "ratio": float(total_count) / float(giants) }
	var threshold: int = get_compression_threshold()
	if total_count <= threshold:
		return { "spawn": total_count, "ratio": 1.0 }
	return { "spawn": threshold, "ratio": float(total_count) / float(threshold) }


## 압축 배수 → 스탯 배율 (보정 아이템 포함)
static func get_stat_multiplier(ratio: float) -> float:
	if ratio > 1.0:
		return ratio * compression_stat_bonus
	return ratio


## 압축 배수 → 티어 (1~4). 거인은 합체이므로 호출하는 쪽에서 판단.
static func get_tier(ratio: float) -> int:
	var tier: int = 1
	for threshold: float in TIER_THRESHOLDS:
		if ratio >= threshold:
			tier += 1
	return tier


static func get_tier_scale(tier: int) -> float:
	return TIER_SCALES[clampi(tier - 1, 0, TIER_SCALES.size() - 1)]
