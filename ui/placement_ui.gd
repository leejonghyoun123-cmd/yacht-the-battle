extends Control
## 배치 화면 오버레이. 주사위마다 [병과 선택 → 칸 클릭]으로 소환한다.
## 배치할 때마다 뒤쪽 연병장에 병력이 바로 나타난다.

signal battle_requested

var session: GameSession
var selected_summon: int = 0
var selected_unit: StringName = &"sword"

var _list_box: VBoxContainer
var _unit_box: HBoxContainer
var _board_slot: VBoxContainer
var _hint_slot: VBoxContainer
var _start_button: Button
var _info_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layout: Dictionary = UiKit.overlay_layout(self, 10, UiConfig.TOP_BAR_HEIGHT)

	var left: PanelContainer = UiKit.panel()
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	left.add_child(col)
	(layout["top_left"] as Container).add_child(left)
	_hint_slot = layout["top_right"]

	col.add_child(UiKit.label("배치: 주사위 선택 → 병과 선택 → 칸 클릭", 16, UiKit.COLOR_ACCENT))
	_list_box = VBoxContainer.new()
	col.add_child(_list_box)
	col.add_child(UiKit.label("병과", 13, UiKit.COLOR_TEXT_DIM))
	_unit_box = HBoxContainer.new()
	col.add_child(_unit_box)
	_board_slot = VBoxContainer.new()
	col.add_child(_board_slot)
	_info_label = UiKit.label("", 12, UiKit.COLOR_TEXT_DIM)
	col.add_child(_info_label)
	var buttons: HBoxContainer = HBoxContainer.new()
	col.add_child(buttons)
	var reset: Button = UiKit.button("배치 초기화")
	reset.pressed.connect(func() -> void:
		session.reset_placement()
		selected_summon = 0
		refresh.call_deferred())
	buttons.add_child(reset)
	_start_button = UiKit.button("전투 시작 ▶", 18)
	_start_button.pressed.connect(func() -> void: battle_requested.emit())
	buttons.add_child(_start_button)


func refresh() -> void:
	if session == null or _list_box == null:
		return
	if selected_summon < 0 or selected_summon >= session.summons.size() or session.summons[selected_summon]["placed"]:
		selected_summon = session.next_unplaced_index()

	UiKit.clear(_list_box)
	for i: int in range(session.summons.size()):
		var s: Dictionary = session.summons[i]
		var text: String = "주사위%d: %s명" % [i + 1, NumberFormatter.format_num(s["value"])]
		if s["reason"] != "":
			text += "  (%s명 → %s)" % [NumberFormatter.format_num(s["base"]), s["reason"]]
		if s["placed"]:
			var row_name: String = ["후열", "중열", "전열"][BoardState.row_of(s["cell"])]
			var kind: String = "중첩" if session.board.cells[s["cell"]].is_stack else "소비"
			text += "  ✔ %s → %s %s칸" % [UnitCatalog.get_unit(s["unit_id"]).display_name, row_name, kind]
		var b: Button = UiKit.button(("▶ " if i == selected_summon else "   ") + text, 13)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = s["placed"]
		b.pressed.connect(func() -> void:
			selected_summon = i
			refresh.call_deferred())
		_list_box.add_child(b)

	UiKit.clear(_unit_box)
	for id: StringName in UnitCatalog.ALL_IDS:
		var data: UnitData = UnitCatalog.get_unit(id)
		var ub: Button = UiKit.button(data.display_name, 14)
		ub.toggle_mode = true
		ub.button_pressed = id == selected_unit
		ub.add_theme_color_override("font_color", data.color)
		ub.pressed.connect(func() -> void:
			selected_unit = id
			refresh.call_deferred())
		_unit_box.add_child(ub)

	UiKit.clear(_board_slot)
	_board_slot.add_child(UiKit.board_grid(session.board, _on_cell_pressed, _is_cell_placeable))

	var data_sel: UnitData = UnitCatalog.get_unit(selected_unit)
	_info_label.text = "%s: 체력 %d · 공격 %d · 사거리 %d%s   |   같은 병과끼리만 같은 칸에 쌓입니다." % [
		data_sel.display_name, int(data_sel.max_hp), int(data_sel.attack), int(data_sel.attack_range),
		" · 소환 인원을 1~3명 거인으로 합체" if data_sel.is_giant else ""]
	_start_button.disabled = not session.all_placed()

	UiKit.clear(_hint_slot)
	_hint_slot.add_child(UiKit.enemy_hint(session))


func _on_cell_pressed(idx: int) -> void:
	if session.place(selected_summon, selected_unit, idx):
		refresh.call_deferred()


func _is_cell_placeable(idx: int) -> bool:
	return selected_summon >= 0 and session.can_place(selected_summon, selected_unit, idx)
