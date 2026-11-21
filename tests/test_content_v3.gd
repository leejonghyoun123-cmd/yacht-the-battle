extends SceneTree
## 남은 아이템 4종(유압 압축기·무단 침입 통행증·수정 테이프·사포와펜) + 타로 5종(러버·저지먼트·데빌·데스·템퍼런스)
## 실행: godot --headless --path <프로젝트> --script res://tests/test_content_v3.gd

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	print("===== 남은 아이템·타로 테스트 =====")
	_test_hydraulic()
	_test_trespass()
	_test_correction_tape()
	_test_sandpaper()
	_test_lovers()
	_test_pvp()
	_test_pools()
	print("===== 결과: 통과 %d / 실패 %d =====" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func _item(id: String) -> UserItemData:
	return load("res://data/items/%s.tres" % id) as UserItemData


func _tarot(id: String) -> TarotCardData:
	return load("res://data/tarots/%s.tres" % id) as TarotCardData


func _packet(cell: int, id: StringName, count: int) -> SpawnPacket:
	var p: SpawnPacket = SpawnPacket.new()
	p.cell_index = cell
	p.unit_data = UnitCatalog.get_unit(id)
	p.total_count = count
	return p


func _test_hydraulic() -> void:
	var s: GameSession = GameSession.new(51)
	s.acquire_item(_item("hydraulic"))
	_eq(s.get_compression_threshold(), 25, "유압 압축기: 내 압축 기준 25")
	var sim: BattleSimulation = BattleSimulation.new()
	sim.team_compression[0] = s.inventory.get_compression()
	sim.setup([[_packet(4, &"sword", 100)], [_packet(4, &"sword", 100)]], 1)
	var mine: int = 0
	var theirs: int = 0
	var my_unit: BattleUnit = null
	for u: BattleUnit in sim.units:
		if u.team == 0:
			mine += 1
			my_unit = u
		else:
			theirs += 1
	_eq(mine, 25, "내 소드 100명 → 25개체 (배수 4)")
	_eq(theirs, 50, "적은 기본 50개체")
	_near(my_unit.attack, 10.0 * 4.0 * 1.15 * 1.3, "압축 스탯 ×1.15 추가 (+ 소드 50명 1분기 ×1.3)")
	sim.run_to_end()
	_eq(BattleRules.get_compression_threshold(), 50, "공용 기준은 그대로 50")


func _test_trespass() -> void:
	var s: GameSession = GameSession.new(52)
	var spare: DiceInstance = DiceInstance.new(load("res://data/dice/d20.tres"))
	s.deck.add_to_reserve(spare)
	s.go_to_rolling()
	s.flow.roll()
	_check(not s.can_trespass_swap(), "통행증 없으면 굴림 뒤 교체 불가")
	s.acquire_item(_item("trespass"))
	_check(s.can_trespass_swap(), "통행증: 굴림 뒤 교체 가능")
	var rerolls: int = s.flow.rerolls_left
	_check(s.trespass_swap(2, s.deck.reserve.find(spare)), "교체 성공")
	_check(s.deck.active[2] == spare, "출전 3번 = 가방에서 온 d20")
	_eq(s.flow.rerolls_left, rerolls, "재굴림 횟수는 그대로")
	_check(not s.deck.can_edit_dice(spare), "들어온 주사위도 이번 라운드 잠금")
	_check(not s.can_trespass_swap(), "라운드당 1회")
	_eq(s.flow.results.size(), 5, "결과 5개 유지")


func _test_correction_tape() -> void:
	var s: GameSession = GameSession.new(53)
	s.go_to_rolling()
	s.flow.roll()
	s.flow.record_yacht(YachtBoard.Category.CHOICE)
	s.acquire_item(_item("correction_tape"))
	var tape: ItemInstance = s.inventory.items[0]
	var choices: Array[Dictionary] = tape.data.get_choices(tape, s)
	_eq(choices.size(), 1, "지울 수 있는 기록 1칸")
	s.phase = GameSession.Phase.BARRACKS
	s.activate_item(tape, YachtBoard.Category.CHOICE)
	_check(not s.yacht.is_recorded(YachtBoard.Category.CHOICE), "수정 테이프: 초이스 기록 지움")
	_eq(s.inventory.items.size(), 0, "1회용이라 사라짐")


func _test_sandpaper() -> void:
	var s: GameSession = GameSession.new(54)
	var d: DiceInstance = s.deck.active[0]
	var data: UserItemData = _item("sandpaper")
	_eq(data.get_dice_choices(d, []).size(), 6, "1단계: 지울 숫자 6개")
	_eq(data.get_dice_choices(d, [1]).size(), 5, "2단계: 새길 숫자 5개 (지운 숫자 제외)")
	_eq(data.get_dice_choices(d, [1, 6]).size(), 0, "선택 끝")
	s.acquire_item(data, d, [1, 6])
	_eq(d.get_modified_faces(), [6, 2, 3, 4, 5, 6] as Array[int], "사포와펜: 1 지우고 6 새김")


func _test_lovers() -> void:
	var s: GameSession = GameSession.new(55)
	s.acquire_tarot(_tarot("lovers"))
	_check(s.use_tarot(_tarot("lovers"), 1) != "", "러버: 두 번째 칸 필요")
	_eq(s.use_tarot(_tarot("lovers"), 1, 4), "", "러버: 1번·4번 칸 연결")
	_eq(s.board.slot_links, [Vector2i(1, 4)] as Array[Vector2i], "연결 기록")
	var sim: BattleSimulation = BattleSimulation.new()
	sim.team_links[0] = s.board.slot_links.duplicate()
	sim.setup([[_packet(1, &"shield", 5), _packet(4, &"sword", 5), _packet(7, &"bow", 5)], [_packet(4, &"sword", 5)]], 2)
	sim._update_auras()
	var linked: int = 0
	var unlinked: int = 0
	for u: BattleUnit in sim.units:
		if u.team == 0 and u.link_regen > 0.0:
			if u.cell_index == 7:
				unlinked += 1
			else:
				linked += 1
	_eq(linked, 10, "연결된 두 칸 유닛 10명 회복 적용")
	_eq(unlinked, 0, "연결 안 된 칸은 없음")
	sim.run_to_end()


func _test_pvp() -> void:
	# 저지먼트: 칸 버프와 연결 해제
	var target: GameSession = GameSession.new(61)
	target.acquire_tarot(_tarot("hanged_man"))
	target.use_tarot(_tarot("hanged_man"), 4)
	target.acquire_tarot(_tarot("lovers"))
	target.use_tarot(_tarot("lovers"), 4, 1)
	PvpTarotRules.judgement(target, 4)
	_eq(target.board.get_slot_modifiers(4).size(), 0, "저지먼트: 칸 버프 해제")
	_eq(target.board.slot_links.size(), 0, "저지먼트: 러버 연결도 해제")
	_check(not target.inventory.cell_tarots.has(1), "저지먼트: 반대쪽 칸의 러버 표시도 정리")
	# 더 데빌: 5주사위 보장
	var a: GameSession = GameSession.new(62)
	var b: GameSession = GameSession.new(63)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	PvpTarotRules.devil(a, b, rng)
	_eq(a.deck.active.size(), 5, "더 데빌: 내 출전 5개 유지")
	_eq(b.deck.active.size(), 5, "더 데빌: 상대 출전 5개 유지")
	# 데스
	a.player.hp = 100
	b.player.hp = 100
	_eq(PvpTarotRules.death(a, b, 40), 40, "데스: X = 40")
	_eq(a.player.hp, 60, "데스: 내 체력 -40")
	_eq(b.player.hp, 60, "데스: 상대 체력 -40")
	a.player.hp = 10
	_eq(PvpTarotRules.death(a, b, 50), 9, "데스: 자살 불가 (최대 체력 - 1)")
	_eq(a.player.hp, 1, "데스 후 체력 1")
	# 템퍼런스
	var mine: Array[SpawnPacket] = [_packet(4, &"sword", 100)]
	var theirs: Array[SpawnPacket] = [_packet(1, &"bow", 40)]
	PvpTarotRules.temperance(mine, 4, theirs, 1)
	_eq(mine[0].total_count, 70, "템퍼런스: 인원 평균 70")
	_eq(theirs[0].unit_data.id, &"sword", "템퍼런스: 병과는 많은 쪽(소드)으로")


func _test_pools() -> void:
	var tarots: Array[TarotCardData] = ShopCatalog.tarot_pool(10)
	var ids: Array[StringName] = []
	for t: TarotCardData in tarots:
		ids.append(t.id)
	_check(ids.has(&"lovers"), "1인용 풀: 더 러버 포함")
	_check(not ids.has(&"devil") and not ids.has(&"death") and not ids.has(&"temperance"), "1인용 풀: 2인 전용 3종 제외")
	_check(not ids.has(&"judgement"), "1인용 풀: 저지먼트 제외 (적에게 타로 없음)")
	_eq(ShopCatalog.item_pool(10).size(), 23, "아이템 23종 등록")


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		print("  PASS  ", label)
	else:
		_fail_count += 1
		print("  FAIL  ", label, ("  → " + detail) if detail != "" else "")


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, label, "기대 %s, 실제 %s" % [str(expected), str(actual)])


func _near(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.01, label, "기대 %.3f, 실제 %.3f" % [expected, actual])
