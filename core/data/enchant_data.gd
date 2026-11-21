class_name EnchantData
extends Resource
## 주사위 슬롯 인첸트의 베이스 리소스 (.tres 원본, 실행 중 절대 수정하지 않음).
## 가변 상태(남은 횟수, 누적 스택 등)는 EnchantInstance.runtime_state에 둔다.
## 각 인첸트는 이 클래스를 상속해 apply_pre_roll / apply_post_roll만 재정의한다.

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }
enum Phase { PRE_ROLL, POST_ROLL }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var phase: Phase = Phase.POST_ROLL
## 곱연산 계열 여부 (12R 보스 과세 대상)
@export var is_multiplier: bool = false
## 복사 계열 여부 (메아리 등). 다른 복사 인첸트는 이 인첸트를 복사할 수 없다.
@export var is_copy_enchant: bool = false
## 상점 등장 최소 라운드
@export var min_unlock_round: int = 1


## 굴림 전: 면 배열을 변형해 반환한다. 원본 배열은 수정하지 말 것.
## 빈 배열을 반환해도 DiceInstance가 해당 필터를 건너뛰어 최소 1면을 보장한다.
func apply_pre_roll(faces: Array[int], _instance: EnchantInstance) -> Array[int]:
	return faces.duplicate()


## 굴림 후: ctx의 값을 변형한다.
func apply_post_roll(_ctx: RollContext, _instance: EnchantInstance) -> void:
	pass


## EnchantInstance 생성 시 초기 런타임 상태
func create_initial_state() -> Dictionary:
	return {}


## UI 슬롯 아이콘에 표시할 짧은 글자 (예: "+3", "×2"). 각 인첸트가 재정의한다.
func get_icon_text() -> String:
	return display_name.substr(0, 2)
