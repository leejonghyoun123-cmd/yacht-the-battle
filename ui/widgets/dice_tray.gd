extends Control
## 주사위 쟁반 (굴리는 곳). 위쪽 선반 = 고정한 주사위 자리, 아래 펠트 = 굴린 주사위가 떨어지는 곳, 오른쪽 컵 = 굴림 시작점.
## 그리기만 담당하고, 주사위 토큰 배치는 roll_ui가 이 위젯의 좌표 함수로 한다. (아트가 생기면 _draw만 교체)

const RIM: float = 14.0
const SHELF_HEIGHT: float = 172.0
const SHELF_GAP: float = 8.0
const CUP_RADIUS: float = 62.0

const COLOR_RIM: Color = Color("3c4047")
const COLOR_RIM_LIGHT: Color = Color("6b7079")
const COLOR_SHELF: Color = Color("2a2d33")
const COLOR_SHELF_SLOT: Color = Color("1e2025")
const COLOR_FELT: Color = Color("2f6b4f")
const COLOR_FELT_DARK: Color = Color("27583f")
const COLOR_CUP: Color = Color("5a2e1e")
const COLOR_CUP_IN: Color = Color("3a1c12")

var held_label: String = "고정한 주사위"


func shelf_rect() -> Rect2:
	return Rect2(Vector2(RIM, RIM), Vector2(size.x - RIM * 2.0, SHELF_HEIGHT))


func shelf_slot_rect(i: int, count: int = 5) -> Rect2:
	var r: Rect2 = shelf_rect()
	var w: float = (r.size.x - SHELF_GAP * float(count + 1)) / float(count)
	return Rect2(r.position + Vector2(SHELF_GAP + float(i) * (w + SHELF_GAP), SHELF_GAP), Vector2(w, r.size.y - SHELF_GAP * 2.0))


func felt_rect() -> Rect2:
	var top: float = RIM + SHELF_HEIGHT + 10.0
	return Rect2(Vector2(RIM + 6.0, top), Vector2(size.x - RIM * 2.0 - 12.0, size.y - top - RIM - 6.0))


## 주사위가 실제로 놓일 수 있는 펠트 영역 (컵 자리 제외)
func landing_rect() -> Rect2:
	var f: Rect2 = felt_rect()
	return Rect2(f.position + Vector2(10, 8), Vector2(f.size.x - CUP_RADIUS * 2.0 - 40.0, f.size.y - 16.0))


func cup_center() -> Vector2:
	var f: Rect2 = felt_rect()
	return Vector2(f.end.x - CUP_RADIUS - 14.0, f.position.y + f.size.y * 0.5)


func _draw() -> void:
	var outer: Rect2 = Rect2(Vector2.ZERO, size)
	_box(outer, COLOR_RIM, 18)
	draw_rect(outer.grow(-3.0), COLOR_RIM_LIGHT, false, 2.0)
	_box(shelf_rect(), COLOR_SHELF, 10)
	for i: int in range(5):
		_box(shelf_slot_rect(i), COLOR_SHELF_SLOT, 8)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, shelf_rect().position + Vector2(10, -1), held_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))
	var f: Rect2 = felt_rect()
	_box(f, COLOR_FELT, 10)
	# 펠트 결
	for k: int in range(int(f.size.y / 14.0)):
		var y: float = f.position.y + 7.0 + float(k) * 14.0
		draw_line(Vector2(f.position.x + 8, y), Vector2(f.end.x - 8, y), COLOR_FELT_DARK, 1.0)
	# 주사위통 받침 자리 (주사위통 자체는 roll_ui의 DiceCup 위젯이 그린다 — 마우스로 들고 흔든다)
	var c: Vector2 = cup_center()
	draw_circle(c, CUP_RADIUS + 6.0, Color(0, 0, 0, 0.18))
	draw_arc(c, CUP_RADIUS + 6.0, 0.0, TAU, 40, Color(1, 1, 1, 0.12), 2.0)


func _box(r: Rect2, color: Color, radius: int) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, r)
