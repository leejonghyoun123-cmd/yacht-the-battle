class_name ShopCatalog
extends RefCounted
## 상점에 나올 수 있는 데이터 목록과 가격 계산.
## 새 인첸트·주사위를 추가하면 여기 목록에만 넣으면 된다.

const ENCHANT_PATHS: Array[String] = [
	"res://data/enchants/add_common.tres",
	"res://data/enchants/add_uncommon.tres",
	"res://data/enchants/add_rare.tres",
	"res://data/enchants/mul_common.tres",
	"res://data/enchants/mul_uncommon.tres",
	"res://data/enchants/mul_rare.tres",
	"res://data/enchants/sub_from_100.tres",
	"res://data/enchants/remove_lower_half.tres",
	"res://data/enchants/echo_slot.tres",
	# 확장분 (02 문서)
	"res://data/enchants/remove_upper_half.tres",
	"res://data/enchants/keep_top_faces.tres",
	"res://data/enchants/keep_bottom_faces.tres",
	"res://data/enchants/square_temptation.tres",
	"res://data/enchants/reverse_digits.tres",
	"res://data/enchants/ceil_to_ten.tres",
	"res://data/enchants/amplify_next.tres",
	"res://data/enchants/threshold_switch.tres",
	"res://data/enchants/odd_zealot.tres",
	"res://data/enchants/even_noble.tres",
	"res://data/enchants/lucky_seven.tres",
	"res://data/enchants/invert_faces.tres",
	"res://data/enchants/parity_odd_only.tres",
	"res://data/enchants/parity_even_only.tres",
	"res://data/enchants/fake_max_face.tres",
]
## 상점 성질 변환 칸에 나올 수 있는 성질
const TRAIT_PATHS: Array[String] = [
	"res://data/traits/poker.tres",
]
const DICE_DIR: String = "res://data/dice/"


static func load_dice(id: StringName) -> DiceData:
	return load(DICE_DIR + String(id) + ".tres") as DiceData


static func enchant_price(data: EnchantData) -> int:
	return GameBalance.ENCHANT_PRICE_BY_RARITY[clampi(int(data.rarity), 0, GameBalance.ENCHANT_PRICE_BY_RARITY.size() - 1)]


static func dice_price(data: DiceData) -> int:
	return int(GameBalance.DICE_PRICES.get(data.id, 100))


static func sell_value(price: int) -> int:
	return int(floorf(float(price) * GameBalance.SELL_RATIO))


## 주사위 판매가 = 주사위 + 끼워진 인첸트 판매가 합산
static func dice_sell_value(dice: DiceInstance) -> int:
	var total: int = sell_value(dice_price(dice.data))
	for inst: EnchantInstance in dice.get_enchants():
		total += sell_value(enchant_price(inst.data))
	if dice.trait_data != null:
		total += sell_value(trait_price(dice.trait_data))
	return total


## 해당 라운드에 상점에 나올 수 있는 인첸트 (해금 라운드 필터)
static func enchant_pool(round_number: int) -> Array[EnchantData]:
	var pool: Array[EnchantData] = []
	for path: String in ENCHANT_PATHS:
		var data: EnchantData = load(path) as EnchantData
		if data != null and data.min_unlock_round <= round_number:
			pool.append(data)
	return pool


## 가중치 랜덤 (결정론적 RNG)
static func pick_weighted(keys: Array, weights: Array, rng: RandomNumberGenerator) -> Variant:
	var total: int = 0
	for w: int in weights:
		total += w
	var roll: int = rng.randi_range(1, maxi(total, 1))
	for i: int in range(keys.size()):
		roll -= weights[i]
		if roll <= 0:
			return keys[i]
	return keys[keys.size() - 1]


static func trait_price(data: DiceTraitData) -> int:
	return GameBalance.TRAIT_PRICE_BY_RANK[clampi(int(data.rank), 0, GameBalance.TRAIT_PRICE_BY_RANK.size() - 1)]


static func trait_pool(round_number: int) -> Array[DiceTraitData]:
	var pool: Array[DiceTraitData] = []
	for path: String in TRAIT_PATHS:
		var data: DiceTraitData = load(path) as DiceTraitData
		if data != null and data.min_unlock_round <= round_number:
			pool.append(data)
	return pool
