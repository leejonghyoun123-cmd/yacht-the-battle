class_name EchoSlotEnchant
extends EnchantData
## 메아리: 바로 이전 슬롯의 인첸트를 1회 추가 발동한다 (복사 계열).
## 실제 복사 처리는 DiceInstance의 슬롯 루프가 담당한다 (재귀 깊이 1 강제).
## 직전 슬롯이 비어 있거나, 비활성화되었거나, 굴림 전 인첸트이거나, 복사 계열이면 미발동.


func _init() -> void:
	phase = Phase.POST_ROLL
	is_copy_enchant = true
