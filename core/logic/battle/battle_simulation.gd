class_name BattleSimulation
extends RefCounted
## 결정론적 자동 전투 시뮬레이션 (화면·노드와 무관한 순수 로직).
## 고정 시간 간격(BattleRules.SIM_DT)으로만 진행하므로 같은 입력·시드면 항상 같은 결과가 나온다.
## → 배속은 프레임당 step 횟수를 늘리고, 스킵은 run_to_end()로 즉시 끝낸다. 멀티에서는 방장만 돌린다.
##
## 진행: DEPLOY(문에서 달려나와 진열) → WHISTLE(3초 대기 후 호각) → FIGHT(교전, 60초 제한) → ENDED
##
## 논리 좌표: 팀 0은 x < 0 쪽, 팀 1은 x > 0 쪽에 배치판이 있고 서로 마주 본다.
## 화면(아이소 변환, "내 진영은 항상 좌상단")은 뷰가 이 좌표를 변환해서 처리한다.

signal phase_changed(new_phase: Phase)
signal battle_ended(result: BattleResult)

enum Phase { DEPLOY, WHISTLE, FIGHT, ENDED }

const TEAM_COUNT: int = 2
## 배치판 칸 크기와 배치판 중심 거리
const CELL_SIZE: float = 110.0
const BOARD_CENTER_X: float = 260.0
## 연병장 문 위치 (각 팀 배치판 뒤쪽)
const GATE_X: float = 720.0
const RUN_SPEED: float = 240.0
## 공간 분할 격자 크기 (가까운 적 탐색 가속)
const GRID_SIZE: float = 64.0
const MAX_SEARCH_RING: int = 30
const AURA_INTERVAL: float = 0.5

var units: Array[BattleUnit] = []
var phase: Phase = Phase.DEPLOY
var phase_time: float = 0.0
var total_time: float = 0.0
var result: BattleResult = null
## 이번 step에서 발생한 연출용 이벤트 (뷰가 읽음, 다음 step 시작 시 비워짐)
## { "type": "attack"|"death"|"heal"|"whistle"|"phase", ... }
var events: Array[Dictionary] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _grids: Array[Dictionary] = [{}, {}]
var _aura_timer: float = 0.0


# =========================================================================
# 설정
# =========================================================================

## team_packets: [팀0 SpawnPacket 배열, 팀1 SpawnPacket 배열]
func setup(team_packets: Array, seed_value: int) -> void:
	_rng.seed = seed_value
	units.clear()
	var next_id: int = 0
	for team: int in range(TEAM_COUNT):
		for packet: SpawnPacket in team_packets[team]:
			if packet.unit_data == null or packet.total_count <= 0:
				continue
			var plan: Dictionary = BattleRules.get_spawn_plan(packet.total_count, packet.unit_data.is_giant)
			var spawn: int = plan["spawn"]
			var ratio: float = plan["ratio"]
			var offsets: Array[Vector2] = _formation_offsets(spawn, packet.unit_data.is_giant)
			var center: Vector2 = cell_center(team, packet.cell_index)
			for i: int in range(spawn):
				var u: BattleUnit = BattleUnit.new()
				u.setup(next_id, team, packet.cell_index, packet.unit_data, ratio, packet.is_consumable)
				u.home = center + offsets[i]
				# 연병장 안(문 뒤쪽)에서 출발
				var behind: float = -_rng.randf_range(15.0, 190.0) * team_direction(team)
				u.pos = gate_position(team) + Vector2(behind, _rng.randf_range(-150.0, 150.0))
				u.retarget_timer = BattleRules.RETARGET_INTERVAL * float(next_id % 8) / 8.0
				units.append(u)
				next_id += 1
	phase = Phase.DEPLOY
	phase_time = 0.0
	total_time = 0.0
	result = null


static func team_direction(team: int) -> float:
	return 1.0 if team == 0 else -1.0


## 배치판 칸 중심 (논리 좌표). 팀 1은 180도 회전 배치라 서로의 전열이 마주 본다.
static func cell_center(team: int, cell_index: int) -> Vector2:
	var dir: float = team_direction(team)
	var row: int = BoardState.row_of(cell_index)
	var col: int = BoardState.col_of(cell_index)
	var x: float = -BOARD_CENTER_X * dir + float(row - 1) * CELL_SIZE * dir
	var y: float = float(col - 1) * CELL_SIZE * dir
	return Vector2(x, y)


static func gate_position(team: int) -> Vector2:
	return Vector2(-GATE_X * team_direction(team), 0.0)


## 칸 안 사각 대형 오프셋 (50명 → 8x7 격자, 거인 1~3명 → 칸 중앙 일렬)
static func _formation_offsets(count: int, is_giant: bool) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	if count <= 0:
		return offsets
	if is_giant:
		var gap: float = CELL_SIZE * 0.3
		for i: int in range(count):
			offsets.append(Vector2(0.0, (float(i) - float(count - 1) * 0.5) * gap))
		return offsets
	var cols: int = ceili(sqrt(float(count)))
	var rows: int = ceili(float(count) / float(cols))
	var spacing: float = minf(CELL_SIZE * 0.9 / float(cols), 16.0)
	for i: int in range(count):
		var cx: float = float(i % cols) - float(cols - 1) * 0.5
		var cy: float = float(i / cols) - float(rows - 1) * 0.5
		offsets.append(Vector2(cy, cx) * spacing)
	return offsets


# =========================================================================
# 진행
# =========================================================================

func is_finished() -> bool:
	return phase == Phase.ENDED


func step(dt: float = BattleRules.SIM_DT) -> void:
	if phase == Phase.ENDED:
		return
	events.clear()
	phase_time += dt
	total_time += dt
	match phase:
		Phase.DEPLOY:
			_step_deploy(dt)
		Phase.WHISTLE:
			if phase_time >= BattleRules.WHISTLE_DELAY:
				events.append({ "type": "whistle" })
				_set_phase(Phase.FIGHT)
		Phase.FIGHT:
			_step_fight(dt)


## 스킵: 끝까지 즉시 계산 (결과는 실시간 진행과 동일)
func run_to_end() -> BattleResult:
	var guard: int = ceili((BattleRules.DEPLOY_MAX_TIME + BattleRules.WHISTLE_DELAY + BattleRules.FIGHT_TIME_LIMIT) / BattleRules.SIM_DT) + 10
	while phase != Phase.ENDED and guard > 0:
		step()
		guard -= 1
	return result


func _set_phase(p: Phase) -> void:
	phase = p
	phase_time = 0.0
	events.append({ "type": "phase", "phase": p })
	phase_changed.emit(p)


func _step_deploy(dt: float) -> void:
	var all_arrived: bool = true
	for u: BattleUnit in units:
		var to_home: Vector2 = u.home - u.pos
		var dist: float = to_home.length()
		var move: float = RUN_SPEED * dt
		if dist <= move:
			u.pos = u.home
		else:
			u.pos += to_home / dist * move
			all_arrived = false
	if all_arrived or phase_time >= BattleRules.DEPLOY_MAX_TIME:
		for u: BattleUnit in units:
			u.pos = u.home
		_set_phase(Phase.WHISTLE)


func _step_fight(dt: float) -> void:
	_rebuild_grids()
	_aura_timer -= dt
	if _aura_timer <= 0.0:
		_aura_timer = AURA_INTERVAL
		_update_auras()

	for u: BattleUnit in units:
		if not u.alive:
			continue
		u.cooldown = maxf(0.0, u.cooldown - dt)
		u.retarget_timer -= dt
		if u.target == null or not u.target.alive or u.retarget_timer <= 0.0:
			u.target = _find_nearest_enemy(u)
			u.retarget_timer = BattleRules.RETARGET_INTERVAL
		if u.data.heal_per_second > 0.0:
			_try_heal(u, dt)
		if u.target == null:
			continue
		var to_target: Vector2 = u.target.pos - u.pos
		var dist: float = to_target.length()
		var reach: float = u.data.attack_range + u.radius + u.target.radius
		if dist > reach:
			var move: float = minf(u.data.move_speed * dt, dist - reach)
			u.pos += to_target / dist * move
		elif u.cooldown <= 0.0:
			u.cooldown = u.data.attack_interval
			_attack(u, u.target)

	var alive_count: Array[int] = [0, 0]
	for u: BattleUnit in units:
		if u.alive:
			alive_count[u.team] += 1
	if alive_count[0] == 0 or alive_count[1] == 0:
		var winner: int = BattleResult.DRAW
		if alive_count[0] > 0:
			winner = 0
		elif alive_count[1] > 0:
			winner = 1
		_finish(winner, "annihilation")
	elif phase_time >= BattleRules.FIGHT_TIME_LIMIT:
		_finish_by_timeout()


func _attack(attacker: BattleUnit, target: BattleUnit) -> void:
	var damage: float = attacker.attack * (1.0 + attacker.aura_attack)
	var splash: float = attacker.data.splash_radius
	events.append({ "type": "attack", "from": attacker.id, "to": target.id, "pos": target.pos, "splash": splash })
	if splash > 0.0:
		for victim: BattleUnit in _enemies_near(attacker.team, target.pos, splash):
			_apply_damage(victim, damage)
	else:
		_apply_damage(target, damage)


func _apply_damage(victim: BattleUnit, damage: float) -> void:
	victim.take_damage(damage)
	if not victim.alive:
		events.append({ "type": "death", "id": victim.id, "pos": victim.pos })


func _try_heal(healer: BattleUnit, dt: float) -> void:
	healer.heal_cooldown -= dt
	if healer.heal_cooldown > 0.0:
		return
	healer.heal_cooldown = 1.0
	var best: BattleUnit = null
	var best_ratio: float = 1.0
	var radius_sq: float = healer.data.support_radius * healer.data.support_radius
	for ally: BattleUnit in units:
		if ally.team != healer.team or not ally.alive or ally.hp >= ally.max_hp:
			continue
		if ally.pos.distance_squared_to(healer.pos) > radius_sq:
			continue
		var r: float = ally.hp / ally.max_hp
		if r < best_ratio:
			best_ratio = r
			best = ally
	if best != null:
		var amount: float = healer.data.heal_per_second * BattleRules.get_stat_multiplier(healer.ratio)
		best.heal(amount)
		events.append({ "type": "heal", "from": healer.id, "to": best.id })


func _update_auras() -> void:
	for u: BattleUnit in units:
		u.aura_attack = 0.0
		u.aura_defense = 0.0
	for healer: BattleUnit in units:
		if not healer.alive or healer.data.support_radius <= 0.0:
			continue
		if healer.data.aura_attack_bonus <= 0.0 and healer.data.aura_defense_bonus <= 0.0:
			continue
		var radius_sq: float = healer.data.support_radius * healer.data.support_radius
		for ally: BattleUnit in units:
			if ally.team == healer.team and ally.alive and ally.pos.distance_squared_to(healer.pos) <= radius_sq:
				ally.aura_attack = maxf(ally.aura_attack, healer.data.aura_attack_bonus)
				ally.aura_defense = maxf(ally.aura_defense, healer.data.aura_defense_bonus)


# =========================================================================
# 공간 분할 탐색
# =========================================================================

func _rebuild_grids() -> void:
	_grids = [{}, {}]
	for u: BattleUnit in units:
		if not u.alive:
			continue
		var key: Vector2i = _grid_key(u.pos)
		var grid: Dictionary = _grids[u.team]
		if not grid.has(key):
			grid[key] = []
		(grid[key] as Array).append(u)


static func _grid_key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / GRID_SIZE), floori(p.y / GRID_SIZE))


func _find_nearest_enemy(u: BattleUnit) -> BattleUnit:
	var grid: Dictionary = _grids[1 - u.team]
	if grid.is_empty():
		return null
	var center: Vector2i = _grid_key(u.pos)
	var best: BattleUnit = null
	var best_dist_sq: float = INF
	for ring: int in range(MAX_SEARCH_RING + 1):
		# 이미 찾은 적이 이번 링보다 가까우면 더 볼 필요 없음
		var ring_min: float = maxf(0.0, float(ring - 1)) * GRID_SIZE
		if best != null and ring_min * ring_min > best_dist_sq:
			break
		for dx: int in range(-ring, ring + 1):
			for dy: int in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var key: Vector2i = center + Vector2i(dx, dy)
				if not grid.has(key):
					continue
				for other: BattleUnit in grid[key]:
					var d: float = other.pos.distance_squared_to(u.pos)
					if d < best_dist_sq or (d == best_dist_sq and best != null and other.id < best.id):
						best_dist_sq = d
						best = other
	if best == null:
		# 격자 탐색 범위 밖: 전체 탐색 (드문 경우)
		for other: BattleUnit in units:
			if other.alive and other.team != u.team:
				var d2: float = other.pos.distance_squared_to(u.pos)
				if d2 < best_dist_sq:
					best_dist_sq = d2
					best = other
	return best


func _enemies_near(attacker_team: int, point: Vector2, radius: float) -> Array[BattleUnit]:
	var found: Array[BattleUnit] = []
	var grid: Dictionary = _grids[1 - attacker_team]
	var reach: int = ceili(radius / GRID_SIZE)
	var center: Vector2i = _grid_key(point)
	var radius_sq: float = radius * radius
	for dx: int in range(-reach, reach + 1):
		for dy: int in range(-reach, reach + 1):
			var key: Vector2i = center + Vector2i(dx, dy)
			if not grid.has(key):
				continue
			for other: BattleUnit in grid[key]:
				if other.alive and other.pos.distance_squared_to(point) <= radius_sq:
					found.append(other)
	return found


# =========================================================================
# 종료
# =========================================================================

func _finish_by_timeout() -> void:
	var hp_sum: Array[float] = [0.0, 0.0]
	for u: BattleUnit in units:
		if u.alive:
			hp_sum[u.team] += u.hp
	var winner: int = BattleResult.DRAW
	if hp_sum[0] > hp_sum[1]:
		winner = 0
	elif hp_sum[1] > hp_sum[0]:
		winner = 1
	_finish(winner, "timeout")


func _finish(winner: int, reason: String) -> void:
	var r: BattleResult = BattleResult.new()
	r.winner = winner
	r.reason = reason
	r.fight_duration = phase_time
	r.survivors_by_cell = [{}, {}]
	for u: BattleUnit in units:
		r.remaining_hp[u.team] += u.hp if u.alive else 0.0
		if not u.alive:
			continue
		var cells: Dictionary = r.survivors_by_cell[u.team]
		cells[u.cell_index] = float(cells.get(u.cell_index, 0.0)) + u.ratio
		r.survivor_totals[u.team] += u.ratio
	# 유닛끼리 서로를 target으로 참조하면 RefCounted 순환 참조로 메모리가 해제되지 않는다
	for u: BattleUnit in units:
		u.target = null
	result = r
	_set_phase(Phase.ENDED)
	battle_ended.emit(r)
