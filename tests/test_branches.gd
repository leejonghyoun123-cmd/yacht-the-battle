extends SceneTree
## 중첩 특수능력(분기) 검증 (킹·포커카드는 2026-11-22 삭제)
## 실행: godot --headless --path <프로젝트> --script res://tests/test_branches.gd

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	print("===== 분기 테스트 =====")
	_test_branches()
	_test_reflect()
	print("===== 결과: 통과 %d / 실패 %d =====" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func _test_branches() -> void:
	var sword: UnitData = UnitCatalog.get_unit(&"sword")
	_eq(sword.get_branch_level(49), 0, "소드 49명: 분기 없음")
	_eq(sword.get_branch_level(50), 1, "소드 50명: 1분기")
	_eq(sword.get_branch_level(150), 2, "소드 150명: 2분기")
	var u: BattleUnit = BattleUnit.new()
	u.setup(0, 0, 0, sword, 1.0, false, 150)
	_near(u.attack, 10.0 * 1.3 * 1.1, "소드 2분기 공격력 = 10 ×1.3 ×1.1")
	_near(u.splash_radius, 22.0, "소드 2분기 회전베기 광역 22")


func _packet(cell: int, id: StringName, count: int) -> SpawnPacket:
	var p: SpawnPacket = SpawnPacket.new()
	p.cell_index = cell
	p.unit_data = UnitCatalog.get_unit(id)
	p.total_count = count
	return p


func _test_reflect() -> void:
	var sim: BattleSimulation = BattleSimulation.new()
	sim.setup([[_packet(4, &"shield", 150)], [_packet(4, &"sword", 1)]], 3)
	var shield: BattleUnit = null
	var enemy: BattleUnit = null
	for u: BattleUnit in sim.units:
		if u.team == 0 and shield == null:
			shield = u
		elif u.team == 1:
			enemy = u
	_near(shield.reflect_ratio, 0.25, "실드 2분기 가시방패 반사 25%")
	var enemy_hp: float = enemy.hp
	sim._hit(enemy, shield, 40.0)
	_check(enemy.hp < enemy_hp, "실드를 때리면 공격자도 피해", "%f → %f" % [enemy_hp, enemy.hp])
	sim.run_to_end()


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
