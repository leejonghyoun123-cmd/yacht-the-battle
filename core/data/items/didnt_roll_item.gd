class_name DidntRollItem
extends UserItemData
## 나 안굴렸는데?: 매 라운드 재굴림 횟수 영구 +1 (15R 보스 -1과 합산해도 최소 1회 보장 — RoundFlow)


func get_reroll_bonus(_item: ItemInstance) -> int:
	return 1
