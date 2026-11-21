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
## 유닛배치장을 화면 중앙에 (상단 바와 아래 주사위 바 사이 가운데가 되도록 살짝 위로)
const BARRACKS_SCREEN_SHIFT: Vector2 = Vector2(0.0, 45.0)
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
	_damage_number_count = 0
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
	_damage_number_count = 0
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
	# 유닛배치장을 화면 중앙에 보여 준다
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
	_damage_number_count = 0
	_show_result()


# =========================================================================
# 진행
# =========================================================================

func _set_state(s: ViewState) -> void:
	view_state = s
	_state_time = 0.0


func _process(delta: float) -> void:
	_state_time += delta
	_anim_time += delta * float(maxi(1, speed))
	_tick_spawn_anims(delta)
	_whistle_flash = maxf(0.0, _whistle_flash - delta)
	_tarot_banner_time = maxf(0.0, _tarot_banner_time - delta)
	if _tarot_banner_time <= 0.0:
		_tarot_banner = ""
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
				var ranged: bool = attacker.attack_range > 40.0
				_add_effect({
					"kind": "shot" if ranged else "hit",
					"from": attacker.pos, "to": e["pos"], "life": 0.18 if ranged else 0.12,
					"color": attacker.data.color, "splash": e["splash"],
				})
				if float(e["splash"]) > 0.0:
					_add_effect({ "kind": "boom", "to": e["pos"], "life": 0.35, "radius": e["splash"] })
			"damage":
				_add_damage_number(e)
			"death":
				_add_effect({ "kind": "death", "to": e["pos"], "life": 0.6 })
			"whistle":
				_whistle_flash = 1.2
			"tarot":
				_tarot_banner = "타로 발동: " + String(e["name"]) if _tarot_banner == "" else _tarot_banner + " · " + String(e["name"])
				_tarot_banner_time = 2.5
			"tarot_blast":
				_add_effect({ "kind": "tarot_" + String(e["kind"]), "to": e["pos"], "radius": e["radius"], "life": 0.9 if e["kind"] == "sun" else 0.45 })
			"zap":
				_add_effect({ "kind": "zap", "from": e["from"], "to": e["to"], "life": 0.25 })


func _add_effect(effect: Dictionary) -> void:
	if _effects.size() >= MAX_EFFECTS:
		return
	effect["age"] = 0.0
	_effects.append(effect)


## 데미지 숫자: 화면이 숫자로 뒤덮이지 않도록 동시에 떠 있는 개수를 제한하고, 같은 대상은 잠깐 합쳐 띄운다
const MAX_DAMAGE_NUMBERS: int = 70
const DAMAGE_NUMBER_LIFE: float = 0.75
## 위로 튀어 오르는 높이 (화면 px, 줌 보정 전)
const DAMAGE_NUMBER_RISE: float = 30.0
var _damage_number_count: int = 0


func _add_damage_number(e: Dictionary) -> void:
	var amount: float = float(e["amount"])
	if amount < 0.05:
		return
	# 같은 대상에 막 뜬 숫자가 있으면 합친다 (광역·연타가 숫자 폭탄이 되지 않게)
	for d: Dictionary in _effects:
		if d["kind"] == "dmg" and int(d["id"]) == int(e["id"]) and float(d["age"]) < 0.12:
			d["amount"] = float(d["amount"]) + amount
			return
	if _damage_number_count >= MAX_DAMAGE_NUMBERS:
		return
	_damage_number_count += 1
	# 겹침을 줄이기 위해 좌우로 조금 흩뿌린다 (화면 전용 값, 시뮬레이션과 무관)
	var jitter: float = float((int(e["id"]) * 37 + _damage_number_count * 11) % 17) - 8.0
	_add_effect({
		"kind": "dmg", "id": e["id"], "to": e["pos"], "life": DAMAGE_NUMBER_LIFE,
		"amount": amount, "ally": int(e["team"]) == viewer_team, "jitter": jitter,
	})


func _update_effects(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for e: Dictionary in _effects:
		e["age"] = float(e["age"]) + delta * float(maxi(1, speed))
		if e["age"] < e["life"]:
			kept.append(e)
		elif e["kind"] == "dmg":
			_damage_number_count -= 1
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
	# 양 팀 배치판 3x3 (중첩칸 금색, 소비칸 파란색 — 기본은 9칸 모두 중첩칸)
	var half_cell: float = BattleSimulation.CELL_SIZE * 0.5 - 3.0
	for team: int in range(2):
		for idx: int in range(BoardState.CELL_COUNT):
			var c: Vector2 = BattleSimulation.cell_center(team, idx)
			var is_stack: bool = BoardState.is_stack_index(idx)
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
		var is_stack: bool = BoardState.is_stack_index(idx)
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


## 화면 전용 애니메이션 시계 (걷기·흔들림. 시뮬레이션과 무관)
var _anim_time: float = 0.0


## 바라보는 방향: 노리는 적이 있으면 그쪽, 없으면 상대 진영 쪽 (화면 기준 +1 = 오른쪽)
func _facing(u: BattleUnit, p: Vector2) -> float:
	if u.target != null and u.target.alive:
		var dx: float = to_screen(u.target.pos).x - p.x
		if absf(dx) > 0.5:
			return signf(dx)
	return 1.0 if u.team == viewer_team else -1.0


## 발밑 타원 고리 (정예 티어 표시)
func _draw_foot_ring(p: Vector2, r: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(17):
		var a: float = TAU * float(i) / 16.0
		pts.append(p + Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_polyline(pts, color, 2.0)


## 데미지 숫자: 위로 빠르게 튀었다가 느려지며 사라진다 (ease-out + 후반 페이드)
func _draw_damage_numbers() -> void:
	var font: Font = ThemeDB.fallback_font
	var zoom: float = maxf(0.2, _camera.zoom.x)
	var fs: int = int(round(16.0 / zoom))
	for e: Dictionary in _effects:
		if e["kind"] != "dmg":
			continue
		var t: float = float(e["age"]) / float(e["life"])
		var rise: float = 1.0 - pow(1.0 - t, 3.0)
		var alpha: float = 1.0 if t < 0.55 else 1.0 - (t - 0.55) / 0.45
		var base: Vector2 = to_screen(e["to"])
		var pos: Vector2 = base + Vector2(float(e["jitter"]), -12.0 - DAMAGE_NUMBER_RISE * rise) / zoom * 0.6
		var text: String = NumberFormatter.format_num(int(round(float(e["amount"]))))
		if text == "0":
			text = "1"
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var col: Color = Color(1.0, 0.45, 0.4, alpha) if bool(e["ally"]) else Color(1.0, 0.95, 0.7, alpha)
		var at: Vector2 = pos + Vector2(-w * 0.5, 0.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(3.0 / zoom * 0.6)), Color(0, 0, 0, 0.85 * alpha))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw() -> void:
	if sim == null:
		return
	var deploying: bool = view_state == ViewState.INTRO_CAMERA or view_state == ViewState.OPEN_GATES
	# 정예 오라 (뒤쪽 레이어, 발밑)
	for u: BattleUnit in sim.units:
		if u.alive and u.tier >= 2:
			var aura: Color = TIER_COLORS[u.tier - 1]
			draw_circle(to_screen(_spawn_display_pos(u)), u.radius * 1.9, Color(aura, 0.22))
	# 킹 장판 (바닥에 금빛 원, 은은하게 맥동)
	for u: BattleUnit in sim.units:
		if u.alive and u.data.is_unique and u.support_radius > 0.0:
			var center: Vector2 = _spawn_display_pos(u)
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in range(33):
				var a: float = TAU * float(i) / 32.0
				pts.append(to_screen(center + Vector2(cos(a), sin(a)) * u.support_radius))
			var pulse: float = 0.5 + 0.5 * sin(_anim_time * 3.0)
			draw_colored_polygon(pts, Color(1.0, 0.82, 0.25, 0.07 + 0.04 * pulse))
			draw_polyline(pts, Color(1.0, 0.85, 0.3, 0.45 + 0.25 * pulse), 2.0)
	# 유닛 본체: 스틱맨 (화면 아래쪽 유닛이 앞에 오도록 화면 y 순서로 그린다)
	var drawn: Array[BattleUnit] = []
	for u: BattleUnit in sim.units:
		if not u.alive:
			continue
		if deploying and u.pos.distance_squared_to(u.home) > 1.0 and not _inside_barracks(u):
			continue
		drawn.append(u)
	drawn.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return to_screen(a.pos).y < to_screen(b.pos).y)
	for u: BattleUnit in drawn:
		var p: Vector2 = to_screen(_spawn_display_pos(u))
		if u.tier >= 2:
			_draw_foot_ring(p, u.radius + 3.0, TIER_COLORS[u.tier - 1])
		var top: float = UnitFigure.draw(self, p, u, _facing(u, p), _anim_time, TEAM_COLORS[u.team])
		if u.data.is_giant or u.ratio >= 15.0:
			_draw_hp_bar(Vector2(p.x, top - 5.0), u.radius * 2.4, u.hp / u.max_hp, u.team)
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
	_draw_tarot_effects()
	_draw_damage_numbers()
	# 준비 단계: 칸 강조·이름표 (유닛 위에 겹쳐도 읽히도록 외곽선 글씨)
	_draw_barracks_overlay()
	_draw_spawn_bursts()


# =========================================================================
# 연병장 배치 (준비 단계: 연병장 칸을 직접 클릭해 유닛을 배치)
# =========================================================================

signal barracks_cell_clicked(cell_index: int)
signal barracks_cell_hovered(cell_index: int)

enum CellMark { NONE, PLACEABLE, REPLACE, BLOCKED }

## 칸 클릭 허용 (준비 화면에서만 켠다)
var pick_enabled: bool = false
var _cell_labels: Array[String] = []
var _cell_marks: Array[int] = []
var _hover_cell: int = -1


## 화면(UI)이 칸 표시 문구와 강조 상태를 넘겨준다 (뷰는 게임 규칙을 모른다)
func set_barracks_overlay(labels: Array[String], marks: Array[int]) -> void:
	_cell_labels = labels
	_cell_marks = marks
	queue_redraw()


## 칸 중심의 화면(UI) 좌표 — 주사위가 칸으로 날아가는 연출용
func cell_screen_position(cell_index: int) -> Vector2:
	return get_viewport().get_canvas_transform() * to_screen(BattleSimulation.barracks_cell_center(viewer_team, cell_index))


const SPAWN_ANIM_TIME: float = 0.45
## 칸별 "팡!" 소환 연출 경과 시간
var _spawn_anims: Dictionary = {}


## 주사위가 칸에 떨어지면: 팡 터지며 유닛들이 칸 중심에서 각자 자리로 흩어진다
func play_cell_spawn(cell_index: int) -> void:
	_spawn_anims[cell_index] = 0.0
	queue_redraw()


func _tick_spawn_anims(delta: float) -> void:
	if _spawn_anims.is_empty():
		return
	for k: int in _spawn_anims.keys():
		_spawn_anims[k] = float(_spawn_anims[k]) + delta
		if _spawn_anims[k] > SPAWN_ANIM_TIME + 0.2:
			_spawn_anims.erase(k)
	queue_redraw()


## 소환 연출 중인 칸의 유닛 표시 위치 (칸 중심 → 자기 자리)
func _spawn_display_pos(u: BattleUnit) -> Vector2:
	if view_state != ViewState.IDLE or u.team != viewer_team or not _spawn_anims.has(u.cell_index):
		return u.pos
	var t: float = clampf(float(_spawn_anims[u.cell_index]) / SPAWN_ANIM_TIME, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	var center: Vector2 = BattleSimulation.barracks_cell_center(viewer_team, u.cell_index)
	return center.lerp(u.pos, eased)


func _draw_spawn_bursts() -> void:
	for k: int in _spawn_anims.keys():
		var t: float = clampf(float(_spawn_anims[k]) / SPAWN_ANIM_TIME, 0.0, 1.0)
		var c: Vector2 = to_screen(BattleSimulation.barracks_cell_center(viewer_team, k))
		var a: float = 1.0 - t
		draw_circle(c, 18.0 + 70.0 * t, Color(1.0, 0.9, 0.5, 0.35 * a))
		draw_arc(c, 18.0 + 80.0 * t, 0.0, TAU, 32, Color(1, 1, 1, 0.8 * a), 3.0)
		for i: int in range(10):
			var ang: float = TAU * float(i) / 10.0
			var r0: float = 20.0 + 60.0 * t
			var dir: Vector2 = Vector2(cos(ang), sin(ang) * 0.5)
			draw_line(c + dir * r0, c + dir * (r0 + 14.0), Color(1.0, 0.85, 0.4, a), 2.5)


## 화면 좌표(마우스) → 내 연병장 칸 번호 (-1 = 칸 밖)
func barracks_cell_at(world_pos: Vector2) -> int:
	var logical: Vector2 = Vector2((world_pos.x + 2.0 * world_pos.y) * 0.5, (2.0 * world_pos.y - world_pos.x) * 0.5)
	if viewer_team != 0:
		logical = -logical
	var half: float = BattleSimulation.CELL_SIZE * 0.5
	for idx: int in range(BoardState.CELL_COUNT):
		var c: Vector2 = BattleSimulation.barracks_cell_center(viewer_team, idx)
		if absf(logical.x - c.x) <= half and absf(logical.y - c.y) <= half:
			return idx
	return -1


func _unhandled_input(event: InputEvent) -> void:
	if not pick_enabled or view_state != ViewState.IDLE:
		return
	if event is InputEventMouseMotion:
		var h: int = barracks_cell_at(_event_world_pos(event as InputEventMouse))
		if h != _hover_cell:
			_hover_cell = h
			barracks_cell_hovered.emit(h)
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var cell: int = barracks_cell_at(_event_world_pos(mb))
			if cell >= 0:
				barracks_cell_clicked.emit(cell)
				get_viewport().set_input_as_handled()


func _draw_barracks_overlay() -> void:
	if view_state != ViewState.IDLE or _cell_labels.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var half: float = BattleSimulation.CELL_SIZE * 0.5 - 4.0
	for idx: int in range(BoardState.CELL_COUNT):
		var c: Vector2 = BattleSimulation.barracks_cell_center(viewer_team, idx)
		var mark: int = _cell_marks[idx] if idx < _cell_marks.size() else CellMark.NONE
		var outline: Color = Color.TRANSPARENT
		match mark:
			CellMark.PLACEABLE:
				outline = UiConfig.COLOR_TARGET
			CellMark.REPLACE:
				outline = Color("ff9a3c")
		if idx == _hover_cell and pick_enabled:
			outline = UiConfig.COLOR_SELECTED if outline.a == 0.0 else outline.lightened(0.3)
		if outline.a > 0.0:
			var pts: PackedVector2Array = _rect_points(c, Vector2(half, half))
			draw_colored_polygon(pts, Color(outline, 0.12))
			pts.append(pts[0])
			draw_polyline(pts, outline, 3.0)
		var text: String = _cell_labels[idx] if idx < _cell_labels.size() else ""
		if text == "":
			continue
		var p: Vector2 = to_screen(c + Vector2(-half * 0.55, -half * 0.55))
		var lines: PackedStringArray = text.split("\n")
		# 이름표: 병과 이름(흰색 크게) / 인원(노란색) — 두꺼운 외곽선으로 유닛 위에서도 잘 보이게
		for li: int in range(lines.size()):
			var fs: int = 19 if li == 0 else 17
			var col: Color = Color.WHITE if li == 0 else Color("ffe08a")
			var w: float = font.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos: Vector2 = p + Vector2(-w * 0.5, float(li) * 20.0)
			draw_string_outline(font, pos, lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.92))
			draw_string(font, pos, lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


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
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# 상단 한 줄: 왼쪽 = 라운드·골드·체력·병력 / 가운데 = 전투 진행·타이머 / 오른쪽 끝 = 배속·스킵
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	root.add_child(margin)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(top)

	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(info)
	var player_row: HBoxContainer = HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 6)
	info.add_child(player_row)
	_player_round_label = _label("", 16, Color.WHITE)
	player_row.add_child(_player_round_label)
	player_row.add_child((load("res://ui/widgets/stat_icon.gd") as GDScript).new().call("setup", "coin", 20.0))
	_player_gold_label = _label("", 16, Color("ffe08a"))
	player_row.add_child(_player_gold_label)
	player_row.add_child((load("res://ui/widgets/stat_icon.gd") as GDScript).new().call("setup", "heart", 20.0))
	_player_hp_gauge = (load("res://ui/widgets/hp_gauge.gd") as GDScript).new()
	_player_hp_gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	player_row.add_child(_player_hp_gauge)
	_hud_label = _label("", 15, Color.WHITE)
	info.add_child(_hud_label)

	_phase_label = _label("", 26, Color("f2c14e"))
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_phase_label)

	var speed_box: HBoxContainer = HBoxContainer.new()
	speed_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_box.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(speed_box)
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


var _player_round_label: Label
var _player_gold_label: Label
var _player_hp_gauge: Control


## 전투 화면 왼쪽 위 플레이어 정보 (GameRoot가 전투 시작 시 넘겨 준다)
func set_player_info(round_number: int, gold: int, hp: int, max_hp: int) -> void:
	if _player_round_label == null:
		return
	_player_round_label.text = "라운드 %d / %d" % [round_number, LevelTable.FINAL_ROUND]
	_player_gold_label.text = NumberFormatter.format_num(gold)
	_player_hp_gauge.call("set_values", hp, max_hp, 0)


func _update_hud() -> void:
	if view_state == ViewState.IDLE:
		return
	if sim == null:
		_phase_label.text = "유닛배치"
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
			_phase_label.text = "유닛배치 → 전장으로"
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
					if _tarot_banner_time > 0.0:
						_phase_label.text += "\n" + _tarot_banner
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
	if r.reason == "void":
		title = "전투 무효"
		reason = "더 월드 — 시간 정지"
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


## 입력 이벤트의 화면 좌표 → 월드 좌표 (카메라 반영). "현재 마우스 위치" 조회 대신 이벤트 좌표를 써서
## 리게임 직후 등 마우스 위치 갱신이 늦을 때 엉뚱한 칸이 눌리는 문제를 막는다.
func _event_world_pos(event: InputEventMouse) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * event.position


# =========================================================================
# 타로 연출 (별똥별·태양·번개·발동 알림)
# =========================================================================

var _tarot_banner: String = ""
var _tarot_banner_time: float = 0.0


func _draw_tarot_effects() -> void:
	for e: Dictionary in _effects:
		var t: float = float(e["age"]) / float(e["life"])
		match e["kind"]:
			"tarot_star":
				var p: Vector2 = to_screen(e["to"])
				var drop: Vector2 = p + Vector2(-60.0, -140.0) * (1.0 - minf(1.0, t * 2.5))
				draw_line(drop + Vector2(-18, -30), drop, Color(1.0, 0.95, 0.6, 0.9 * (1.0 - t)), 3.0)
				if t > 0.35:
					var k: float = (t - 0.35) / 0.65
					_draw_iso_ring(e["to"], float(e["radius"]) * (0.3 + 0.7 * k), Color(1.0, 0.9, 0.5, 0.6 * (1.0 - k)), 3.0)
			"tarot_sun":
				_draw_iso_ring(e["to"], float(e["radius"]), Color(1.0, 0.6, 0.15, 0.7 * (1.0 - t)), 4.0)
				_draw_iso_disc(e["to"], float(e["radius"]) * (0.4 + 0.6 * t), Color(1.0, 0.75, 0.2, 0.25 * (1.0 - t)))
			"tarot_world":
				draw_rect(Rect2(-5000, -5000, 10000, 10000), Color(0.6, 0.8, 1.0, 0.25 * (1.0 - t)))
			"zap":
				var a: Vector2 = to_screen(e["from"])
				var b: Vector2 = to_screen(e["to"])
				var pts: PackedVector2Array = PackedVector2Array([a])
				for i: int in range(1, 5):
					var mid: Vector2 = a.lerp(b, float(i) / 5.0)
					pts.append(mid + Vector2(sin(float(i) * 7.3 + _anim_time * 40.0), cos(float(i) * 5.1)) * 6.0)
				pts.append(b)
				draw_polyline(pts, Color(0.7, 0.9, 1.0, 1.0 - t), 2.5)
	# 진행 중 화염 (더 썬): 불붙은 유닛 발밑 주황 점
	if sim != null:
		for u: BattleUnit in sim.units:
			if u.alive and u.burn_time > 0.0:
				draw_circle(to_screen(u.pos) + Vector2(0, -u.radius), u.radius * 0.6, Color(1.0, 0.5, 0.1, 0.6))
			if u.alive and u.shield > 0.0:
				draw_arc(to_screen(u.pos) + Vector2(0, -u.radius * 1.6), u.radius * 1.9, 0.0, TAU, 14, Color(0.6, 0.85, 1.0, 0.55), 1.5)


func _draw_iso_ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(25):
		var a: float = TAU * float(i) / 24.0
		pts.append(to_screen(center + Vector2(cos(a), sin(a)) * radius))
	draw_polyline(pts, color, width)


func _draw_iso_disc(center: Vector2, radius: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(24):
		var a: float = TAU * float(i) / 24.0
		pts.append(to_screen(center + Vector2(cos(a), sin(a)) * radius))
	draw_colored_polygon(pts, color)
