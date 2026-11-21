class_name GlassTrait
extends MultiplyTrait
## 유리주사위: 최종 소환값 ×3. 출전해 굴린 라운드가 끝나면 25% 확률로 파괴 (인첸트는 자동 회수)

@export var break_chance: float = 0.25


func on_round_end(dice: DiceInstance, was_rolled: bool, session: GameSession) -> String:
	if not was_rolled:
		return ""
	if session.rng.randf() < break_chance:
		session.destroy_dice(dice)
		return "유리주사위가 깨졌습니다!"
	return ""
