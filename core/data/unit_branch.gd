class_name UnitBranch
extends Resource
## 병과 분기 특수능력 (중첩 인원이 기준을 넘으면 그 칸 유닛 전원에게 적용).
## 1분기·2분기는 누적 적용된다 (2분기 도달 시 1분기 효과도 유지).
## 수치는 배율(×) 또는 더하기(+)로만 표현해 병과별 if문 없이 데이터로 처리한다.

@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("능력치 배율 (×)")
@export var hp_mult: float = 1.0
@export var attack_mult: float = 1.0
## 공격 간격 배율 (0.75 = 25% 빨라짐)
@export var interval_mult: float = 1.0
@export var move_speed_mult: float = 1.0
@export var size_mult: float = 1.0
@export var heal_mult: float = 1.0
@export var support_radius_mult: float = 1.0

@export_group("더하기 (+)")
@export var range_add: float = 0.0
## 광역 반경 추가 (0이던 병과도 광역 공격이 된다)
@export var splash_add: float = 0.0
@export_range(0.0, 0.5) var damage_reduction_add: float = 0.0
## 받은 근접·원거리 피해의 일부를 공격자에게 되돌림 (0.25 = 25%)
@export_range(0.0, 1.0) var reflect_add: float = 0.0
## 힐러형 오라: 범위 안 아군 공격력 +
@export var aura_attack_add: float = 0.0
