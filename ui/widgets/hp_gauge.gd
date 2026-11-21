extends Control
## 체력 게이지: 최대 체력 대비 비율로 채움. 70% 이하 노란색, 30% 이하 빨간색. 실드는 하늘색 덧칠.

const COLOR_HIGH: Color = Color("4fc35a")
const COLOR_MID: Color = Color("e8c53a")
const COLOR_LOW: Color = Color("e5483f")
const COLOR_BG: Color = Color(0.12, 0.12, 0.14)
const COLOR_SHIELD: Color = Color("7fd4ff")
const MID_RATIO: float = 0.7
const LOW_RATIO: float = 0.3

var hp: int = 0
var max_hp: int = 1
var shield: int = 0


func _init() -> void:
	custom_minimum_size = Vector2(150, 20)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(p_hp: int, p_max: int, p_shield: int = 0) -> void:
	if p_hp == hp and p_max == max_hp and p_shield == shield:
		return
	hp = p_hp
	max_hp = maxi(1, p_max)
	shield = p_shield
	queue_redraw()


static func color_for(ratio: float) -> Color:
	if ratio <= LOW_RATIO:
		return COLOR_LOW
	if ratio <= MID_RATIO:
		return COLOR_MID
	return COLOR_HIGH


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_box(r, COLOR_BG)
	if ratio > 0.0:
		_box(Rect2(r.position, Vector2(r.size.x * ratio, r.size.y)), color_for(ratio))
	if shield > 0:
		var sr: float = clampf(float(shield) / float(max_hp), 0.0, 1.0)
		draw_rect(Rect2(Vector2(0, r.size.y - 4.0), Vector2(r.size.x * sr, 4.0)), COLOR_SHIELD)
	draw_rect(r, Color(0, 0, 0, 0.6), false, 1.0)
	var font: Font = ThemeDB.fallback_font
	var text: String = "%d / %d" % [hp, max_hp]
	var fs: int = 13
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos: Vector2 = Vector2((r.size.x - w) * 0.5, r.size.y * 0.5 + fs * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.8))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _box(rect: Rect2, color: Color) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	draw_style_box(sb, rect)
