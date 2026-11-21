extends Node
## 게임 전체 화면 흐름 (메인 씬 루트). 씬에는 루트 Node + 이 스크립트만 두면 된다.
##   연병장(준비) → 주사위 테이블(굴림·얏츠판) → 배치 → 전투 연출 → 정산 → 다음 라운드 연병장
## 로직은 GameSession, 화면 전환만 여기서 담당한다.

## 0이면 무작위 시드
@export var fixed_seed: int = 0

var session: GameSession
var view: Node2D
var barracks_ui: Control
var roll_ui: Control
var placement_ui: Control

var _ui_layer: CanvasLayer
var _settle_panel: PanelContainer
var _settle_label: Label
var _settle_button: Button


func _ready() -> void:
	session = GameSession.new(fixed_seed)

	view = (load("res://ui/battle_view.gd") as GDScript).new()
	add_child(view)
	view.battle_finished.connect(_on_battle_finished)

	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 5
	add_child(_ui_layer)

	barracks_ui = (load("res://ui/barracks_ui.gd") as GDScript).new()
	barracks_ui.set("session", session)
	barracks_ui.roll_requested.connect(func() -> void: session.go_to_rolling())
	_ui_layer.add_child(barracks_ui)

	roll_ui = (load("res://ui/prep_and_roll_ui.gd") as GDScript).new()
	roll_ui.set("flow", session.flow)
	roll_ui.set("integrated", true)
	roll_ui.proceed_requested.connect(_on_proceed_to_placement)
	_ui_layer.add_child(roll_ui)

	placement_ui = (load("res://ui/placement_ui.gd") as GDScript).new()
	placement_ui.set("session", session)
	placement_ui.battle_requested.connect(_on_battle_requested)
	_ui_layer.add_child(placement_ui)

	_build_settle_panel()
	session.board.board_changed.connect(_refresh_preview)
	session.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(session.phase)


func _on_phase_changed(p: GameSession.Phase) -> void:
	_settle_panel.visible = false
	barracks_ui.visible = p == GameSession.Phase.BARRACKS
	# 얏츠판을 기록하면 PLACEMENT가 되지만, 기록 결과를 확인하고 [배치하러 가기]를 누를 때까지 굴림 화면 유지
	roll_ui.visible = p == GameSession.Phase.ROLLING or p == GameSession.Phase.PLACEMENT
	placement_ui.visible = false
	if p == GameSession.Phase.BARRACKS:
		_refresh_preview()
		barracks_ui.call("refresh")


func _on_proceed_to_placement() -> void:
	roll_ui.visible = false
	placement_ui.visible = true
	_refresh_preview()
	placement_ui.call("refresh")


## 준비·배치 중: 연병장에 현재 병력을 모아 보여 준다
func _refresh_preview() -> void:
	if session.phase == GameSession.Phase.BATTLE:
		return
	var preview: BattleSimulation = BattleSimulation.new()
	preview.setup([session.board.get_spawn_packets(), []], 1)
	view.call("show_preview", preview, 0)


func _on_battle_requested() -> void:
	var sim: BattleSimulation = session.start_battle()
	if sim == null:
		return
	placement_ui.visible = false
	view.call("start_battle", sim, 0)


func _on_battle_finished(_result: BattleResult) -> void:
	var summary: Dictionary = session.settle_battle()
	_show_settlement(summary)


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
	_settle_button = UiKit.button("연병장으로", 18)
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
		var dmg_text: String = "체력 피해  -%d" % summary["damage"]
		if summary["damage_raw"] > summary["damage"]:
			dmg_text += "  (적 생존 %d명, 라운드 상한 적용)" % summary["damage_raw"]
		lines.append(dmg_text)
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
		_settle_button.text = "연병장으로 (%dR)" % session.get_round()
	_settle_label.text = "\n".join(lines)
	_settle_panel.visible = true


func _on_settle_confirmed() -> void:
	if session.phase == GameSession.Phase.GAME_OVER:
		get_tree().reload_current_scene()
		return
	session.return_to_barracks()
