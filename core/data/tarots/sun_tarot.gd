class_name SunTarot
extends TarotCardData
## 19. 더 썬 — 태양의 심판: 교전 3초에 적이 가장 밀집한 곳(반경 180)에 투하.
## 범위 안 적: 5초간 초당 최대 체력 6% 화염 / 범위 안 아군: 최대 체력 30% 즉시 회복

@export var trigger_time: float = 3.0
@export var radius: float = 180.0
@export var burn_ratio: float = 0.06
@export var burn_duration: float = 5.0
@export var ally_heal_ratio: float = 0.3


func on_battle_step(sim: BattleSimulation, team: int, state: Dictionary, elapsed: float, _dt: float) -> void:
	if state.get("done", false) or elapsed < trigger_time:
		return
	state["done"] = true
	var center: Vector2 = sim.densest_point(1 - team, radius)
	sim.events.append({ "type": "tarot_blast", "kind": "sun", "pos": center, "radius": radius })
	for v: BattleUnit in sim.units_near(1 - team, center, radius):
		v.burn_per_second = maxf(v.burn_per_second, v.max_hp * burn_ratio)
		v.burn_time = burn_duration
	for a: BattleUnit in sim.units_near(team, center, radius):
		a.heal(a.max_hp * ally_heal_ratio)
