class_name UnitData
extends Resource
## 병과 원본 데이터 (.tres). 수치는 "1명분" 기준이며 정예 압축 배수만큼 곱해진다.
## 거리 단위는 전투 논리 좌표(px), 시간은 시뮬레이션 초.

## 자동 배치 열: 탱커 전열 / 근거리 중열 / 원거리 후열
enum Role { TANK, MELEE, RANGED }
enum DamageType { PHYSICAL, MAGICAL }

@export var id: StringName = &""
@export var display_name: String = ""
@export var role: Role = Role.MELEE
@export var color: Color = Color.WHITE

@export_group("능력치 (1명분)")
@export var max_hp: float = 100.0
@export var attack: float = 10.0
## 공격 간격(초). 공속 1.6회/초 → 0.625
@export var attack_interval: float = 1.0
@export var attack_range: float = 16.0
@export var move_speed: float = 60.0
@export var damage_type: DamageType = DamageType.PHYSICAL
## 받는 피해 감소율 (0.3 = 30% 감소)
@export_range(0.0, 0.75) var damage_reduction: float = 0.0

@export_group("특수")
## 광역 피해 반경 (0이면 단일 대상)
@export var splash_radius: float = 0.0
## 초당 회복량 (가장 체력 비율이 낮은 주변 아군 1명)
@export var heal_per_second: float = 0.0
## 회복·오라 반경
@export var support_radius: float = 0.0
@export var aura_attack_bonus: float = 0.0
@export var aura_defense_bonus: float = 0.0
## 화면·충돌용 몸통 반지름 (티어 크기 배율 적용 전)
@export var body_radius: float = 5.0

@export_group("중첩 특수능력")
## 분기 기준 인원 (x = 1분기, y = 2분기). 0이면 해당 분기 없음.
@export var branch_thresholds: Vector2i = Vector2i(50, 150)
@export var branch_1: UnitBranch = null
@export var branch_2: UnitBranch = null


## 칸 누적 인원 → 분기 단계 (0 = 없음, 1, 2)
func get_branch_level(total_count: int) -> int:
	if branch_2 != null and branch_thresholds.y > 0 and total_count >= branch_thresholds.y:
		return 2
	if branch_1 != null and branch_thresholds.x > 0 and total_count >= branch_thresholds.x:
		return 1
	return 0


func get_active_branches(total_count: int) -> Array[UnitBranch]:
	var out: Array[UnitBranch] = []
	var level: int = get_branch_level(total_count)
	if level >= 1:
		out.append(branch_1)
	if level >= 2:
		out.append(branch_2)
	return out
