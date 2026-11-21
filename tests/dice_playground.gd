extends Node
## Step 1 로직 확인용 놀이터 (화면 UI 없음, 결과는 에디터 하단 [출력] 패널에 표시).
## 실행할 때마다 다른 시드로 주사위 5개를 굴리고, 재굴림 2회 후 얏츠판 예상 보상을 보여준다.
## 인스펙터에서 시드·라운드를 바꿔 같은 결과를 재현할 수 있다.

## 0이면 매번 무작위 시드
@export var fixed_seed: int = 0
@export var round_number: int = 1

const ENCHANT_PATHS: Array[String] = [
	"res://data/enchants/add_common.tres",
	"res://data/enchants/mul_uncommon.tres",
	"res://data/enchants/echo_slot.tres",
	"res://data/enchants/remove_lower_half.tres",
	"res://data/enchants/mul_common.tres",
]


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if fixed_seed != 0:
		rng.seed = fixed_seed
	else:
		rng.randomize()
	print("\n========== 주사위 놀이터 (시드 %d, %dR) ==========" % [rng.seed, round_number])

	var dice: Array[DiceInstance] = _build_sample_dice()
	for i: int in range(dice.size()):
		print("주사위%d 장착: %s" % [i + 1, _enchant_names(dice[i])])

	var results: Array[DiceRollResult] = DiceRollResolver.resolve(dice, rng, round_number)
	_print_results("첫 굴림", results)

	# 재굴림 2회: 소환값이 가장 낮은 주사위 2개만 다시 굴린다 (나머지 고정)
	for reroll: int in range(2):
		var held: Array[bool] = _hold_all_but_lowest(results, 2)
		results = DiceRollResolver.resolve(dice, rng, round_number, held, results)
		_print_results("재굴림 %d (낮은 2개만)" % (reroll + 1), results)

	var values: Array[int] = DiceRollResolver.to_summon_values(results)
	var board: YachtBoard = YachtBoard.new()
	print("\n최종 소환값: ", values, "  1의 자리: ", YachtBoard.to_digits(values))
	print("얏츠판 예상 보상:")
	var preview: Dictionary = board.preview(values, round_number)
	for category: int in preview.keys():
		print("  %-14s %s원" % [YachtBoard.CATEGORY_NAMES[category], NumberFormatter.format_num(preview[category])])
	var total: int = 0
	for v: int in values:
		total += v
	print("소환 총 인원: ", NumberFormatter.format_num(total), "명")


## 샘플 덱: 주사위마다 다른 인첸트 조합 (슬롯 순서 효과를 비교하기 쉽게)
func _build_sample_dice() -> Array[DiceInstance]:
	var d6: DiceData = load("res://data/dice/d6.tres")
	var d20: DiceData = load("res://data/dice/d6.tres")  # (20면 삭제 → 6면)
	var e: Array[EnchantData] = []
	for path: String in ENCHANT_PATHS:
		e.append(load(path))
	var layouts: Array = [
		[d6, []],                    # 기본 6면 (인첸트 없음)
		[d6, [e[0], e[1]]],          # +3 → ×2
		[d6, [e[1], e[0]]],          # ×2 → +3 (순서만 반대)
		[d6, [e[3], e[0], e[2]]],    # 하위 절반 삭제 → +3 → 메아리
		[d20, [e[4], e[2]]],         # 20면: ×1.5 → 메아리
	]
	var dice: Array[DiceInstance] = []
	for layout: Array in layouts:
		var d: DiceInstance = DiceInstance.new(layout[0])
		var slot_index: int = 0
		for data: EnchantData in layout[1]:
			d.equip(EnchantInstance.new(data), slot_index)
			slot_index += 1
		dice.append(d)
	return dice


func _enchant_names(d: DiceInstance) -> String:
	var names: PackedStringArray = []
	for inst: EnchantInstance in d.get_enchants():
		names.append(inst.get_display_name())
	return d.data.display_name + " | " + (" → ".join(names) if names.size() > 0 else "(없음)")


func _print_results(title: String, results: Array[DiceRollResult]) -> void:
	print("\n[%s]" % title)
	for r: DiceRollResult in results:
		print("  주사위%d: %s" % [r.dice_index + 1, r.describe()])


func _hold_all_but_lowest(results: Array[DiceRollResult], reroll_count: int) -> Array[bool]:
	var order: Array[int] = []
	for i: int in range(results.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return results[a].summon_value < results[b].summon_value)
	var held: Array[bool] = []
	held.resize(results.size())
	held.fill(true)
	for k: int in range(mini(reroll_count, order.size())):
		held[order[k]] = false
	return held
