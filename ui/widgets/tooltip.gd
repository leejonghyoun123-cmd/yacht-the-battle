extends CanvasLayer
## 커서를 따라다니는 상세 정보 창. 어느 화면에서든 Tooltip.show_text(...)로 띄운다.
## (손 모양 커서는 각 위젯의 mouse_default_cursor_shape = 손가락으로 처리)

var _panel: PanelContainer
var _label: Label


func _ready() -> void:
	layer = 50
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.95)
	style.border_color = UiConfig.COLOR_ACCENT
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(UiConfig.TOOLTIP_MAX_WIDTH, 0)
	_panel.add_child(_label)


func show_text(text: String) -> void:
	_label.text = text
	_panel.reset_size()
	_panel.visible = true
	_follow()


func hide_tip() -> void:
	_panel.visible = false


func _process(_delta: float) -> void:
	if _panel.visible:
		_follow()


func _follow() -> void:
	var vp: Viewport = get_viewport()
	var mouse: Vector2 = vp.get_mouse_position()
	var pos: Vector2 = mouse + UiConfig.TOOLTIP_OFFSET
	var screen: Vector2 = vp.get_visible_rect().size
	if pos.x + _panel.size.x > screen.x:
		pos.x = mouse.x - _panel.size.x - 10.0
	if pos.y + _panel.size.y > screen.y:
		pos.y = mouse.y - _panel.size.y - 10.0
	_panel.position = pos


## 위젯에 툴팁 연결 (text_func는 호출 시점의 최신 설명을 돌려준다)
func attach(control: Control, text_func: Callable) -> void:
	control.mouse_entered.connect(func() -> void: show_text(String(text_func.call())))
	control.mouse_exited.connect(hide_tip)
