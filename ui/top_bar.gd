extends PanelContainer
## 상단 바 (준비 화면 공통, 항상 같은 위치): 왼쪽 상태 · 가운데 타이머(+30초) · 오른쪽 화면 이동 탭

signal screen_requested(screen: String)

var session: GameSession
var current_screen: String = "barracks"

const StatIcon: GDScript = preload("res://ui/widgets/stat_icon.gd")
const HpGauge: GDScript = preload("res://ui/widgets/hp_gauge.gd")

var _status: Label
var _gold_label: Label
var _hp_gauge: Control
var _shield_label: Label
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
	# 왼쪽 상태: 라운드 · [금화] 골드 · [하트] 체력 게이지
	var left: HBoxContainer = HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	_status = UiKit.label("", 15)
	left.add_child(_status)
	left.add_child(_spacer(10))
	left.add_child(StatIcon.new().call("setup", "coin"))
	_gold_label = UiKit.label("", 16, Color("ffe08a"))
	left.add_child(_gold_label)
	left.add_child(_spacer(10))
	left.add_child(StatIcon.new().call("setup", "heart"))
	_hp_gauge = HpGauge.new()
	_hp_gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(_hp_gauge)
	_shield_label = UiKit.label("", 13, Color("7fd4ff"))
	left.add_child(_shield_label)

	var center: HBoxContainer = HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(center)
	_timer_label = UiKit.label("2:00", UiConfig.TIMER_FONT_SIZE, Color.WHITE)
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


func _spacer(width: int) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(width, 0)
	return c


func _process(_delta: float) -> void:
	if visible and session != null:
		_update()


func _update() -> void:
	var p: PlayerState = session.player
	_status.text = "라운드 %d / %d" % [session.get_round(), LevelTable.FINAL_ROUND]
	_gold_label.text = NumberFormatter.format_num(p.gold)
	_hp_gauge.call("set_values", p.hp, p.max_hp, p.round_shield)
	_shield_label.text = "실드 %d" % p.round_shield if p.round_shield > 0 else ""
	# 솔로(타이머 꺼짐)에서는 시간·연장 버튼을 숨긴다
	_timer_label.visible = session.timer.enabled
	_extend_button.visible = session.timer.enabled
	_timer_label.text = session.timer.get_text()
	_timer_label.add_theme_color_override("font_color", Color("ff6b6b") if session.timer.time_left <= UiConfig.TIMER_WARNING_SECONDS else Color.WHITE)
	_extend_button.disabled = not session.timer.can_extend()
	_extend_button.text = "연장됨" if session.timer.extended else "+30초"
	# 연병장이 곧 배치 화면: 배치 단계에서는 탭 이름으로 알려 준다
	(_tabs["barracks"] as Button).text = "유닛배치 ●" if session.phase == GameSession.Phase.PLACEMENT else "유닛배치"
	for key: String in _tabs.keys():
		(_tabs[key] as Button).set_pressed_no_signal(key == current_screen)
