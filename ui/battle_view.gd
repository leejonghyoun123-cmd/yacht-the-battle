extends Node2D
## 전투 화면 (프로토타입: 도형으로 표현, 아트는 나중에 교체).
## BattleSimulation(순수 로직)을 받아 그리기만 한다. 시뮬레이션 결과에는 영향을 주지 않는다.
##
## 연출 순서: 내 연병장 비춤 → 카메라가 중앙 필드로 이동 → 양측 문 열림
##          → 달려나와 진열(DEPLOY) → 3초 후 호각 → 교전 → 결과
## 화면 규칙: 아이소메트릭 바닥 + 탑뷰 유닛. 보는 사람(viewer_team)의 진영이 항상 좌측 위.
## 배속은 프레임당 시뮬레이션 step 횟수로 처리한다 (Engine.time_scale 미사용 → 결과 동일 보장).

signal battle_finished(result: BattleResult)

enum ViewState { IDLE, INTRO_CAMERA, OPEN_GATES, RUNNING, RESULT }

const CAMERA_MOVE_TIME: float = 1.6
const GATE_OPEN_TIME: float = 0.7
const INTRO_HOLD_TIME: float = 0.8
## 양쪽 연병장 문까지 보이도록 (문에서 몰려나오는 장면 포함)
const FIELD_ZOOM: float = 0.55
const BARRACKS_ZOOM: float = 1.0
const BARRACKS_SCREEN_SHIFT: Vector2 = Vector2(-230.0, 0.0)
const MAX_EFFECTS: int = 400

const COLOR_GROUND: Color = Color("2e3a2c")
const COLOR_FIELD: Color = Color("3d4a37")
const COLOR_GRID: Color = Color(1, 1, 1, 0.08)
const COLOR_STACK_CELL: Color = Color(0.95, 0.78, 0.3, 0.16)
const COLOR_CONSUME_CELL: Color = Color(0.55, 0.75, 1.0, 0.10)
const COLOR_BARRACKS: Color = Color("4a3b2c")
const COLOR_WALL: Color = Color("6b553d")
const COLOR_GATE: Color = Color("8a5a2b")
const TEAM_COLORS: Array[Color] = [Color("5ec8ff"), Color("ff5e5e")]
const TIER_COLORS: Array[Color] = [Color.TRANSPARENT, Color("d0d6e2"), Color("ffcc33"), Color("ff4040")]

## 이 화면을 보는 플레이어의 팀 (멀티에서 상대는 1 → 좌표를 뒤집어 자기 진영이 좌상단)
var viewer_team: int = 0
var speed: int = 1
var sim: BattleSimulation
var view_state: ViewState = ViewState.IDLE

var _camera: Camera2D
var _floor: Node2D
var _effects: Array[Dictionary] = []
var _sim_accumulator: float = 0.0
var _state_time: float = 0.0
var _gate_open: float = 0.0
var _whistle_flash: float = 0.0

# HUD
var _hud_layer: CanvasLayer
var _hud_label: Label
var _phase_label: Label
var _speed_buttons: Array[Button] = []
var _result_panel: PanelContainer
var _result_label: Label


func _ready() -> void:
	_floor = Node2D.new()
	_floor.z_index = -10
	_floor.draw.connect(_draw_floor.bind(_floor))
	add_child(_floor)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_build_hud()
	_focus_barracks()


## 전투 시작. 연출이 끝나면 battle_finished가 발생한다.
func start_battle(simulation: BattleSimulation, p_viewer_team: int = 0) -> void:
	sim = simulation
	viewer_team = p_viewer_team
	_effects.clear()
	_sim_accumulator = 0.0
	_gate_open = 0.0
	_result_panel.visible = false
	_floor.queue_redraw()
	_focus_barracks()
	set_hud_visible(true)
	_set_state(ViewState.INTRO_CAMERA)
	_kill_intro_tween()
	var tween: Tween = create_tween()
	_intro_tween = tween
	tween.tween_interval(INTRO_HOLD_TIME)
	tween.tween_property(_camera, "position", Vector2.ZERO, CAMERA_MOVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_camera, "zoom", Vector2.ONE * FIELD_ZOOM, CAMERA_MOVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: _set_state(ViewState.OPEN_GATES))


## 준비 단계: 전투를 돌리지 않고 연병장에 모인 병력만 보여 준다 (HUD 숨김)
func show_preview(simulation: BattleSimulation, p_viewer_team: int = 0) -> void:
	sim = simulation
	viewer_team = p_viewer_team
	_effects.clear()
	_gate_open = 0.0
	_result_panel.visible = false
	_kill_intro_tween()
	_set_state(ViewState.IDLE)
	set_hud_visible(false)
	_floor.queue_redraw()
	_focus_barracks()


var _intro_tween: Tween = null


func _kill_intro_tween() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = null


func set_hud_visible(value: bool) -> void:
	if _hud_layer != null:
		_hud_layer.visible = value


## 연병장(내 진영 문 쪽) 비추기 — 준비 단계 화면에서도 사용
func _focus_barracks() -> void:
	if _camera == null:
		return
	# 왼쪽 준비 UI 패널에 가리지 않도록 연병장을 화면 오른쪽으로 조금 비켜 보여 준다
	_camera.position = to_screen(BattleSimulation.barracks_center(viewer_team)) + BARRACKS_SCREEN_SHIFT
	_camera.zoom = Vector2.ONE * BARRACKS_ZOOM


func set_speed(value: int) -> void:
	speed = value
	for b: Button in _speed_buttons:
		b.button_pressed = b.get_meta("speed") == value


## 스킵: 연출 상관없이 즉시 끝까지 계산 (결과는 실시간과 동일)
func skip_to_end() -> void:
	if sim == null or view_state == ViewState.RESULT or view_state == ViewState.IDLE:
		return
	# 진행 중인 카메라 연출을 멈춰야 나중에 연출 콜백이 전투 상태를 다시 바꾸지 않는다
	_kill_intro_tween()
	_camera.position = Vector2.ZERO
	_camera.zoom = Vector2.ONE * FIELD_ZOOM
	_gate_open = 1.0
	sim.run_to_end()
	_effects.clear()
	_show_result()


# =========================================================================
# 진행
# =========================================================================

func _set_state(s: ViewState) -> void:
	view_state = s
	_state_time = 0.0


func _process(delta: float) -> void:
	_state_time += delta
	_whistle_flash = maxf(0.0, _whistle_flash - delta)
	match view_state:
		ViewState.OPEN_GATES:
			_gate_open = clampf(_state_time / GATE_OPEN_TIME, 0.0, 1.0)
			_floor.queue_redraw()
			if _gate_open >= 1.0:
				_set_state(ViewState.RUNNING)
		ViewState.RUNNING:
			_run_simulation(delta)
	_update_effects(delta)
	_update_hud()
	queue_redraw()


func _run_simulation(delta: float) -> void:
	_sim_accumulator += delta * float(speed)
	var steps: int = 0
	while _sim_accumulator >= BattleRules.SIM_DT and steps < 16:
		_sim_accumulator -= BattleRules.SIM_DT
		sim.step()
		_consume_events()
		steps += 1
		if sim.is_finished():
			_show_result()
			return


func _consume_events() -> void:
	for e: Dictionary in sim.events:
		match e["type"]:
			"attack":
				var attacker: BattleUnit = sim.units[e["from"]]
				var ranged: bool = attacker.data.attack_range > 40.0
				_add_effect({
					"kind": "shot" if ranged else "hit",
					"from": attacker.pos, "to": e["pos"], "life": 0.18 if ranged else 0.12,
					"color": attacker.data.color, "splash": e["splash"],
				})
				if float(e["splash"]) > 0.0:
					_add_effect({ "kind": "boom", "to": e["pos"], "life": 0.35, "radius": e["splash"] })
			"death":
				_add_effect({ "kind": "death", "to": e["pos"], "life": 0.6 })
			"whistle":
				_whistle_flash = 1.2


func _add_effect(effect: Dictionary) -> void:
	if _effects.size() >= MAX_EFFECTS:
		return
	effect["age"] = 0.0
	_effects.append(effect)


func _update_effects(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for e: Dictionary in _effects:
		e["age"] = float(e["age"]) + delta * float(maxi(1, speed))
		if e["age"] < e["life"]:
			kept.append(e)
	_effects = kept


# =========================================================================
# 좌표 변환
# =========================================================================

## 논리 좌표 → 화면 좌표 (아이소). 보는 사람의 진영이 좌측 위에 오도록 상대 시점이면 뒤집는다.
func to_screen(p: Vector2) -> Vector2:
	var q: Vector2 = p if viewer_team == 0 else -p
	return Vector2(q.x - q.y, (q.x + q.y) * 0.5)


func _rect_points(center: Vector2, half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		to_screen(center + Vector2(-half.x, -half.y)),
		to_screen(center + Vector2(half.x, -half.y)),
		to_screen(center + Vector2(half.x, half.y)),
		to_screen(center + Vector2(-half.x, half.y)),
	])


# =========================================================================
# 그리기
# =========================================================================

func _draw_floor(canvas: Node2D) -> void:
	canvas.draw_colored_polygon(_rect_points(Vector2.ZERO, Vector2(1000.0, 330.0)), COLOR_GROUND)
	canvas.draw_colored_polygon(_rect_points(Vector2.ZERO, Vector2(470.0, 210.0)), COLOR_FIELD)
	# 필드 격자
	for i: int in range(-9, 10):
		var x: float = float(i) * 50.0
		canvas.draw_line(to_screen(Vector2(x, -210.0)), to_screen(Vector2(x, 210.0)), COLOR_GRID, 1.0)
	for j: int in range(-4, 5):
		var y: float = float(j) * 50.0
		canvas.draw_line(to_screen(Vector2(-470.0, y)), to_screen(Vector2(470.0, y)), COLOR_GRID, 1.0)
	# 양 팀 배치판 3x3 (가운데 줄 = 중첩칸 금색, 양옆 = 소비칸 파란색)
	var half_cell: float = BattleSimulation.CELL_SIZE * 0.5 - 3.0
	for team: int in range(2):
		for idx: int in range(BoardState.CELL_COUNT):
			var c: Vector2 = BattleSimulation.cell_center(team, idx)
			var is_stack: bool = BoardState.col_of(idx) == BoardState.STACK_COLUMN
			var pts: PackedVector2Array = _rect_points(c, Vector2(half_cell, half_cell))
			canvas.draw_colored_polygon(pts, COLOR_STACK_CELL if is_stack else COLOR_CONSUME_CELL)
			pts.append(pts[0])
			canvas.draw_polyline(pts, Color(TEAM_COLORS[team], 0.35), 1.5)
		_draw_barracks(canvas, team)


## 연병장(각 팀 문 뒤쪽 건물)과 문
func _draw_barracks(canvas: Node2D, team: int) -> void:
	var dir: float = BattleSimulation.team_direction(team)
	var gate: Vector2 = BattleSimulation.gate_position(team)
	var center: Vector2 = BattleSimulation.barracks_center(team)
	var half: float = BattleSimulation.BARRACKS_HALF
	canvas.draw_colored_polygon(_rect_points(center, Vector2(half, half)), COLOR_BARRACKS)
	# 연병장 바닥 3x3 (필드 배치판과 같은 칸 배치 — 병력이 이 자리에 정렬해 서 있다)
	var half_cell: float = BattleSimulation.CELL_SIZE * 0.5 - 3.0
	for idx: int in range(BoardState.CELL_COUNT):
		var cc: Vector2 = BattleSimulation.barracks_cell_center(team, idx)
		var is_stack: bool = BoardState.col_of(idx) == BoardState.STACK_COLUMN
		var p: PackedVector2Array = _rect_points(cc, Vector2(half_cell, half_cell))
		canvas.draw_colored_polygon(p, COLOR_STACK_CELL if is_stack else COLOR_CONSUME_CELL)
		p.append(p[0])
		canvas.draw_polyline(p, Color(1, 1, 1, 0.15), 1.0)
	# 벽: 뒤·양옆 + 앞면(가운데 좁은 문만 비움)
	var back: float = center.x - half * dir
	var gw: float = BattleSimulation.GATE_HALF_WIDTH
	var wall: PackedVector2Array = PackedVector2Array([
		to_screen(Vector2(gate.x, -gw)), to_screen(Vector2(gate.x, -half)), to_screen(Vector2(back, -half)),
		to_screen(Vector2(back, half)), to_screen(Vector2(gate.x, half)), to_screen(Vector2(gate.x, gw)),
	])
	canvas.draw_polyline(wall, COLOR_WALL, 7.0)
	# 문: 좁은 두 짝 문. 닫힘 → 양옆으로 밀려 열림
	var door: float = gw * (1.0 - _gate_open)
	var gate_color: Color = COLOR_GATE.lerp(Color(COLOR_GATE, 0.25), _gate_open)
	canvas.draw_line(to_screen(gate + Vector2(0.0, -gw)), to_screen(gate + Vector2(0.0, -gw + door)), gate_color, 9.0)
	canvas.draw_line(to_screen(gate + Vector2(0.0, gw)), to_screen(gate + Vector2(0.0, gw - door)), gate_color, 9.0)
	canvas.draw_circle(to_screen(gate + Vector2(0.0, -gw - 8.0)), 10.0, COLOR_WALL)
	canvas.draw_circle(to_screen(gate + Vector2(0.0, gw + 8.0)), 10.0, COLOR_WALL)


func _draw() -> void:
	if sim == null:
		return
	var deploying: bool = view_state == ViewState.INTRO_CAMERA or view_state == ViewState.OPEN_GATES
	# 정예 오라 (뒤쪽 레이어)
	for u: BattleUnit in sim.units:
		if u.alive and u.tier >= 2:
			var aura: Color = TIER_COLORS[u.tier - 1]
			draw_circle(to_screen(u.pos), u.radius * 1.9, Color(aura, 0.22))
	# 유닛 본체: 병과 색 + 팀 색 테두리 (+ 티어 색 고리)
	for u: BattleUnit in sim.units:
		if not u.alive:
			continue
		if deploying and u.pos.distance_squared_to(u.home) > 1.0 and not _inside_barracks(u):
			continue
		var p: Vector2 = to_screen(u.pos)
		draw_circle(p, u.radius, u.data.color)
		draw_arc(p, u.radius + 1.0, 0.0, TAU, 16, TEAM_COLORS[u.team], 2.0)
		if u.tier >= 2:
			draw_arc(p, u.radius + 3.5, 0.0, TAU, 20, TIER_COLORS[u.tier - 1], 2.0)
		if u.data.is_giant or u.ratio >= 15.0:
			_draw_hp_bar(p + Vector2(0.0, -u.radius - 7.0), u.radius * 2.2, u.hp / u.max_hp, u.team)
	# 공격·사망 이펙트
	for e: Dictionary in _effects:
		var t: float = float(e["age"]) / float(e["life"])
		match e["kind"]:
			"shot":
				var a: Vector2 = to_screen(e["from"])
				var b: Vector2 = to_screen(e["to"])
				var head: Vector2 = a.lerp(b, minf(1.0, t * 1.4))
				draw_line(head.lerp(a, 0.15), head, Color(e["color"], 1.0 - t), 2.0)
			"hit":
				draw_circle(to_screen(e["to"]), 3.0, Color(1, 1, 1, 0.8 * (1.0 - t)))
			"boom":
				var r: float = float(e["radius"]) * (0.4 + t * 0.8)
				draw_circle(to_screen(e["to"]), r, Color(1.0, 0.6, 0.2, 0.35 * (1.0 - t)))
			"death":
				var dp: Vector2 = to_screen(e["to"])
				var s: float = 4.0
				var c: Color = Color(1, 0.3, 0.3, 0.8 * (1.0 - t))
				draw_line(dp + Vector2(-s, -s), dp + Vector2(s, s), c, 1.5)
				draw_line(dp + Vector2(-s, s), dp + Vector2(s, -s), c, 1.5)


## 연출 중(문 열리기 전)에는 연병장 안 유닛만 보여 준다
func _inside_barracks(u: BattleUnit) -> bool:
	var gate_x: float = BattleSimulation.gate_position(u.team).x
	return (u.pos.x - gate_x) * BattleSimulation.team_direction(u.team) <= 0.0


func _draw_hp_bar(center: Vector2, width: float, ratio: float, team: int) -> void:
	var left: Vector2 = center - Vector2(width * 0.5, 0.0)
	draw_rect(Rect2(left, Vector2(width, 3.0)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(left, Vector2(width * clampf(ratio, 0.0, 1.0), 3.0)), TEAM_COLORS[team])


# =========================================================================
# HUD
# =========================================================================

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	_hud_layer = layer
	add_child(layer)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var info: VBoxContainer = VBoxContainer.new()
	info.position = Vector2(12, 10)
	root.add_child(info)
	_phase_label = _label("", 22, Color("f2c14e"))
	_hud_label = _label("", 15, Color.WHITE)
	info.add_child(_phase_label)
	info.add_child(_hud_label)

	var speed_box: HBoxContainer = HBoxContainer.new()
	speed_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	speed_box.position = Vector2(-320, 10)
	speed_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(speed_box)
	for s: int in [1, 2, 4]:
		var b: Button = Button.new()
		b.text = "%d배속" % s
		b.toggle_mode = true
		b.button_pressed = s == speed
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("speed", s)
		b.pressed.connect(set_speed.bind(s))
		speed_box.add_child(b)
		_speed_buttons.append(b)
	var skip: Button = Button.new()
	skip.text = "전투 스킵 ▶▶"
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(skip_to_end)
	speed_box.add_child(skip)

	_result_panel = PanelContainer.new()
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	style.border_color = Color("f2c14e")
	style.set_border_width_all(2)
	_result_panel.add_theme_stylebox_override("panel", style)
	_result_panel.visible = false
	root.add_child(_result_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_result_panel.add_child(box)
	_result_label = _label("", 20, Color.WHITE)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_label)
	var ok: Button = Button.new()
	ok.text = "확인"
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(func() -> void:
		_result_panel.visible = false
		battle_finished.emit(sim.result))
	box.add_child(ok)


func _update_hud() -> void:
	if view_state == ViewState.IDLE:
		return
	if sim == null:
		_phase_label.text = "연병장"
		_hud_label.text = ""
		return
	var totals: Array[float] = [0.0, 0.0]
	for u: BattleUnit in sim.units:
		if u.alive:
			totals[u.team] += u.ratio
	var mine: int = viewer_team
	var theirs: int = 1 - viewer_team
	_hud_label.text = "아군 %s명   vs   적군 %s명 (환산)" % [
		NumberFormatter.format_num(roundf(totals[mine])), NumberFormatter.format_num(roundf(totals[theirs]))]
	match view_state:
		ViewState.INTRO_CAMERA:
			_phase_label.text = "연병장 → 전장으로"
		ViewState.OPEN_GATES:
			_phase_label.text = "문이 열린다!"
		ViewState.RUNNING, ViewState.RESULT:
			match sim.phase:
				BattleSimulation.Phase.DEPLOY:
					_phase_label.text = "진열 중…"
				BattleSimulation.Phase.WHISTLE:
					_phase_label.text = "호각까지 %.1f초" % maxf(0.0, BattleRules.WHISTLE_DELAY - sim.phase_time)
				BattleSimulation.Phase.FIGHT:
					_phase_label.text = ("호각! 돌격!" if _whistle_flash > 0.0 else "교전 %.1f초 / %d초" % [sim.phase_time, int(BattleRules.FIGHT_TIME_LIMIT)])
				BattleSimulation.Phase.ENDED:
					_phase_label.text = "전투 종료"


func _show_result() -> void:
	_set_state(ViewState.RESULT)
	var r: BattleResult = sim.result
	var title: String = "무승부"
	if r.winner == viewer_team:
		title = "승리!"
	elif r.winner != BattleResult.DRAW:
		title = "패배…"
	var reason: String = "전멸" if r.reason == "annihilation" else "시간 초과 (남은 체력 비교)"
	_result_label.text = "%s\n%s · 교전 %.1f초\n생존 환산 인원  아군 %s명 / 적군 %s명" % [
		title, reason, r.fight_duration,
		NumberFormatter.format_num(r.get_survivor_total(viewer_team)),
		NumberFormatter.format_num(r.get_survivor_total(1 - viewer_team))]
	_result_panel.visible = true


func _label(text: String, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l
