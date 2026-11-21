extends SceneTree
## 주사위 성질 .tres 생성. 이미 있는 파일은 덮어쓰지 않는다.
## 실행: godot --headless --path <프로젝트> --script res://tools/generate_traits.gd

const DIR: String = "res://data/traits/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var poker: PokerTrait = PokerTrait.new()
	poker.rank = DiceTraitData.Rank.B
	poker.badge = "포커"
	_make(poker, &"poker", "포커카드", "6면 주사위 전용 (성질 없는 주사위). 면이 A(1) ~ K(13)로 바뀐다.\nA가 나오면 거인, K가 나오면 킹을 배치할 수 있다.\n변환 시 수트(♠♥♦♣) 1개가 정해진다.")
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
