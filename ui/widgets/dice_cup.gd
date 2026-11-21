extends Control
## 주사위통(컵). 마우스로 누르고 있는 동안 커서를 따라다니며 흔들리고, 안의 주사위들도 덜그럭거린다.
## 놓으면 released(컵 중심 전역 좌표) 신호 → 화면이 실제 굴림과 쏟아지는 연출을 처리한다.
## (나중에 이미지 애니메이션으로 바꿀 때는 _draw만 교체하면 된다)

signal grabbed
signal released(global_center: Vector2)

const RADIUS: float = 62.0
const SHAKE_AMOUNT: float = 7.0
const INNER_DIE: float = 18.0

var enabled: bool = true
## 비활성일 때 이유 (툴팁)
var disabled_reason: String = ""
## 컵 안 주사위 표시용 { "text": String }
var inner_dice: Array[Dictionary] = []
var home_position: Vector2 = Vector2.ZERO

var _dragging: bool = false
var _grab_offset: Vector2 = Vector2.ZERO
var _shake_time: float = 0.0
var _inner_offsets: Array[Vector2] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	custom_minimum_size = Vector2(RADIUS * 2.0 + 16.0, RADIUS * 2.0 + 16.0)
	size = custom_minimum_size
	pivot_offset = size * 0.5


func is_dragging() -> bool:
	return _dragging


func go_home(animate: bool) -> void:
	if _dragging:
		return
	if animate:
		var tw: Tween = create_tween()
		tw.tween_property(self, "position", home_position, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "rotation", 0.0, 0.3)
	else:
		position = home_position
		rotation = 0.0


func set_inner(dice_texts: Array[String]) -> void:
	inner_dice.clear()
	_inner_offsets.clear()
	for t: String in dice_texts:
		inner_dice.append({ "text": t })
		_inner_offsets.append(Vector2.ZERO)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and enabled and not _dragging:
			_dragging = true
			_grab_offset = mb.position
			mouse_default_cursor_shape = Control.CURSOR_DRAG
			grabbed.emit()
			accept_event()


## 컵 밖에서 버튼을 놓아도 감지하도록 전역 입력으로 처리
func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_dragging = false
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			released.emit(global_position + size * 0.5)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_FORBIDDEN
	if not _dragging:
		return
	_shake_time += delta
	# 커서를 따라다니며 흔들림
	var parent_ctrl: Control = get_parent() as Control
	var mouse_local: Vector2 = parent_ctrl.get_local_mouse_position() if parent_ctrl != null else get_global_mouse_position()
	var shake: Vector2 = Vector2(_rng.randf_range(-SHAKE_AMOUNT, SHAKE_AMOUNT), _rng.randf_range(-SHAKE_AMOUNT, SHAKE_AMOUNT))
	position = mouse_local - _grab_offset + shake
	rotation = sin(_shake_time * 38.0) * 0.12
	# 안의 주사위도 덜그럭
	for i: int in range(_inner_offsets.size()):
		_inner_offsets[i] = Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	draw_circle(c + Vector2(5, 7), RADIUS, Color(0, 0, 0, 0.32))
	var rim: Color = Color("6a3522") if enabled else Color("4a3a33")
	draw_circle(c, RADIUS, rim)
	draw_circle(c, RADIUS - 11.0, Color("2e140c"))
	draw_arc(c, RADIUS - 2.0, -2.4, -0.6, 24, Color(1, 1, 1, 0.22), 3.0)
	# 컵 안 주사위
	var n: int = inner_dice.size()
	var font: Font = ThemeDB.fallback_font
	for i: int in range(n):
		var ang: float = TAU * float(i) / float(maxi(n, 1)) + 0.4
		var p: Vector2 = c + Vector2(cos(ang), sin(ang)) * (RADIUS * 0.42) + (_inner_offsets[i] if i < _inner_offsets.size() else Vector2.ZERO)
		var r: Rect2 = Rect2(p - Vector2(INNER_DIE, INNER_DIE) * 0.5, Vector2(INNER_DIE, INNER_DIE))
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color("f4f1e8")
		sb.set_corner_radius_all(4)
		draw_style_box(sb, r)
		var t: String = String(inner_dice[i]["text"])
		var w: float = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, p + Vector2(-w * 0.5, 3.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.15, 0.15, 0.17))
	if n == 0:
		var label: String = "주사위통" if enabled else ""
		var lw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, c + Vector2(-lw * 0.5, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.4))
