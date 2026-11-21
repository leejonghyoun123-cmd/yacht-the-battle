extends Node
## 게임 전체 화면 흐름 (메인 씬 루트). 씬에는 루트 Node + 이 스크립트만 두면 된다.
## 준비 시간(타이머) 동안 연병장 · 주사위(굴림/배치) · 상점 화면을 자유롭게 오가고,
## 배치 후 [전투 시작] 또는 시간 만료 시 전투 → 정산 → 다음 라운드 연병장.
## 로직은 GameSession, 화면 전환만 여기서 담당한다.

## 0이면 무작위 시드
@export var fixed_seed: int = 0

var session: GameSession
var view: Node2D
var tooltip: Node
var top_bar: Control
var screens: Dictionary = {}
var current_screen: String = "barracks"

var _ui_layer: CanvasLayer
var _top_layer: CanvasLayer
var _settle_panel: PanelContainer
var _settle_label: Label
var _settle_button: Button


func _ready() -> void:
	# 기준 해상도 (창 크기가 달라도 이 크기 기준으로 확대·축소)
	get_tree().root.content_scale_size = UiConfig.BASE_SIZE
	var window: Window = get_window()
	if window.mode == Window.MODE_WINDOWED and window.size.x < UiConfig.BASE_SIZE.x:
		window.size = UiConfig.BASE_SIZE
		window.move_to_center()
	session = GameSession.new(fixed_seed)

	view = (load("res://ui/battle_view.gd") as GDScript).new()
	add_child(view)
	view.battle_finished.connect(_on_battle_finished)

	tooltip = (load("res://ui/widgets/tooltip.gd") as GDScript).new()
	add_child(tooltip)

	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 5
	add_child(_ui_layer)

	# 연병장 = 배치 화면 (뒤쪽 연병장 칸을 직접 클릭해 배치)
	var barracks: Control = _make_screen("barracks", "res://ui/barracks_ui.gd")
	barracks.connect("roll_requested", func() -> void: show_screen("roll"))
	barracks.connect("shop_requested", func() -> void: show_screen("shop"))
	barracks.connect("battle_requested", _on_battle_requested)

	var roll: Control = _make_screen("roll", "res://ui/roll_ui.gd")
	roll.connect("placement_requested", func() -> void: show_screen("barracks"))

	var shop: Control = _make_screen("shop", "res://ui/shop_ui.gd")
	shop.connect("back_requested", func() -> void: show_screen("barracks"))

	_build_settle_panel()

	_top_layer = CanvasLayer.new()
	_top_layer.layer = 6
	add_child(_top_layer)
	top_bar = (load("res://ui/top_bar.gd") as GDScript).new()
	top_bar.set("session", session)
	top_bar.connect("screen_requested", show_screen)
	_top_layer.add_child(top_bar)

	session.board.board_changed.connect(_refresh_preview)
	session.phase_changed.connect(_on_phase_changed)
	session.timer.expired.connect(_on_timer_expired)
	show_screen("barracks")


func _make_screen(key: String, path: String) -> Control:
	var s: Control = (load(path) as GDScript).new()
	s.set("session", session)
	s.set("tooltip", tooltip)
	s.set("view", view)
	screens[key] = s
	_ui_layer.add_child(s)
	return s


func _process(delta: float) -> void:
	if session.is_preparing():
		session.timer.tick(delta)


## 준비 화면 전환 (연병장(=배치) / 주사위 / 상점)
func show_screen(key: String) -> void:
	if not session.is_preparing():
		return
	current_screen = key
	if key == "roll":
		session.go_to_rolling()
	elif key == "barracks":
		session.go_to_barracks()
	current_screen = key
	tooltip.call("hide_tip")
	for k: String in screens.keys():
		(screens[k] as Control).visible = k == key
	_settle_panel.visible = false
	top_bar.visible = true
	top_bar.set("current_screen", key)
	# 연병장 칸 클릭은 연병장 화면에서만
	view.set("pick_enabled", key == "barracks")
	if key == "barracks":
		_refresh_preview()
	if screens[key].has_method("refresh"):
		screens[key].call("refresh")


func _on_phase_changed(p: GameSession.Phase) -> void:
	match p:
		GameSession.Phase.BATTLE:
			for k: String in screens.keys():
				(screens[k] as Control).visible = false
			top_bar.visible = false
			view.set("pick_enabled", false)
			tooltip.call("hide_tip")
		GameSession.Phase.BARRACKS:
			if current_screen != "barracks" and current_screen != "shop":
				show_screen("barracks")


## 준비·배치 중: 연병장에 현재 병력을 정렬해 보여 준다
func _refresh_preview() -> void:
	if not session.is_preparing():
		return
	var preview: BattleSimulation = BattleSimulation.new()
	preview.setup([session.board.get_spawn_packets(), []], 1)
	view.call("show_preview", preview, 0)


func _on_battle_requested() -> void:
	var sim: BattleSimulation = session.start_battle()
	if sim != null:
		view.call("start_battle", sim, 0)


## 준비 시간 만료: 자동 굴림·기록·배치 후 전투
func _on_timer_expired() -> void:
	var sim: BattleSimulation = session.auto_finalize()
	if sim != null:
		view.call("start_battle", sim, 0)


func _on_battle_finished(_result: BattleResult) -> void:
	var summary: Dictionary = session.settle_battle()
	_show_settlement(summary)


# =========================================================================
# 정산 패널
# =========================================================================

func _build_settle_panel() -> void:
	_settle_panel = UiKit.panel(Color(0.08, 0.09, 0.12, 0.95), UiKit.COLOR_ACCENT)
	_settle_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settle_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_settle_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_settle_panel.visible = false
	_ui_layer.add_child(_settle_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_settle_panel.add_child(box)
	_settle_label = UiKit.label("", 17)
	box.add_child(_settle_label)
	_settle_button = UiKit.button("유닛배치로", 18)
	_settle_button.pressed.connect(_on_settle_confirmed)
	box.add_child(_settle_button)


func _show_settlement(summary: Dictionary) -> void:
	var lines: PackedStringArray = []
	var won: bool = summary.get("winner", -1) == 0
	lines.append("%dR 정산 — %s" % [summary.get("round", 0), "승리" if won else ("패배" if summary.get("winner", -1) == 1 else "무승부")])
	if won:
		lines.append("승리 보너스  +%s원" % NumberFormatter.format_num(summary["win_bonus"]))
		if summary["streak_bonus"] > 0:
			lines.append("%d연승 보상  +%s원" % [session.streak.win_streak, NumberFormatter.format_num(summary["streak_bonus"])])
		lines.append("소비칸 생존 %s명 판매  +%s원" % [NumberFormatter.format_num(summary["sale_count"]), NumberFormatter.format_num(summary["sale_gold"])])
	elif summary.get("winner", -1) == 1:
		var dmg_text: String = "피해  -%d" % summary["damage"]
		if summary["damage_raw"] > summary["damage"]:
			dmg_text += "  (적 생존 %d명, 라운드 상한 적용)" % summary["damage_raw"]
		lines.append(dmg_text)
		if summary.get("shield_absorbed", 0) > 0:
			lines.append("성벽 실드가 %d 막음 → 체력 -%d" % [summary["shield_absorbed"], summary["hp_damage"]])
		if summary["streak_bonus"] > 0:
			lines.append("%d연패 보상  +%s원" % [session.streak.loss_streak, NumberFormatter.format_num(summary["streak_bonus"])])
		lines.append("소비칸 병력은 사라졌습니다.")
	lines.append("")
	lines.append("골드 %s · 체력 %d / %d" % [NumberFormatter.format_num(session.player.gold), session.player.hp, session.player.max_hp])
	if session.phase == GameSession.Phase.GAME_OVER:
		lines.append("")
		lines.append("★ 15라운드 클리어! ★" if session.player.hp > 0 and won else "게임 오버")
		_settle_button.text = "처음부터 다시"
	else:
		_settle_button.text = "유닛배치로 (%dR)" % session.get_round()
	_settle_label.text = "\n".join(lines)
	_settle_panel.visible = true


func _on_settle_confirmed() -> void:
	if session.phase == GameSession.Phase.GAME_OVER:
		get_tree().reload_current_scene()
		return
	current_screen = ""
	session.return_to_barracks()
	show_screen("barracks")
