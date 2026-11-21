class_name BattleUnit
extends RefCounted
## 전투 중 개체 1개 (화면 노드가 아닌 순수 데이터). 화면은 이 값을 읽어 그리기만 한다.
## 능력치는 UnitData 원본을 복사한 뒤 정예 압축·중첩 분기를 반영한 "이 개체의 값"이다.

var id: int = 0
var team: int = 0
var cell_index: int = 0
var data: UnitData
## 이 개체 1개가 대표하는 환산 인원 (정예 압축 배수)
var ratio: float = 1.0
var tier: int = 1
var is_consumable: bool = false
## 중첩 분기 단계 (0 = 없음, 1, 2)
var branch_level: int = 0

var max_hp: float = 100.0
var hp: float = 100.0
var attack: float = 10.0
var radius: float = 5.0
var attack_interval: float = 1.0
var attack_range: float = 16.0
var move_speed: float = 60.0
var splash_radius: float = 0.0
var damage_reduction: float = 0.0
var reflect_ratio: float = 0.0
var heal_per_second: float = 0.0
var support_radius: float = 0.0
var aura_attack_bonus: float = 0.0
var aura_defense_bonus: float = 0.0

var pos: Vector2 = Vector2.ZERO
## 진열 위치 (배치판 칸 안의 대형 자리)
var home: Vector2 = Vector2.ZERO
## 진열 이동 경로: 0 = 연병장 문으로 몰려감, 1 = 문을 나와 진열 자리로
var deploy_stage: int = 0
var gate_waypoint: Vector2 = Vector2.ZERO
var alive: bool = true
var cooldown: float = 0.0
var heal_cooldown: float = 0.0
var retarget_timer: float = 0.0
var target: BattleUnit = null

## 힐러 오라 (매 재탐색 주기마다 갱신)
var aura_attack: float = 0.0
var aura_defense: float = 0.0

## 칸 보정·타로로 붙는 값
var mod_damage_taken: float = 1.0
var shield_ratio: float = 0.0
## 남은 개인 실드 (피해를 먼저 흡수)
var shield: float = 0.0
var regen_ratio: float = 0.0
## 더 러버 연결 회복 (오라 갱신 때 설정)
var link_regen: float = 0.0
var physical_mult: float = 1.0
var magical_mult: float = 1.0
var splash_damage_mult: float = 1.0
## 남은 피해 면역·타겟 불가 시간 (더 허밋)
var immune_time: float = 0.0
## 전투 타로(예약 카드)로 붙는 전역 배율 — 시뮬레이션 스케줄러가 바꾼다
var tarot_attack_mult: float = 1.0
var tarot_haste_mult: float = 1.0
var tarot_damage_taken_mult: float = 1.0
## 지속 화염 피해 (더 썬): 초당 피해, 남은 시간
var burn_per_second: float = 0.0
var burn_time: float = 0.0


func setup(p_id: int, p_team: int, packet_cell: int, p_data: UnitData, p_ratio: float, p_consumable: bool, total_count: int = 0, mods: Array[StatModifier] = [], stat_bonus: float = 0.0) -> void:
	id = p_id
	team = p_team
	cell_index = packet_cell
	data = p_data
	ratio = p_ratio
	is_consumable = p_consumable
	var mult: float = BattleRules.get_stat_multiplier(p_ratio, stat_bonus)
	max_hp = p_data.max_hp * mult
	attack = p_data.attack * mult
	attack_interval = p_data.attack_interval
	attack_range = p_data.attack_range
	move_speed = p_data.move_speed
	splash_radius = p_data.splash_radius
	damage_reduction = p_data.damage_reduction
	heal_per_second = p_data.heal_per_second * mult
	support_radius = p_data.support_radius
	aura_attack_bonus = p_data.aura_attack_bonus
	aura_defense_bonus = p_data.aura_defense_bonus
	tier = BattleRules.get_tier(p_ratio)
	radius = p_data.body_radius * BattleRules.get_tier_scale(tier)
	branch_level = p_data.get_branch_level(total_count)
	for b: UnitBranch in p_data.get_active_branches(total_count):
		_apply_branch(b)
	for m: StatModifier in mods:
		m.apply_to(self)
	hp = max_hp
	shield = max_hp * shield_ratio
	cooldown = attack_interval * 0.5


func _apply_branch(b: UnitBranch) -> void:
	max_hp *= b.hp_mult
	attack *= b.attack_mult
	attack_interval *= b.interval_mult
	move_speed *= b.move_speed_mult
	radius *= b.size_mult
	heal_per_second *= b.heal_mult
	support_radius *= b.support_radius_mult
	attack_range += b.range_add
	splash_radius += b.splash_add
	damage_reduction = minf(0.75, damage_reduction + b.damage_reduction_add)
	reflect_ratio += b.reflect_add
	aura_attack_bonus += b.aura_attack_add


## 실제 공격 간격 (타로 공속 배율 반영)
func get_attack_interval() -> float:
	return attack_interval / maxf(0.1, tarot_haste_mult)


func get_attack_damage() -> float:
	var type_mult: float = magical_mult if data.damage_type == UnitData.DamageType.MAGICAL else physical_mult
	return attack * (1.0 + aura_attack) * tarot_attack_mult * type_mult


## 받는 피해 배율 (방어 감소·힐러 오라·칸 보정·타로)
func get_damage_taken_mult() -> float:
	return maxf(BattleRules.MIN_DAMAGE_TAKEN, (1.0 - damage_reduction) * (1.0 - aura_defense) * mod_damage_taken * tarot_damage_taken_mult)


## 받는 피해 계산 후 적용. 실제 깎인 체력을 반환한다.
func take_damage(amount: float) -> float:
	if not alive or amount <= 0.0 or immune_time > 0.0:
		return 0.0
	var incoming: float = amount * get_damage_taken_mult()
	if shield > 0.0:
		var absorbed: float = minf(shield, incoming)
		shield -= absorbed
		incoming -= absorbed
		if incoming <= 0.0:
			return 0.0
	var dealt: float = minf(hp, incoming)
	hp -= dealt
	if hp <= 0.0:
		hp = 0.0
		alive = false
	return dealt


func heal(amount: float) -> void:
	if alive and amount > 0.0:
		hp = minf(max_hp, hp + amount)


## 현재 남은 환산 인원 (체력 비율 반영 없이 생존 개체 기준)
func get_equivalent() -> float:
	return ratio if alive else 0.0


## 고정 비율 피해 (타로 폭격 등): 받는 피해 배율·실드는 적용, 반사·분담은 없음
func take_true_damage(amount: float) -> float:
	return take_damage(amount)


## 타겟으로 지정할 수 있는가 (더 허밋 면역 중이면 불가)
func is_targetable() -> bool:
	return alive and immune_time <= 0.0
