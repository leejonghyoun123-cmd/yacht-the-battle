extends Control
## 선택지 팝업: 검은 반투명 화면 + 제목 + 버튼 격자. 고르면 chosen(value), 취소하면 cancelled.
## (수정 테이프: 지울 얏츠판 칸 / 사포와펜: 지울 면 → 새길 숫자)

signal chosen(value: Variant)
signal cancelled

var _title: Label
var _grid: GridContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = UiKit.panel(Color(0.1, 0.11, 0.15, 0.97), UiConfig.COLOR_ACCENT)
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_title = UiKit.label("", 18, UiConfig.COLOR_ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)
	var cancel: Button = UiKit.button("취소", 15)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.custom_minimum_size = Vector2(110, 36)
	cancel.pressed.connect(func() -> void:
		visible = false
		cancelled.emit())
	box.add_child(cancel)
	visible = false


## choices: [{ "value", "label" }]
func open(title: String, choices: Array[Dictionary]) -> void:
	_title.text = title
	UiKit.clear(_grid)
	_grid.columns = clampi(choices.size(), 1, 4)
	for c: Dictionary in choices:
		var b: Button = UiKit.button(String(c["label"]), 15)
		b.custom_minimum_size = Vector2(130, 40)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var v: Variant = c["value"]
		b.pressed.connect(func() -> void:
			visible = false
			chosen.emit(v))
		_grid.add_child(b)
	visible = true
