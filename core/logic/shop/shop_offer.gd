class_name ShopOffer
extends RefCounted
## 상점 진열 상품 1칸

enum Kind { FOOD, WALL, DICE, TRAIT_LOCKED, BAG, SPECIAL_LOCKED, ENCHANT }

var kind: Kind = Kind.FOOD
var price: int = 0
var sold: bool = false
var title: String = ""
var description: String = ""
var dice_data: DiceData = null
var enchant_data: EnchantData = null
## 가방 등급 인덱스 (GameBalance.BAG_TIERS)
var bag_tier: int = -1
## 상시 상품(식량·성벽): 이번 라운드 구매 횟수. 살 때마다 가격이 오른다.
var base_price: int = 0
var purchase_count: int = 0


## 반복 구매 상품인가 (팔려도 사라지지 않고 가격만 오른다)
func is_repeatable() -> bool:
	return kind == Kind.FOOD or kind == Kind.WALL


## 아직 시스템이 없는 칸 (성질 변환·타로·유저 아이템) — 해당 단계에서 채운다
func is_locked() -> bool:
	return kind == Kind.TRAIT_LOCKED or kind == Kind.SPECIAL_LOCKED


func is_available() -> bool:
	return not sold and not is_locked()
