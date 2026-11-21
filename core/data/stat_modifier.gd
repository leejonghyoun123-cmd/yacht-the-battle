class_name StatModifier
extends Resource
## 칸 단위 스탯 보정 (포커 수트·로열, 뼈주사위, 타로 유닛칸 버프 등).
## 칸에 붙어 있으면 그 칸에서 소환되는 모든 유닛에 적용된다. 같은 보정(같은 리소스)은 한 칸에 한 번만.
## 배율(×)은 곱해지고, 받는 피해 배율은 BattleRules.MIN_DAMAGE_TAKEN(0.25) 아래로 내려가지 않는다.

@export var display_name: String = ""
@export var attack_mult: float = 1.0
@export var hp_mult: float = 1.0
## 공격 속도 배율 (1.3 = 30% 빨라짐)
@export var haste_mult: float = 1.0
@export var move_mult: float = 1.0
@export var size_mult: float = 1.0
## 받는 피해 배율 (0.75 = 25% 덜 받음)
@export var damage_taken_mult: float = 1.0
## 전투 시작 시 최대 체력 대비 개인 실드
@export var shield_ratio: float = 0.0
## 초당 최대 체력 대비 회복
@export var regen_ratio: float = 0.0
@export var physical_mult: float = 1.0
@export var magical_mult: float = 1.0
## 광역 공격 피해 배율
@export var splash_damage_mult: float = 1.0
## 전투 시작 후 피해 면역·타겟 불가 시간(초)
@export var immune_seconds: float = 0.0


func apply_to(u: BattleUnit) -> void:
	u.max_hp *= hp_mult
	u.attack *= attack_mult
	u.attack_interval /= maxf(0.1, haste_mult)
	u.move_speed *= move_mult
	u.radius *= size_mult
	u.mod_damage_taken *= damage_taken_mult
	u.shield_ratio += shield_ratio
	u.regen_ratio += regen_ratio
	u.physical_mult *= physical_mult
	u.magical_mult *= magical_mult
	u.splash_damage_mult *= splash_damage_mult
	u.immune_time = maxf(u.immune_time, immune_seconds)


static func make(p_name: String, values: Dictionary) -> StatModifier:
	var m: StatModifier = StatModifier.new()
	m.display_name = p_name
	for k: String in values.keys():
		m.set(k, values[k])
	return m
