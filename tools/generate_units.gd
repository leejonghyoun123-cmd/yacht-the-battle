extends SceneTree
## 6종 병과 .tres 생성 도구 (임시 스탯). 이미 있는 파일은 덮어쓰지 않는다.
## 실행: godot --headless --path <프로젝트> --script res://tools/generate_units.gd

const UNIT_DIR: String = "res://data/units/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UNIT_DIR))

	var sword: UnitData = _unit(&"sword", "소드", UnitData.Role.MELEE, Color("d9dde8"), 100.0, 10.0, 1.0, 16.0, 60.0)
	_save(sword)

	var bow: UnitData = _unit(&"bow", "보우", UnitData.Role.RANGED, Color("8fd16a"), 60.0, 7.0, 0.625, 220.0, 55.0)
	_save(bow)

	var shield: UnitData = _unit(&"shield", "실드", UnitData.Role.TANK, Color("6aa7e0"), 220.0, 5.0, 1.25, 16.0, 50.0)
	shield.damage_reduction = 0.3
	shield.body_radius = 6.0
	_save(shield)

	var cannon: UnitData = _unit(&"cannon", "캐논", UnitData.Role.RANGED, Color("e0884f"), 70.0, 7.0, 2.4, 200.0, 45.0)
	cannon.splash_radius = 16.0
	_save(cannon)

	var healer: UnitData = _unit(&"healer", "힐러", UnitData.Role.RANGED, Color("f2d86b"), 80.0, 4.0, 1.0, 120.0, 50.0)
	healer.damage_type = UnitData.DamageType.MAGICAL
	healer.heal_per_second = 6.0
	healer.support_radius = 90.0
	healer.aura_attack_bonus = 0.1
	healer.aura_defense_bonus = 0.1
	_save(healer)


	quit(0)


func _unit(p_id: StringName, p_name: String, p_role: UnitData.Role, p_color: Color,
		hp: float, atk: float, interval: float, attack_range: float, speed: float) -> UnitData:
	var u: UnitData = UnitData.new()
	u.id = p_id
	u.display_name = p_name
	u.role = p_role
	u.color = p_color
	u.max_hp = hp
	u.attack = atk
	u.attack_interval = interval
	u.attack_range = attack_range
	u.move_speed = speed
	return u


func _save(u: UnitData) -> void:
	var path: String = UNIT_DIR + String(u.id) + ".tres"
	if ResourceLoader.exists(path):
		print("건너뜀 (이미 존재): ", path)
		return
	var err: Error = ResourceSaver.save(u, path)
	print("생성: " if err == OK else "실패(%d): " % err, path)
