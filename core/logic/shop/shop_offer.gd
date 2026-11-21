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


## 아직 시스템이 없는 칸 (성질 변환·타로·유저 아이템) — 해당 단계에서 채운다
func is_locked() -> bool:
	return kind == Kind.TRAIT_LOCKED or kind == Kind.SPECIAL_LOCKED


func is_available() -> bool:
	return not sold and not is_locked()
