class_name StarTarot
extends TarotCardData
## 17. 더 스타 — 성운 폭격: 교전 0~10초, 0.5초마다 적 진영에 별똥별 (반경 120, 최대 체력 8% + 고정 피해). 아군 오폭 없음.

@export var duration: float = 10.0
@export var interval: float = 0.5
@export var radius: float = 120.0
@export var max_hp_ratio: float = 0.08
@export var flat_damage: float = 10.0


func on_battle_step(sim: BattleSimulation, team: int, state: Dictionary, elapsed: float, _dt: float) -> void:
	var next: float = float(state.get("next", 0.0))
	if elapsed > duration or elapsed < next:
		return
	state["next"] = next + interval
	var enemy: BattleUnit = sim.random_enemy_of(team)
	if enemy == null:
		return
	var center: Vector2 = enemy.pos + Vector2(sim.rng_range(-40.0, 40.0), sim.rng_range(-40.0, 40.0))
	sim.events.append({ "type": "tarot_blast", "kind": "star", "pos": center, "radius": radius })
	for v: BattleUnit in sim.units_near(1 - team, center, radius):
		sim.apply_effect_damage(v, v.max_hp * max_hp_ratio + flat_damage)
