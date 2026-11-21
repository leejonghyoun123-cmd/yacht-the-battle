class_name UnitCatalog
extends RefCounted
## 병과 ID → UnitData 조회 (res://data/units/<id>.tres, 한 번 읽으면 캐시)

const UNIT_DIR: String = "res://data/units/"
const ALL_IDS: Array[StringName] = [&"sword", &"bow", &"shield", &"cannon", &"healer", &"giant"]
## 일반 주사위로 배치할 수 있는 병과 (거인·킹은 포커카드 에이스 전용 — 포커카드 단계에서 연결)
const NORMAL_IDS: Array[StringName] = [&"sword", &"bow", &"shield", &"cannon", &"healer"]
const POKER_ONLY_IDS: Array[StringName] = [&"giant"]


static func is_poker_only(unit_id: StringName) -> bool:
	return POKER_ONLY_IDS.has(unit_id)

static var _cache: Dictionary = {}


static func get_unit(unit_id: StringName) -> UnitData:
	if _cache.has(unit_id):
		return _cache[unit_id]
	var path: String = UNIT_DIR + String(unit_id) + ".tres"
	if not ResourceLoader.exists(path):
		push_error("UnitCatalog: 병과 데이터 없음 " + path)
		return null
	var data: UnitData = load(path) as UnitData
	_cache[unit_id] = data
	return data
