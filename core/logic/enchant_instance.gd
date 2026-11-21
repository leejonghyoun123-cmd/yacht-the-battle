class_name EnchantInstance
extends RefCounted
## 주사위 슬롯에 실제로 장착되는 인첸트 객체.
## data(.tres 원본)는 공유·불변이고, 가변 상태는 runtime_state에만 저장한다.

var data: EnchantData
var runtime_state: Dictionary = {}


func _init(p_data: EnchantData) -> void:
	data = p_data
	runtime_state = p_data.create_initial_state() if p_data != null else {}


func get_display_name() -> String:
	return data.display_name if data != null else "(빈 슬롯)"


## 네트워크/세이브용 직렬화 (Resource 객체 대신 ID + 원시 타입만)
func to_dict() -> Dictionary:
	return {
		"id": String(data.id),
		"state": runtime_state.duplicate(true),
	}
