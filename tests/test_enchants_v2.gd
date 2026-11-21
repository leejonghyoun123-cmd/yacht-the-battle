extends SceneTree
## 확장 인첸트 검증 (02 문서 사양)
## 실행: godot --headless --path <프로젝트> --script res://tests/test_enchants_v2.gd

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	print("===== 확장 인첸트 테스트 =====")
	_eq(_faces(["remove_upper_half"]), [1, 2, 3] as Array[int], "상위 절반 삭제: 6면 → [1,2,3]")
	_eq(_faces(["keep_top_faces"]), [6, 5] as Array[int], "최상위 면 남기기: [6,5]")
	_eq(_faces(["keep_bottom_faces"]), [1, 2] as Array[int], "최하위 면 남기기: [1,2]")
	_eq(_faces(["invert_faces"]), [6, 5, 4, 3, 2, 1] as Array[int], "눈금 반전")
	_eq(_faces(["parity_odd_only"]), [1, 3, 5] as Array[int], "홀짝 필터(홀수만)")
	_eq(_faces(["parity_even_only"]), [2, 4, 6] as Array[int], "홀짝 필터(짝수만)")
	_eq(_faces(["fake_max_face"]), [6, 2, 3, 4, 5, 6] as Array[int], "가짜 최댓값: 1 → 6")
	_eq(_faces(["parity_odd_only", "parity_even_only"]), [1, 3, 5] as Array[int], "홀짝 필터 둘 다: 0면이 되는 쪽은 건너뜀")

	_eq(_run(["square_temptation"], 6), 36, "제곱의 유혹: 6 → 36")
	_eq(_run(["add_rare", "square_temptation"], 6), 21, "제곱의 유혹: 21은 10 초과 → 미발동")
	_eq(_run(["add_common", "reverse_digits"], 16), 91, "숫자 뒤집기: 19 → 91")
	_eq(_run(["ceil_to_ten"], 11), 20, "10의 자리 올림: 11 → 20")
	_eq(_run(["ceil_to_ten"], 20), 20, "10의 자리 올림: 20 → 20")
	_eq(_run(["amplify_next", "add_common"], 4), 9, "증폭 코어 → +3이 +4.5: 4 → 8.5 → 9")
	_eq(_run(["amplify_next", "add_common", "add_common"], 4), 12, "증폭은 다음 1개 슬롯만 (4+4.5+3=11.5 → 12)")
	_eq(_run(["threshold_switch"], 30), 50, "최댓값 절단기: 30 → +20")
	_eq(_run(["threshold_switch"], 60), 90, "최댓값 절단기: 60 → ×1.5")
	_eq(_run(["odd_zealot"], 5), 13, "홀수 광신도: 5 ×2.5 = 12.5 → 13")
	_eq(_run(["odd_zealot"], 4), 5, "홀수 광신도: 짝수 +1")
	_eq(_run(["even_noble"], 4), 10, "짝수 귀족: 4 ×2.5")
	_eq(_run(["even_noble"], 5), 5, "짝수 귀족: 홀수 변화 없음")
	_eq(_run(["lucky_seven"], 17), 68, "럭키 세븐: 17 ×4")
	_eq(_run(["lucky_seven"], 16), 16, "럭키 세븐: 7 아니면 그대로")
	var pool: Array[EnchantData] = ShopCatalog.enchant_pool(10)
	_check(pool.size() == ShopCatalog.ENCHANT_PATHS.size(), "상점 풀에 전부 등록 (%d종)" % pool.size())
	print("===== 결과: 통과 %d / 실패 %d =====" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func _dice(ids: Array) -> DiceInstance:
	var d: DiceInstance = DiceInstance.new(load("res://data/dice/d6.tres"))
	d.unlock_slots(5)
	var i: int = 0
	for id: String in ids:
		d.equip(EnchantInstance.new(load("res://data/enchants/%s.tres" % id)), i)
		i += 1
	return d


func _faces(ids: Array) -> Array[int]:
	return _dice(ids).get_modified_faces()


func _run(ids: Array, raw: int) -> int:
	var ctx: RollContext = RollContext.new(null, 1)
	var d: DiceInstance = _dice(ids)
	# 굴림 범위 밖 숫자(16·17·20 등)도 연산만 검증
	d.run_pipeline(ctx, raw)
	return ctx.get_summon_value()


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		print("  PASS  ", label)
	else:
		_fail_count += 1
		print("  FAIL  ", label, ("  → " + detail) if detail != "" else "")


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, label, "기대 %s, 실제 %s" % [str(expected), str(actual)])
