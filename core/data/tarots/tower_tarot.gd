class_name TowerTarot
extends TarotCardData
## 16. 더 타워 — 번개 포탑: 내 성벽(문 앞)에 영구 포탑. 2초마다 가장 가까운 적 1체 + 주변 2체 연쇄 번개.
## 피해 = 라운드 × 3 + 대상 최대 체력 5%. 여러 장 설치 시 장당 공격력 +50%. (state["stacks"] = 설치 수)

@export var interval: float = 2.0
@export var per_round_damage: float = 3.0
@export var max_hp_ratio: float = 0.05
@export var chain_count: int = 3
@export var stack_bonus: float = 0.5


func on_battle_step(sim: BattleSimulation, team: int, state: Dictionary, elapsed: float, _dt: float) -> void:
	var next: float = float(state.get("next", interval))
	if elapsed < next:
		return
	state["next"] = next + interval
	var stacks: int = maxi(1, int(state.get("stacks", 1)))
	var power: float = 1.0 + stack_bonus * float(stacks - 1)
	var origin: Vector2 = BattleSimulation.gate_position(team) + Vector2(40.0 * BattleSimulation.team_direction(team), 0.0)
	var from: Vector2 = origin
	var hit: Array[BattleUnit] = []
	for i: int in range(chain_count):
		var t: BattleUnit = sim.nearest_enemy_to(team, from, hit)
		if t == null:
			break
		hit.append(t)
		sim.events.append({ "type": "zap", "from": from, "to": t.pos })
		sim.apply_effect_damage(t, (per_round_damage * float(sim.round_number) + t.max_hp * max_hp_ratio) * power)
		from = t.pos
