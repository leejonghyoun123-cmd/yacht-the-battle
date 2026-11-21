class_name BattleUnit
extends RefCounted
## 전투 중 개체 1개 (화면 노드가 아닌 순수 데이터). 화면은 이 값을 읽어 그리기만 한다.
## 능력치는 UnitData 원본을 복사한 뒤 정예 압축·중첩 분기를 반영한 "이 개체의 값"이다.

var id: int = 0
var team: int = 0
var cell_index: int = 0
var data: UnitData
## 이 개체 1개가 대표하는 환산 인원 (정예 압축 배수, 거인은 합체 인원)
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
## 킹 장판 (킹 본인 값)
var king_attack_mult: float = 1.0
var king_damage_taken_mult: float = 1.0
var king_haste_mult: float = 1.0

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
## 킹 장판 안에 있을 때 받는 버프 (곱배수)
var buff_attack_mult: float = 1.0
var buff_damage_taken_mult: float = 1.0
var buff_haste_mult: float = 1.0
## 킹 본인: 피해를 나눠 받을 장판 안 아군 목록 (오라 갱신 때 채움)
var share_targets: Array[BattleUnit] = []


func setup(p_id: int, p_team: int, packet_cell: int, p_data: UnitData, p_ratio: float, p_consumable: bool, total_count: int = 0) -> void:
	id = p_id
	team = p_team
	cell_index = packet_cell
	data = p_data
	ratio = p_ratio
	is_consumable = p_consumable
	var mult: float = BattleRules.get_stat_multiplier(p_ratio)
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
	king_attack_mult = p_data.king_attack_mult
	king_damage_taken_mult = p_data.king_damage_taken_mult
	king_haste_mult = p_data.king_haste_mult
	tier = 1 if (p_data.is_giant or p_data.is_unique) else BattleRules.get_tier(p_ratio)
	radius = p_data.body_radius * BattleRules.get_tier_scale(tier)
	branch_level = p_data.get_branch_level(total_count)
	for b: UnitBranch in p_data.get_active_branches(total_count):
		_apply_branch(b)
	hp = max_hp
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
	king_attack_mult += b.king_attack_mult_add
	king_damage_taken_mult *= b.king_damage_taken_mult
	king_haste_mult += b.king_haste_add


## 실제 공격 간격 (킹 장판 공속 버프 반영)
func get_attack_interval() -> float:
	return attack_interval / maxf(0.1, buff_haste_mult)


func get_attack_damage() -> float:
	return attack * (1.0 + aura_attack) * buff_attack_mult


## 받는 피해 배율 (방어 감소·힐러 오라·킹 장판)
func get_damage_taken_mult() -> float:
	return maxf(BattleRules.MIN_DAMAGE_TAKEN, (1.0 - damage_reduction) * (1.0 - aura_defense) * buff_damage_taken_mult)


## 받는 피해 계산 후 적용. 실제 깎인 체력을 반환한다.
func take_damage(amount: float) -> float:
	if not alive or amount <= 0.0:
		return 0.0
	var dealt: float = minf(hp, amount * get_damage_taken_mult())
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
