extends SceneTree
## 데이터 리소스(.tres) 생성 도구.
## .tres 텍스트를 손으로 쓰지 않고 Godot의 ResourceSaver로 저장해 형식 오류를 막는다.
## 실행: godot --headless --path <프로젝트> --script res://tools/generate_data.gd
## 이미 있는 파일은 덮어쓰지 않는다 (에디터에서 조정한 수치 보호). 다시 만들려면 파일을 지우고 실행.

const DICE_DIR: String = "res://data/dice/"
const ENCHANT_DIR: String = "res://data/enchants/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DICE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ENCHANT_DIR))

	_save(DiceData.create_standard(&"d6", "6면 주사위", 6), DICE_DIR + "d6.tres")

	_save(_add(&"add_common", "합연산 +3", EnchantData.Rarity.COMMON, 3.0), ENCHANT_DIR + "add_common.tres")
	_save(_add(&"add_uncommon", "합연산 +7", EnchantData.Rarity.UNCOMMON, 7.0), ENCHANT_DIR + "add_uncommon.tres")
	_save(_add(&"add_rare", "합연산 +15", EnchantData.Rarity.RARE, 15.0), ENCHANT_DIR + "add_rare.tres")
	_save(_mul(&"mul_common", "곱연산 ×1.5", EnchantData.Rarity.COMMON, 1.5), ENCHANT_DIR + "mul_common.tres")
	_save(_mul(&"mul_uncommon", "곱연산 ×2", EnchantData.Rarity.UNCOMMON, 2.0), ENCHANT_DIR + "mul_uncommon.tres")
	_save(_mul(&"mul_rare", "곱연산 ×3", EnchantData.Rarity.RARE, 3.0), ENCHANT_DIR + "mul_rare.tres")

	var sub: SubFrom100Enchant = SubFrom100Enchant.new()
	sub.id = &"sub_from_100"
	sub.display_name = "100에서 마이너스"
	sub.description = "현재 값을 100 - X로 바꾼다."
	_save(sub, ENCHANT_DIR + "sub_from_100.tres")

	var lower: RemoveLowerHalfEnchant = RemoveLowerHalfEnchant.new()
	lower.id = &"remove_lower_half"
	lower.display_name = "하위 절반 면 삭제"
	lower.description = "굴리기 전, 최댓값의 절반 이하인 면을 삭제한다."
	lower.rarity = EnchantData.Rarity.UNCOMMON
	_save(lower, ENCHANT_DIR + "remove_lower_half.tres")

	var echo: EchoSlotEnchant = EchoSlotEnchant.new()
	echo.id = &"echo_slot"
	echo.display_name = "메아리"
	echo.description = "바로 이전 슬롯의 인첸트를 1회 더 발동한다."
	echo.rarity = EnchantData.Rarity.RARE
	_save(echo, ENCHANT_DIR + "echo_slot.tres")

	quit(0)


func _add(p_id: StringName, p_name: String, p_rarity: EnchantData.Rarity, p_amount: float) -> AddFlatEnchant:
	var e: AddFlatEnchant = AddFlatEnchant.new()
	e.id = p_id
	e.display_name = p_name
	e.description = "현재 값에 %s을 더한다." % str(p_amount)
	e.rarity = p_rarity
	e.amount = p_amount
	return e


func _mul(p_id: StringName, p_name: String, p_rarity: EnchantData.Rarity, p_factor: float) -> MultiplyEnchant:
	var e: MultiplyEnchant = MultiplyEnchant.new()
	e.id = p_id
	e.display_name = p_name
	e.description = "현재 값에 %s를 곱한다." % str(p_factor)
	e.rarity = p_rarity
	e.factor = p_factor
	return e


func _save(res: Resource, path: String) -> void:
	if ResourceLoader.exists(path):
		print("건너뜀 (이미 존재): ", path)
		return
	var err: Error = ResourceSaver.save(res, path)
	print("생성: " if err == OK else "실패(%d): " % err, path)
