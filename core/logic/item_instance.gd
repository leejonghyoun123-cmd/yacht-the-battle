class_name ItemInstance
extends RefCounted
## 보유 중인 유저 아이템 1개 (원본 데이터 + 가변 상태)

var data: UserItemData
var state: Dictionary = {}


func _init(p_data: UserItemData) -> void:
	data = p_data


func get_label() -> String:
	return data.get_label(self)
