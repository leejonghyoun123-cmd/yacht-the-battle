extends Control
## 주사위 선택 연출 (성질 변환·대상 지정 아이템):
## 화면을 검은 반투명(40%)으로 덮고, 고를 수 있는 내 주사위만 앞쪽에 크게 띄운다.
## 고르면 chosen 시그널 → 구매가 성공하면 play_transform()으로 뒤집히며 바뀌는 연출 후 닫힌다.

signal chosen(dice: DiceInstance)
signal cancelled

const ItemIcon: GDScript = preload("res://ui/widgets/item_icon.gd")
const DIM_ALPHA: float = 0.4
const ICON_SIZE: Vector2 = Vector2(110, 110)

var _dim: ColorRect
var _title: Label
var _row: HBoxContainer
var _icons: Dictionary = {}
var _tween: Tween = null
var _busy: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, DIM_ALPHA)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		if not _busy and e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			_cancel())
	add_child(_dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	_title = UiKit.label("", 22, Color("ffe08a"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 6)
	box.add_child(_title)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 26)
	box.add_child(_row)
	var cancel: Button = UiKit.button("취소", 16)
	cancel.custom_minimum_size = Vector2(120, 40)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel.pressed.connect(func() -> void:
		if not _busy:
			_cancel())
	box.add_child(cancel)
	visible = false


## 선택창 열기. dice: 고를 수 있는 주사위만
func open(title: String, dice: Array[DiceInstance], deck: DeckManager) -> void:
	_kill_tween()
	_busy = false
	_title.text = title
	UiKit.clear(_row)
	_icons.clear()
	for d: DiceInstance in dice:
		var holder: VBoxContainer = VBoxContainer.new()
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon: Control = ItemIcon.new()
		icon.custom_minimum_size = ICON_SIZE
		icon.pivot_offset = ICON_SIZE * 0.5
		icon.call("setup_dice", d, d.get_short_name())
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var target: DiceInstance = d
		icon.gui_input.connect(func(e: InputEvent) -> void:
			if not _busy and e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				chosen.emit(target))
		icon.mouse_entered.connect(func() -> void:
			if not _busy:
				icon.scale = Vector2.ONE * 1.08)
		icon.mouse_exited.connect(func() -> void:
			if not _busy:
				icon.scale = Vector2.ONE)
		holder.add_child(icon)
		var where: String = "출전 %d" % (deck.active.find(d) + 1) if deck.active.has(d) else "가방"
		var cap: Label = UiKit.label("%s · %s" % [d.data.display_name, where], 13, Color.WHITE)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(cap)
		_row.add_child(holder)
		_icons[d] = icon
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)


## 변환 연출: 고른 주사위만 남기고, 뒤집혀(가로로 접혔다 펴짐) 새 모습으로 바뀐 뒤 빛나고 닫힌다
func play_transform(dice: DiceInstance, caption: String) -> void:
	_busy = true
	_title.text = caption
	var icon: Control = _icons.get(dice, null)
	for d: DiceInstance in _icons.keys():
		if d != dice:
			(_icons[d] as Control).get_parent().modulate.a = 0.15
	if icon == null:
		_close_after(0.4)
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(icon, "scale", Vector2(1.15, 1.15), 0.15)
	_tween.tween_property(icon, "scale", Vector2(0.0, 1.2), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		icon.call("setup_dice", dice, dice.get_short_name())
		icon.modulate = Color(2.0, 2.0, 1.6))
	_tween.tween_property(icon, "scale", Vector2(1.3, 1.3), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(icon, "modulate", Color.WHITE, 0.5)
	_tween.tween_property(icon, "scale", Vector2.ONE * 1.1, 0.2)
	_tween.tween_interval(0.7)
	_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(func() -> void:
		visible = false
		_busy = false)


## 구매 실패 등: 바로 닫기
func close() -> void:
	_kill_tween()
	_busy = false
	visible = false


func _close_after(t: float) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(t)
	_tween.tween_callback(close)


func _cancel() -> void:
	close()
	cancelled.emit()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
