class_name BattleUnit
extends RefCounted
## 전투 중 개체 1개 (화면 노드가 아닌 순수 데이터). 화면은 이 값을 읽어 그리기만 한다.

var id: int = 0
var team: int = 0
var cell_index: int = 0
var data: UnitData
## 이 개체 1개가 대표하는 환산 인원 (정예 압축 배수, 거인은 합체 인원)
var ratio: float = 1.0
var tier: int = 1
var is_consumable: bool = false

var max_hp: float = 100.0
var hp: float = 100.0
var attack: float = 10.0
var radius: float = 5.0

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


func setup(p_id: int, p_team: int, packet_cell: int, p_data: UnitData, p_ratio: float, p_consumable: bool) -> void:
	id = p_id
	team = p_team
	cell_index = packet_cell
	data = p_data
	ratio = p_ratio
	is_consumable = p_consumable
	var mult: float = BattleRules.get_stat_multiplier(p_ratio)
	max_hp = p_data.max_hp * mult
	hp = max_hp
	attack = p_data.attack * mult
	tier = 1 if p_data.is_giant else BattleRules.get_tier(p_ratio)
	radius = p_data.body_radius * BattleRules.get_tier_scale(tier)
	cooldown = p_data.attack_interval * 0.5


## 받는 피해 계산 후 적용. 실제 깎인 체력을 반환한다.
func take_damage(amount: float) -> float:
	if not alive or amount <= 0.0:
		return 0.0
	var taken_mult: float = maxf(BattleRules.MIN_DAMAGE_TAKEN, (1.0 - data.damage_reduction) * (1.0 - aura_defense))
	var dealt: float = minf(hp, amount * taken_mult)
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
