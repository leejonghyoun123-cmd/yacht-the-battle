class_name MultiplyTrait
extends DiceTraitData
## 최종 소환값에 배율을 곱하는 성질의 공통 부분 (피 ×2.5, 유리 ×3, 과부하 ×2, 황금 ×0.7)

@export var final_multiplier: float = 1.0


func on_post_pipeline(ctx: RollContext, _dice: DiceInstance) -> void:
	if not is_equal_approx(final_multiplier, 1.0):
		multiply(ctx, final_multiplier, display_name)
