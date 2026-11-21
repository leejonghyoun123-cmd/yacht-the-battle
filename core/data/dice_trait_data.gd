class_name DiceTraitData
extends Resource
## 주사위 성질 원본 데이터 (.tres, 실행 중 수정 금지). 03 문서 DiceTraitData.
## 주사위 1개에 성질 1개. 성질마다 하위 클래스가 필요한 훅만 덮어쓴다 (if trait_id 분기 금지).
## 가변 상태(포커 수트 등)는 DiceInstance.runtime_state에 저장한다.

## 상점 등급 (가격은 GameBalance.TRAIT_PRICE_BY_RANK)
enum Rank { C, B, A, S }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rank: Rank = Rank.B
## 주사위 아이콘에 붙는 짧은 표시
@export var badge: String = ""
## 등장 라운드
@export var min_unlock_round: int = 1


## 이 주사위에 붙일 수 있는가 (기본: 성질이 없는 주사위)
func can_attach_to(dice: DiceInstance) -> bool:
	return dice != null and dice.trait_data == null


## 붙이는 순간 1회 (수트 추첨 등). rng는 주입된 결정론 RNG만 사용.
func on_attach(_dice: DiceInstance, _rng: RandomNumberGenerator) -> void:
	pass


## 굴리기 전 기본 면 변형 (인첸트 면 변형보다 먼저)
func modify_base_faces(faces: Array[int], _dice: DiceInstance) -> Array[int]:
	return faces


## 원시 눈금에 따라 추가로 배치할 수 있게 되는 병과 (포커: A → 거인, K → 킹)
func get_unlocked_units(_raw_roll: int, _dice: DiceInstance) -> Array[StringName]:
	return []


## 화면 표시용 눈금 글자 (포커: 1 → A, 13 → K)
func face_label(value: int) -> String:
	return str(value)


func get_badge_text(_dice: DiceInstance) -> String:
	return badge


## 붙일 수 있는 주사위 조건 (상점 안내 문구)
func get_requirement_text() -> String:
	return "성질이 없는 주사위"
