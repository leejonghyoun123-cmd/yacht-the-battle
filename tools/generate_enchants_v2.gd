extends SceneTree
## 인첸트 확장분 .tres 생성 (02 문서 그룹 1·2·3·6 중 사양이 명확한 것). 이미 있는 파일은 덮어쓰지 않는다.
## 실행: godot --headless --path <프로젝트> --script res://tools/generate_enchants_v2.gd

const DIR: String = "res://data/enchants/"


func _initialize() -> void:
	_make(RemoveUpperHalfEnchant.new(), &"remove_upper_half", "상위 절반 면 삭제", "굴리기 전, 최댓값의 절반을 넘는 면을 삭제한다.")
	var top: KeepExtremeFacesEnchant = KeepExtremeFacesEnchant.new()
	top.keep_top = true
	_make(top, &"keep_top_faces", "최상위 면 남기기", "굴리기 전, 가장 큰 면 2개만 남기고 전부 삭제한다.")
	var bottom: KeepExtremeFacesEnchant = KeepExtremeFacesEnchant.new()
	bottom.keep_top = false
	_make(bottom, &"keep_bottom_faces", "최하위 면 남기기", "굴리기 전, 가장 작은 면 2개만 남기고 전부 삭제한다.")
	_make(SquareTemptationEnchant.new(), &"square_temptation", "제곱의 유혹", "현재 값이 10 이하일 때만 제곱한다. 11 이상이면 발동하지 않는다.")
	_make(ReverseDigitsEnchant.new(), &"reverse_digits", "숫자 뒤집기", "현재 값의 자릿수를 좌우로 뒤집는다. (19 → 91, 100 → 1)")
	_make(CeilToTenEnchant.new(), &"ceil_to_ten", "10의 자리 올림", "현재 값을 가장 가까운 10의 배수로 올린다. (11 → 20)")
	_make(AmplifyNextEnchant.new(), &"amplify_next", "증폭 코어", "바로 다음 슬롯의 합연산·곱연산 수치를 1.5배 강화한다.")
	_make(ThresholdSwitchEnchant.new(), &"threshold_switch", "최댓값 절단기", "현재 값이 50 이하면 +20, 50을 넘으면 ×1.5.")
	_make(OddZealotEnchant.new(), &"odd_zealot", "홀수 광신도", "현재 값이 홀수면 ×2.5, 짝수면 +1.")
	_make(EvenNobleEnchant.new(), &"even_noble", "짝수 귀족", "현재 값이 짝수면 ×2.5, 홀수면 변화 없음.")
	_make(LuckySevenEnchant.new(), &"lucky_seven", "럭키 세븐", "현재 값의 1의 자리가 7이면 ×4.")
	_make(InvertFacesEnchant.new(), &"invert_faces", "눈금 반전", "굴리기 전, 모든 면을 (최댓값+1) - X로 뒤집는다.")
	var no_even: ParityFilterEnchant = ParityFilterEnchant.new()
	no_even.mode = ParityFilterEnchant.FilterMode.REMOVE_EVEN
	_make(no_even, &"parity_odd_only", "홀짝 필터 (홀수만)", "굴리기 전, 짝수 면을 전부 삭제한다.")
	var no_odd: ParityFilterEnchant = ParityFilterEnchant.new()
	no_odd.mode = ParityFilterEnchant.FilterMode.REMOVE_ODD
	_make(no_odd, &"parity_even_only", "홀짝 필터 (짝수만)", "굴리기 전, 홀수 면을 전부 삭제한다.")
	_make(FakeMaxFaceEnchant.new(), &"fake_max_face", "가짜 최댓값", "굴리기 전, 가장 낮은 면 1개를 최댓값으로 바꾼다.")
	quit(0)


func _make(e: EnchantData, p_id: StringName, p_name: String, desc: String) -> void:
	e.id = p_id
	e.display_name = p_name
	e.description = desc
	var path: String = DIR + String(p_id) + ".tres"
	if ResourceLoader.exists(path):
		print("건너뜀 (이미 존재): ", path)
		return
	var err: Error = ResourceSaver.save(e, path)
	print("생성: " if err == OK else "실패(%d): " % err, path)
