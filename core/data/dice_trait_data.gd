class_name DiceTraitData
extends Resource
## 주사위 성질 원본 데이터 (.tres, 실행 중 수정 금지). 03 문서 DiceTraitData.
## 주사위 1개에 성질 1개. 성질마다 하위 클래스가 필요한 훅만 덮어쓴다 (if trait_id 분기 금지).
## 가변 상태(X병 스택, 조커 추첨 결과 등)는 DiceInstance.runtime_state에 저장한다.
##
## 훅 순서 (굴림 1회):
##   prepare_context → [면 변형 modify_base_faces] → 눈금 추첨 → override_raw → on_rolled(실제 굴림만)
##   → 파이프라인(아이템 → 인첸트) → on_post_pipeline → (얏츠판 기록 = 확정) on_confirm
##   → 라운드 종료 on_round_end

## 상점 등급 (가격은 GameBalance.TRAIT_PRICE_BY_RANK)
enum Rank { C, B, A, S }
## 5주사위 일괄 굴림 순서 (03 문서 3-Pass: 일반 → 자석 → 거울)
enum RollPass { NORMAL, MAGNET, MIRROR }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rank: Rank = Rank.B
## 주사위 아이콘에 붙는 짧은 표시
@export var badge: String = ""
## 주사위 아이콘 바탕색
@export var color: Color = Color("f4f1e8")
@export var roll_pass: RollPass = RollPass.NORMAL
## 등장 라운드
@export var min_unlock_round: int = 1


## 이 주사위에 붙일 수 있는가 (기본: 성질이 없는 주사위)
func can_attach_to(dice: DiceInstance) -> bool:
	return dice != null and dice.trait_data == null


## 붙일 수 있는 주사위 조건 (상점 안내 문구)
func get_requirement_text() -> String:
	return "성질이 없는 주사위"


## 붙이는 순간 1회 (수트 추첨 등). rng는 주입된 결정론 RNG만 사용.
func on_attach(_dice: DiceInstance, _rng: RandomNumberGenerator) -> void:
	pass


## 굴림·재연산 시작 전 (뼈주사위: 보스 기믹 면역)
func prepare_context(_ctx: RollContext, _dice: DiceInstance) -> void:
	pass


## 굴리기 전 기본 면 변형 (인첸트 면 변형보다 먼저)
func modify_base_faces(faces: Array[int], _dice: DiceInstance) -> Array[int]:
	return faces


## 추첨된 원시 눈금 대신 쓸 값 (X병: 누적 스택)
func override_raw(raw: int, _dice: DiceInstance) -> int:
	return raw


## 실제로 굴렸을 때만 (고정한 주사위의 재연산에서는 호출되지 않음). 조커 추첨 등.
func on_rolled(_ctx: RollContext, _dice: DiceInstance) -> void:
	pass


## 인첸트 연산이 끝난 뒤 [주사위 성질 반영] 단계 (피 ×2.5, 유리 ×3 등)
func on_post_pipeline(_ctx: RollContext, _dice: DiceInstance) -> void:
	pass


## 원시 눈금에 따라 추가로 배치할 수 있게 되는 병과 (예: 거인·킹 해금. 현재 쓰는 성질 없음)
func get_unlocked_units(_raw_roll: int, _dice: DiceInstance) -> Array[StringName]:
	return []


## 이 주사위로 소환한 칸에 붙는 스탯 보정 (뼈주사위)
func get_cell_modifiers(_raw_roll: int, _dice: DiceInstance) -> Array[StatModifier]:
	return []


## 중첩칸에 놓아도 이번 라운드 한정(소비칸 판정)인가 (과부하)
func forces_consumable() -> bool:
	return false


## 얏츠판 기록(= 배치 확정) 시 1회. 화면에 띄울 문구를 반환 ("" = 없음)
func on_confirm(_dice: DiceInstance, _result: DiceRollResult, _session: GameSession) -> String:
	return ""


## 라운드 정산 후. was_rolled: 이번 라운드에 출전해 굴렸는가. 파괴는 session.destroy_dice로만.
func on_round_end(_dice: DiceInstance, _was_rolled: bool, _session: GameSession) -> String:
	return ""


## 화면 표시용 눈금 글자 (성질이 눈금을 다르게 표기할 때)
func face_label(value: int) -> String:
	return str(value)


func get_badge_text(_dice: DiceInstance) -> String:
	return badge


## 상태 표시 (X병 누적 스택, 조커 결과 등)
func get_state_text(_dice: DiceInstance) -> String:
	return ""


## 성질 배율을 값에 곱한다 (12R 과세 대상인 인첸트 곱연산과 구분)
static func multiply(ctx: RollContext, factor: float, source: String) -> void:
	ctx.set_value(FixedNum.mul_float(ctx.value, factor), source, "×" + RollContext._factor_text(factor))


## 변환할 주사위가 하나도 없을 때 구매 거절 문구
func get_missing_text() -> String:
	return "성질이 없는 주사위가 있어야 구매할 수 있습니다"
