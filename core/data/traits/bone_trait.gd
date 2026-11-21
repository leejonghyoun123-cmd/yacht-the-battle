class_name BoneTrait
extends DiceTraitData
## 뼈주사위: 보스 연산 기믹·저주 완전 무시 + 소환 유닛 최대 체력 +25%, 받는 피해 -15%

static var _mod: StatModifier = null


static func get_modifier() -> StatModifier:
	if _mod == null:
		_mod = StatModifier.make("뼈: 체력 +25%, 받는 피해 -15%", { "hp_mult": 1.25, "damage_taken_mult": 0.85 })
	return _mod


func prepare_context(ctx: RollContext, _dice: DiceInstance) -> void:
	ctx.immune_to_boss_gimmicks = true


func get_cell_modifiers(_raw_roll: int, _dice: DiceInstance) -> Array[StatModifier]:
	return [get_modifier()]
