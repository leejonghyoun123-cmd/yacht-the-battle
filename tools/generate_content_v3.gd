extends SceneTree
## 남은 유저 아이템 4종 + 타로 5종 .tres 생성 (이미 있는 파일은 덮어쓰지 않음)
## 실행: godot --headless --path <프로젝트> --script res://tools/generate_content_v3.gd


func _initialize() -> void:
	var hyd: HydraulicItem = HydraulicItem.new()
	_item(hyd, &"hydraulic", "유압 압축기", "압축", 2, 50, "내 팀 정예 압축 기준 50 → 25명, 압축 스탯 ×1.15.", false)
	_item(TrespassItem.new(), &"trespass", "무단 침입 통행증", "출입", 1, 50, "라운드당 1회, 첫 굴림 뒤에도 출전 주사위 1개를 가방 주사위와 교체 (들어온 주사위는 바로 굴림).", false)
	_item(CorrectionTapeItem.new(), &"correction_tape", "수정 테이프", "지움", 1, 50, "1회용: 기록한 얏츠판 칸 1개를 미기록으로 되돌린다.")
	var sand: SandpaperItem = SandpaperItem.new()
	sand.target = UserItemData.Target.DICE
	_item(sand, &"sandpaper", "사포와펜", "사포", 1, 50, "고른 주사위의 숫자 1개를 지우고, 그 주사위의 다른 숫자 1개를 그 자리에 새긴다 (영구).")

	var lovers: TarotCardData = TarotCardData.new()
	lovers.cells_required = 2
	_tarot(lovers, &"lovers", 6, "더 러버", 1, TarotCardData.Category.CELL, TarotCardData.ModeRestriction.ALL,
		"[두 칸 연결] 한쪽 칸에 생존자가 있으면 다른 칸 유닛이 매초 최대 체력 3% 회복 (서로).")
	_tarot(TarotCardData.new(), &"judgement", 20, "저지먼트", 1, TarotCardData.Category.INTERFERE, TarotCardData.ModeRestriction.ALL,
		"[상대 칸 지정] 그 칸의 타로 영구 버프·연결을 모두 해제. (친선전 전용 — 1인용 적은 타로가 없음)")
	_tarot(TarotCardData.new(), &"devil", 15, "더 데빌", 1, TarotCardData.Category.INTERFERE, TarotCardData.ModeRestriction.PVP_ONLY,
		"[2인 전용] 나와 상대의 주사위 중 각자 무작위 1개 파괴 (5개 이하면 기본 6면으로 초기화).")
	_tarot(TarotCardData.new(), &"death", 13, "데스", 2, TarotCardData.Category.INTERFERE, TarotCardData.ModeRestriction.PVP_ONLY,
		"[2인 전용] 내 체력 X를 깎아 상대 본체에 상한 무시 고정 피해 X (자살 불가).")
	_tarot(TarotCardData.new(), &"temperance", 14, "템퍼런스", 1, TarotCardData.Category.INTERFERE, TarotCardData.ModeRestriction.PVP_ONLY,
		"[2인 전용] 이번 전투에 한해 내 칸 1개와 상대 칸 1개를 평균 상태로 맞춘다.")
	quit(0)


func _item(it: UserItemData, p_id: StringName, p_name: String, p_icon: String, p_rank: int, p_priority: int, desc: String, p_stackable: bool = true) -> void:
	it.id = p_id
	it.display_name = p_name
	it.icon_text = p_icon
	it.rank = p_rank as UserItemData.Rank
	it.priority = p_priority
	it.description = desc
	it.stackable = p_stackable
	_save(it, "res://data/items/%s.tres" % p_id)


func _tarot(t: TarotCardData, p_id: StringName, numeral: int, p_name: String, p_rank: int,
		category: TarotCardData.Category, mode: TarotCardData.ModeRestriction, desc: String) -> void:
	t.id = p_id
	t.numeral = numeral
	t.display_name = p_name
	t.rank = p_rank as TarotCardData.Rank
	t.category = category
	t.mode_restriction = mode
	t.description = desc
	_save(t, "res://data/tarots/%s.tres" % p_id)


func _save(r: Resource, path: String) -> void:
	if ResourceLoader.exists(path):
		print("건너뜀 (이미 존재): ", path)
		return
	var err: Error = ResourceSaver.save(r, path)
	print("생성: " if err == OK else "실패(%d): " % err, path)
