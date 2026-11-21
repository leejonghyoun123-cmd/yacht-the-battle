extends Control
## 임시 아이콘 (도형으로 그림): "coin" 금화 / "heart" 하트. 아트가 생기면 TextureRect로 교체.

var kind: String = "coin"


func setup(p_kind: String, icon_size: float = 22.0) -> Control:
	kind = p_kind
	custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size * 0.5
	match kind:
		"coin":
			draw_circle(c + Vector2(1, 1.5), s * 0.46, Color(0, 0, 0, 0.35))
			draw_circle(c, s * 0.46, Color("c8901e"))
			draw_circle(c, s * 0.38, Color("f2c14e"))
			draw_arc(c, s * 0.3, 0.0, TAU, 20, Color("c8901e"), 1.5)
			draw_circle(c - Vector2(s * 0.12, s * 0.14), s * 0.08, Color(1, 1, 1, 0.7))
		"heart":
			var r: float = s * 0.24
			var col: Color = Color("e5483f")
			draw_circle(c + Vector2(-r * 0.95, -r * 0.35), r, col)
			draw_circle(c + Vector2(r * 0.95, -r * 0.35), r, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 1.9, -r * 0.1), c + Vector2(r * 1.9, -r * 0.1), c + Vector2(0, s * 0.44),
			]), col)
			draw_circle(c + Vector2(-r * 1.1, -r * 0.6), r * 0.3, Color(1, 1, 1, 0.55))
