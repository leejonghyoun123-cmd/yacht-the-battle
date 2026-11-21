class_name UnitCatalog
extends RefCounted
## 병과 ID → UnitData 조회 (res://data/units/<id>.tres, 한 번 읽으면 캐시)

const UNIT_DIR: String = "res://data/units/"
const ALL_IDS: Array[StringName] = [&"sword", &"bow", &"shield", &"cannon", &"healer", &"giant"]

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
