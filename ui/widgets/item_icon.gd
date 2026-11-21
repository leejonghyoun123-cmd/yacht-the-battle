extends Control
## 아이템 아이콘 (프로토타입: 도형으로 그림. 아트가 준비되면 이 위젯만 텍스처로 교체하면 된다)
## kind: "dice" | "enchant" | "food" | "wall" | "bag" | "locked"

var kind: String = "dice"
var text: String = ""
var color: Color = Color.WHITE
## 가방 크기 표현 (0~3)
var size_level: int = 1


func setup(p_kind: String, p_text: String = "", p_color: Color = Color.WHITE) -> Control:
	kind = p_kind
	text = p_text
	color = p_color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	return self


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var c: Vector2 = size * 0.5
	var s: float = minf(size.x, size.y)
	var font: Font = ThemeDB.fallback_font
	match kind:
		"dice":
			var box: Rect2 = Rect2(c - Vector2(s, s) * 0.4, Vector2(s, s) * 0.8)
			_round_rect(box, color, s * 0.14)
			draw_rect(box.grow(-2.0), Color(0, 0, 0, 0.15), false, 2.0)
			_text(font, text, c, int(s * 0.26), Color(0.12, 0.12, 0.14))
		"enchant":
			draw_circle(c, s * 0.38, color.darkened(0.35))
			draw_circle(c - Vector2(s, s) * 0.05, s * 0.3, color)
			draw_circle(c - Vector2(s, s) * 0.16, s * 0.07, Color(1, 1, 1, 0.7))
			_text(font, text, c, int(s * 0.24), Color(0.08, 0.08, 0.1))
		"food":
			for i: int in range(3):
				var b: Rect2 = Rect2(Vector2(s * (0.12 + 0.2 * (i % 2)), s * (0.5 - 0.22 * (i / 2))), Vector2(s * 0.56, s * 0.3))
				_round_rect(b, Color("c9a06a").darkened(0.08 * i), s * 0.1)
			_text(font, "식량", c + Vector2(0, s * 0.3), int(s * 0.16), Color(0.25, 0.15, 0.05))
		"wall":
			var w: Rect2 = Rect2(Vector2(s * 0.12, s * 0.22), Vector2(s * 0.76, s * 0.62))
			draw_rect(w, Color("8d8f94"))
			for row: int in range(4):
				var y: float = w.position.y + w.size.y * float(row) / 4.0
				draw_line(Vector2(w.position.x, y), Vector2(w.end.x, y), Color(0.3, 0.3, 0.32), 1.5)
			for i: int in range(4):
				draw_rect(Rect2(Vector2(w.position.x + w.size.x * (0.05 + 0.25 * i), w.position.y - s * 0.1), Vector2(s * 0.13, s * 0.1)), Color("8d8f94"))
		"bag":
			var k: float = 0.55 + 0.12 * float(size_level)
			var body: Rect2 = Rect2(c - Vector2(s * 0.4, s * 0.28) * k + Vector2(0, s * 0.08), Vector2(s * 0.8, s * 0.6) * k)
			draw_arc(Vector2(c.x, body.position.y), s * 0.2 * k, PI, TAU, 16, Color("5b3d27"), 4.0)
			_round_rect(body, Color("7a5235"), s * 0.08)
			draw_rect(Rect2(body.position + Vector2(0, body.size.y * 0.25), Vector2(body.size.x, body.size.y * 0.18)), Color("5b3d27"))
		"locked":
			_round_rect(r.grow(-s * 0.1), UiConfig.COLOR_LOCKED, s * 0.12)
			_text(font, "?", c, int(s * 0.4), Color(0.6, 0.6, 0.65))
	if text != "" and kind in ["food", "wall", "bag"]:
		pass


func _round_rect(rect: Rect2, fill: Color, radius: float) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, rect)


func _text(font: Font, t: String, center: Vector2, font_size: int, col: Color) -> void:
	if t == "":
		return
	var w: float = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-w * 0.5, font_size * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
