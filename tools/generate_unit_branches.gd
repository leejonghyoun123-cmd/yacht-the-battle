extends SceneTree
## 중첩 특수능력(분기) .tres 생성 + 킹 병과 생성 + 기존 병과에 분기 연결.
## 분기·킹 파일은 이미 있으면 덮어쓰지 않는다. 병과 .tres는 분기 칸이 비어 있을 때만 채워 저장한다.
## 실행: godot --headless --path <프로젝트> --script res://tools/generate_unit_branches.gd

const BRANCH_DIR: String = "res://data/unit_branches/"
const UNIT_DIR: String = "res://data/units/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BRANCH_DIR))
	_make_king()

	# --- 소드: 근접 딜러 → 단단해지고, 2분기에 주변을 함께 베는 회전베기
	var s1: UnitBranch = _branch("sword_1", "숙련 검술", "공격력 ×1.3, 체력 ×1.2")
	s1.attack_mult = 1.3
	s1.hp_mult = 1.2
	var s2: UnitBranch = _branch("sword_2", "회전베기", "공격이 주변 22 반경 광역 피해가 되고 공격력 ×1.1")
	s2.splash_add = 22.0
	s2.attack_mult = 1.1
	_link(&"sword", s1, s2)

	# --- 보우: 속사 → 불화살(광역 + 사거리)
	var b1: UnitBranch = _branch("bow_1", "속사", "공격 간격 ×0.75 (공속 33% 증가)")
	b1.interval_mult = 0.75
	var b2: UnitBranch = _branch("bow_2", "불화살", "화살이 18 반경 광역 피해, 사거리 +30")
	b2.splash_add = 18.0
	b2.range_add = 30.0
	_link(&"bow", b1, b2)

	# --- 실드: 철벽 → 가시방패(반사)
	var h1: UnitBranch = _branch("shield_1", "철벽", "체력 ×1.4, 받는 피해 감소 +10%")
	h1.hp_mult = 1.4
	h1.damage_reduction_add = 0.1
	var h2: UnitBranch = _branch("shield_2", "가시방패", "받은 피해의 25%를 공격자에게 반사, 몸집 ×1.2")
	h2.reflect_add = 0.25
	h2.size_mult = 1.2
	_link(&"shield", h1, h2)

	# --- 캐논: 대구경 → 연발 포격
	var c1: UnitBranch = _branch("cannon_1", "대구경 포탄", "광역 반경 +8, 공격력 ×1.15")
	c1.splash_add = 8.0
	c1.attack_mult = 1.15
	var c2: UnitBranch = _branch("cannon_2", "연발 포격", "공격 간격 ×0.6 (공속 67% 증가)")
	c2.interval_mult = 0.6
	_link(&"cannon", c1, c2)

	# --- 힐러: 치유의 물결 → 축복(공격 오라 강화)
	var e1: UnitBranch = _branch("healer_1", "치유의 물결", "회복량 ×1.5, 회복·오라 범위 ×1.4")
	e1.heal_mult = 1.5
	e1.support_radius_mult = 1.4
	var e2: UnitBranch = _branch("healer_2", "축복", "오라 안 아군 공격력 +15% 추가 (총 +25%)")
	e2.aura_attack_add = 0.15
	_link(&"healer", e1, e2)
	quit(0)


func _make_king() -> void:
	var path: String = UNIT_DIR + "king.tres"
	var k1: UnitBranch = _branch("king_1", "왕의 위엄", "장판 범위 ×1.5, 장판 공격력 배수 1.3 → 1.5")
	k1.support_radius_mult = 1.5
	k1.king_attack_mult_add = 0.2
	var k2: UnitBranch = _branch("king_2", "왕의 진군", "장판 받는 피해 배수 ×0.85 (0.8 → 0.68), 장판 공속 ×1.25, 킹 체력 ×1.5")
	k2.king_damage_taken_mult = 0.85
	k2.king_haste_add = 0.25
	k2.hp_mult = 1.5
	if ResourceLoader.exists(path):
		print("건너뜀 (이미 존재): ", path)
		return
	var u: UnitData = UnitData.new()
	u.id = &"king"
	u.display_name = "킹"
	u.role = UnitData.Role.MELEE
	u.color = Color("ffcc33")
	u.max_hp = 600.0
	u.attack = 14.0
	u.attack_interval = 1.0
	u.attack_range = 18.0
	u.move_speed = 50.0
	u.body_radius = 8.0
	u.support_radius = 110.0
	u.is_unique = true
	u.king_attack_mult = 1.3
	u.king_damage_taken_mult = 0.8
	u.king_haste_mult = 1.0
	u.share_damage_in_aura = true
	u.branch_thresholds = Vector2i(3, 5)
	u.branch_1 = _save_branch(k1)
	u.branch_2 = _save_branch(k2)
	var err: Error = ResourceSaver.save(u, path)
	print("생성: " if err == OK else "실패(%d): " % err, path)


func _branch(file_id: String, p_name: String, desc: String) -> UnitBranch:
	var path: String = BRANCH_DIR + file_id + ".tres"
	if ResourceLoader.exists(path):
		print("건너뜀 (이미 존재): ", path)
		return load(path) as UnitBranch
	var b: UnitBranch = UnitBranch.new()
	b.display_name = p_name
	b.description = desc
	# 값을 채운 뒤 저장해야 하므로 경로만 기억해 두고 _link에서 저장한다
	b.set_meta("save_path", path)
	return b


func _save_branch(b: UnitBranch) -> UnitBranch:
	if not b.has_meta("save_path"):
		return b
	var path: String = b.get_meta("save_path")
	b.remove_meta("save_path")
	var err: Error = ResourceSaver.save(b, path)
	print("생성: " if err == OK else "실패(%d): " % err, path)
	return load(path) as UnitBranch


func _link(unit_id: StringName, b1: UnitBranch, b2: UnitBranch) -> void:
	var saved_1: UnitBranch = _save_branch(b1)
	var saved_2: UnitBranch = _save_branch(b2)
	var path: String = UNIT_DIR + String(unit_id) + ".tres"
	var u: UnitData = load(path) as UnitData
	if u == null:
		push_error("병과 없음: " + path)
		return
	if u.branch_1 != null or u.branch_2 != null:
		print("건너뜀 (분기 이미 연결): ", path)
		return
	u.branch_1 = saved_1
	u.branch_2 = saved_2
	var err: Error = ResourceSaver.save(u, path)
	print("분기 연결: " if err == OK else "실패(%d): " % err, path)
