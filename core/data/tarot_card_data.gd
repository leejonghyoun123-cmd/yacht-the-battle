class_name TarotCardData
extends Resource
## 타로카드 원본 데이터 (05 문서). 준비 단계에 예약·사용·칸 지정하고, 전투 중에는 자동 발동한다.
##   RESERVE  : 예약 소모품 (최대 2장 예약, 전투 1회 발동 후 소모)
##   WALL     : 즉시 사용, 런 끝까지 유지 (더 타워 포탑, 저스티스 실드)
##   CELL     : 내 배치 칸 1개를 지정해 그 자리에 영구 귀속 (칸 유닛 전원 버프)
##   INTERFERE: 상대 간섭·2인 전용
## 전투 효과는 하위 클래스가 on_battle_start / on_battle_step만 덮어쓴다 (card_id 분기 금지).
## 시간은 반드시 시뮬레이션 경과 시간(elapsed)으로만 판단한다 (타이머·await 금지 → 배속·스킵 안전).

enum Category { RESERVE, WALL, CELL, INTERFERE }
enum ModeRestriction { ALL, PVP_ONLY }
enum Rank { C, B, A, S }

@export var id: StringName = &""
@export var display_name: String = ""
## 메이저 아르카나 번호 (0 더 풀 ~ 21 더 월드)
@export var numeral: int = 0
@export_multiline var description: String = ""
@export var rank: Rank = Rank.B
@export var category: Category = Category.CELL
@export var mode_restriction: ModeRestriction = ModeRestriction.ALL
## CELL: 칸 유닛에 붙는 보정
@export var cell_modifier: StatModifier = null
## CELL: 지정할 칸 수 (더 러버 = 2칸 연결)
@export var cells_required: int = 1
@export var min_unlock_round: int = 1


## 전투 시작(호각) 순간 1회. state: 카드별 전투 중 상태 저장용
func on_battle_start(_sim: BattleSimulation, _team: int, _state: Dictionary) -> void:
	pass


## 교전 중 매 스텝. elapsed: 교전 시작 후 경과 시간
func on_battle_step(_sim: BattleSimulation, _team: int, _state: Dictionary, _elapsed: float, _dt: float) -> void:
	pass


func has_battle_effect() -> bool:
	return category == Category.RESERVE or category == Category.WALL


static func roman(n: int) -> String:
	var numerals: Array[String] = ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
		"XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI"]
	return numerals[clampi(n, 0, numerals.size() - 1)]
