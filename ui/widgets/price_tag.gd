extends Control
## 상품 위에 걸린 가격표 (왼쪽이 뾰족한 꼬리표 + 끈 구멍 + 살짝 기울어짐).
## setup(글자, 상태) — 상태: 0 = 판매 중, 1 = 판매됨, 2 = 준비 중/잠김

enum TagState { ON_SALE, SOLD, LOCKED }

const BODY: Color = Color("f6e7b8")
const BODY_SOLD: Color = Color("b9b2a0")
const EDGE: Color = Color("8a6a35")
const INK: Color = Color("4a2f12")
const STRING_COLOR: Color = Color("d9c9a0")
const TILT: float = -0.06

var text: String = ""
var state: int = TagState.ON_SALE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = UiConfig.SHOP_TAG_SIZE


func setup(p_text: String, p_state: int) -> void:
	text = p_text
	state = p_state
	queue_redraw()


func _ready() -> void:
	resized.connect(func() -> void: pivot_offset = Vector2(0.0, size.y * 0.5))
	rotation = TILT


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var notch: float = 14.0
	var mid: float = h * 0.5
	# 끈: 구멍에서 왼쪽 위 카드 모서리 쪽으로 늘어진 곡선
	var hole: Vector2 = Vector2(notch * 0.85, mid)
	var tie: Vector2 = Vector2(-10.0, mid + 12.0)
	var pts: PackedVector2Array = []
	for i: int in range(9):
		var t: float = float(i) / 8.0
		pts.append(hole.lerp(tie, t) + Vector2(0.0, -10.0 * 4.0 * t * (1.0 - t)))
	draw_polyline(pts, STRING_COLOR, 2.0, true)
	# 꼬리표 몸통 (그림자 → 몸통 → 테두리)
	var shape: PackedVector2Array = [
		Vector2(notch, 0), Vector2(w, 0), Vector2(w, h), Vector2(notch, h), Vector2(0, mid)]
	var shadow: PackedVector2Array = []
	for p: Vector2 in shape:
		shadow.append(p + Vector2(2, 3))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	draw_colored_polygon(shape, BODY if state == TagState.ON_SALE else BODY_SOLD)
	var outline: PackedVector2Array = shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, EDGE, 2.0, true)
	# 안쪽 점선 테두리 느낌
	draw_line(Vector2(notch + 4, 4), Vector2(w - 4, 4), Color(EDGE, 0.35), 1.0)
	draw_line(Vector2(notch + 4, h - 4), Vector2(w - 4, h - 4), Color(EDGE, 0.35), 1.0)
	# 구멍
	draw_circle(hole, 4.0, Color("2b2b2b"))
	draw_arc(hole, 4.5, 0.0, TAU, 16, EDGE, 1.2)
	# 글자
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 17 if text.length() <= 6 else 14
	var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var area_x: float = notch + 4.0
	var area_w: float = w - area_x - 4.0
	var baseline: float = mid + font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.35
	var ink: Color = INK if state == TagState.ON_SALE else Color("6b6255")
	draw_string(font, Vector2(area_x + (area_w - text_w) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	if state == TagState.SOLD:
		# 판매됨: 빨간 줄
		draw_line(Vector2(area_x, mid + 2), Vector2(w - 6, mid - 2), Color("c8463d"), 2.5)
