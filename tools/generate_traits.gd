extends SceneTree
## 주사위 성질 .tres 생성. 이미 있는 파일은 덮어쓰지 않는다.
## (포커카드 삭제 2026-11-22 — 지금은 생성할 성질 없음. 다른 성질은 generate_content_v2·v3)
## 실행: godot --headless --path <프로젝트> --script res://tools/generate_traits.gd

const DIR: String = "res://data/traits/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	quit(0)


func _make(t: DiceTraitData, p_id: StringName, p_name: String, desc: String) -> void:
	t.id = p_id
	t.display_name = p_name
	t.description = desc
	var path: String = DIR + String(p_id) + ".tres"
	if ResourceLoader.exists(path):
		print("건너뜀 (이미 존재): ", path)
		return
	var err: Error = ResourceSaver.save(t, path)
	print("생성: " if err == OK else "실패(%d): " % err, path)
