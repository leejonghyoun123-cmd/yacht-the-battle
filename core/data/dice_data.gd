class_name DiceData
extends Resource
## 주사위 원본 데이터 (.tres, 실행 중 수정 금지)

@export var id: StringName = &""
@export var display_name: String = ""
## 기본 면 배열 (6면: [1,2,3,4,5,6])
@export var faces: Array[int] = []
## 기본 개방 인첸트 슬롯 수 (최대 5)
@export_range(0, 5) var base_slots: int = 3


## 1~n 면 주사위 데이터를 코드로 생성 (테스트·데이터 생성 도구용)
static func create_standard(p_id: StringName, p_name: String, face_count: int) -> DiceData:
	var d: DiceData = DiceData.new()
	d.id = p_id
	d.display_name = p_name
	var f: Array[int] = []
	for i: int in range(1, face_count + 1):
		f.append(i)
	d.faces = f
	return d
