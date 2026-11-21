class_name StreakState
extends RefCounted
## 연승·연패 기록과 보상 계산

var win_streak: int = 0
var loss_streak: int = 0


## 승리 기록 후 이번 연승 보상 반환
func record_win() -> int:
	win_streak += 1
	loss_streak = 0
	return _reward(win_streak, GameBalance.WIN_STREAK_REWARDS)


## 패배 기록 후 이번 연패 보상 반환
func record_loss() -> int:
	loss_streak += 1
	win_streak = 0
	return _reward(loss_streak, GameBalance.LOSS_STREAK_REWARDS)


func has_free_reroll() -> bool:
	return loss_streak >= GameBalance.LOSS_STREAK_FREE_REROLL


static func _reward(streak: int, table: Array[Vector2i]) -> int:
	for entry: Vector2i in table:
		if streak >= entry.x:
			return entry.y
	return 0
