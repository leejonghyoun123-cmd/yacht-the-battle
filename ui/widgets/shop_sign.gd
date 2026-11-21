extends Control
## 상점 간판: 테두리를 따라 전구가 번갈아 깜빡이고 가운데 큰 "상점" 글자 + 부제

const BOARD: Color = Color("2a1416")
const FRAME: Color = Color("c8463d")
const BULB_ON: Color = Color("ffe9a8")
const BULB_OFF: Color = Color("6b4a2a")
const TITLE: Color = Color("f2c14e")
const BULB_SPACING: float = 22.0
const BLINK_TIME: float = 0.45

var title: String = "상점"
var subtitle: String = "부대를 강화하세요!"
var _phase: int = 0
var _blink: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 150)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_blink += delta
	if _blink >= BLINK_TIME:
		_blink = 0.0
		_phase = 1 - _phase
		queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	_draw_round_rect(r.grow(-2), FRAME, 14.0)
	_draw_round_rect(r.grow(-12), BOARD, 10.0)
	# 전구: 바깥 테두리 띠 위에 일정 간격
	var inset: Rect2 = r.grow(-7)
	var perimeter: Array[Vector2] = [inset.position, Vector2(inset.end.x, inset.position.y), inset.end, Vector2(inset.position.x, inset.end.y)]
	var k: int = 0
	for side: int in range(4):
		var a: Vector2 = perimeter[side]
		var b: Vector2 = perimeter[(side + 1) % 4]
		var n: int = maxi(1, int(a.distance_to(b) / BULB_SPACING))
		for i: int in range(n):
			var p: Vector2 = a.lerp(b, float(i) / float(n))
			var lit: bool = (k + _phase) % 2 == 0
			if lit:
				draw_circle(p, 5.5, Color(BULB_ON, 0.25))
			draw_circle(p, 3.2, BULB_ON if lit else BULB_OFF)
			k += 1
	var font: Font = ThemeDB.fallback_font
	var title_size: int = 46
	var tw: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var ty: float = size.y * 0.5 + 6.0
	var tp: Vector2 = Vector2((size.x - tw) * 0.5, ty)
	# 두꺼운 외곽선 + 그림자로 간판 글씨 느낌
	draw_string_outline(font, tp + Vector2(3, 4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, 10, Color(0, 0, 0, 0.5))
	draw_string_outline(font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, 10, Color("7a2a20"))
	draw_string(font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, TITLE)
	var sub_size: int = 15
	var sw: float = font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
	draw_string(font, Vector2((size.x - sw) * 0.5, size.y - 26.0), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color("f6e7b8"))


func _draw_round_rect(r: Rect2, color: Color, radius: float) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, r)
