class_name UserItemData
extends Resource
## 유저 아이템 원본 데이터 (04 문서 UserItemData). 하위 클래스가 필요한 훅만 덮어쓴다 (if item_id 분기 금지).
## 가변 상태(저금통 적립금, 지정 눈금, 쿨타임 등)는 ItemInstance.state에 저장한다 (.tres 오염 금지).
## 실행 순서는 priority 오름차순 (값 덮어쓰기 10 → 추가 연산 20 → 보너스 30 → 최종 보정 50~).

enum Rank { C, B, A, S }
## 구매 시 대상 지정
enum Target { NONE, DICE }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rank: Rank = Rank.B
@export var priority: int = 50
@export var target: Target = Target.NONE
## 아이콘 글자
@export var icon_text: String = ""
## 같은 아이템을 여러 개 가질 수 있는가 (효과 중첩)
@export var stackable: bool = true
@export var min_unlock_round: int = 1


## 획득 순간 1회 (지정 눈금 추첨, 고리대금 지급 등). 화면 문구 반환.
func on_acquire(_item: ItemInstance, _session: GameSession) -> String:
	return ""


## 대상 주사위에 쓸 수 있는가 (조각칼: 슬롯이 5칸 미만)
func can_apply_to(_dice: DiceInstance) -> bool:
	return true


## 대상 주사위에 적용 (구매 시 1회). 영구 효과는 주사위 runtime_state에 남긴다.
func apply_to_dice(_dice: DiceInstance, _item: ItemInstance) -> void:
	pass


## 적용 후 아이템이 사라지는가 (조각칼·핸드드릴처럼 쓰고 없어지는 것)
func is_consumed_on_apply() -> bool:
	return target == Target.DICE


## 원시 눈금 트리거 (인첸트 연산 전)
func on_raw_trigger(_ctx: RollContext, _item: ItemInstance, _dice: DiceInstance) -> void:
	pass


## 성질까지 끝난 최종값 보정
func on_final(_ctx: RollContext, _item: ItemInstance, _dice: DiceInstance) -> void:
	pass


## 재굴림 횟수 보너스
func get_reroll_bonus(_item: ItemInstance) -> int:
	return 0


## 얏츠판 족보 위조
func enables_forgery() -> bool:
	return false


## 얏츠판 기록 직후 (주사위 복제 거울: 추가 소환)
func on_record(_item: ItemInstance, _session: GameSession) -> String:
	return ""


## 전투 직전 아군 스폰 데이터 수정 (병영 복사기)
func modify_packets(_item: ItemInstance, _packets: Array[SpawnPacket]) -> void:
	pass


## 전투 정산 후 (소비칸 보험)
func on_settle(_item: ItemInstance, _session: GameSession, _result: BattleResult, _summary: Dictionary) -> String:
	return ""


## 라운드 종료 (저금통 적립, 쿨타임)
func on_round_end(_item: ItemInstance, _session: GameSession) -> void:
	pass


## 준비 단계 수동 사용 (저금통 깨기)
func can_activate(_item: ItemInstance) -> bool:
	return false


func get_activate_label() -> String:
	return "사용"


## 사용. 반환: 화면 문구. 사용 후 아이템 제거 여부는 is_consumed_on_activate.
func activate(_item: ItemInstance, _session: GameSession) -> String:
	return ""


func is_consumed_on_activate() -> bool:
	return true


## 목록에 보일 이름 (지정 눈금 등 상태 포함)
func get_label(_item: ItemInstance) -> String:
	return display_name


func get_state_text(_item: ItemInstance) -> String:
	return ""


## 정예 압축 규칙 변경 (유압 압축기) { "threshold": int, "bonus": float }
func get_compression(_item: ItemInstance) -> Dictionary:
	return {}


## 첫 굴림 뒤에도 주사위 교체 허용 (무단 침입 통행증)
func allows_rolling_swap(_item: ItemInstance) -> bool:
	return false


## 사용 시 고를 선택지 [{ "value", "label" }] (수정 테이프: 지울 얏츠판 칸). 비어 있으면 바로 사용.
func get_choices(_item: ItemInstance, _session: GameSession) -> Array[Dictionary]:
	return []


## 대상 주사위에 적용할 때 단계별 선택지 (사포와펜: 지울 면 → 새길 숫자). picks = 지금까지 고른 값. 비면 선택 끝.
func get_dice_choices(_dice: DiceInstance, _picks: Array) -> Array[Dictionary]:
	return []


## 선택지를 고른 사용 (기본: 선택 없이 activate)
func activate_choice(item: ItemInstance, session: GameSession, _value: Variant) -> String:
	return activate(item, session)
