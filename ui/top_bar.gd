extends PanelContainer
## 상단 바 (준비 화면 공통, 항상 같은 위치): 왼쪽 상태 · 가운데 타이머(+30초) · 오른쪽 화면 이동 탭

signal screen_requested(screen: String)

var session: GameSession
var current_screen: String = "barracks"

var _status: Label
var _timer_label: Label
var _extend_button: Button
var _tabs: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0, UiConfig.TOP_BAR_HEIGHT)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.92)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)

	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	_status = UiKit.label("", 15)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)

	var center: HBoxContainer = HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(center)
	_timer_label = UiKit.label("1:30", UiConfig.TIMER_FONT_SIZE, Color.WHITE)
	_timer_label.custom_minimum_size = Vector2(78, 0)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_timer_label)
	_extend_button = UiKit.button("+30초", 13)
	_extend_button.pressed.connect(func() -> void:
		session.timer.extend()
		_update())
	center.add_child(_extend_button)

	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(tabs)
	for entry: Array in [["barracks", "유닛배치"], ["roll", "주사위"], ["shop", "상점"]]:
		var b: Button = UiKit.button(entry[1], 14)
		b.toggle_mode = true
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var key: String = entry[0]
		b.pressed.connect(func() -> void: screen_requested.emit(key))
		tabs.add_child(b)
		_tabs[key] = b


func _process(_delta: float) -> void:
	if visible and session != null:
		_update()


func _update() -> void:
	var p: PlayerState = session.player
	var shield: String = "  실드 %d" % p.round_shield if p.round_shield > 0 else ""
	_status.text = "라운드 %d / %d   골드 %s   체력 %d / %d%s" % [
		session.get_round(), LevelTable.FINAL_ROUND, NumberFormatter.format_num(p.gold), p.hp, p.max_hp, shield]
	_timer_label.text = session.timer.get_text()
	_timer_label.add_theme_color_override("font_color", Color("ff6b6b") if session.timer.time_left <= UiConfig.TIMER_WARNING_SECONDS else Color.WHITE)
	_extend_button.disabled = not session.timer.can_extend()
	_extend_button.text = "연장됨" if session.timer.extended else "+30초"
	# 연병장이 곧 배치 화면: 배치 단계에서는 탭 이름으로 알려 준다
	(_tabs["barracks"] as Button).text = "유닛배치 ●" if session.phase == GameSession.Phase.PLACEMENT else "유닛배치"
	for key: String in _tabs.keys():
		(_tabs[key] as Button).set_pressed_no_signal(key == current_screen)
