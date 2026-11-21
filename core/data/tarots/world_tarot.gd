class_name WorldTarot
extends TarotCardData
## 21. 더 월드 — 시간 정지 및 무효화: 아군 남은 체력 합이 시작 대비 30% 이하가 되면 전투를 무효(DRAW_VOID)로 끝낸다.
## 무효: 체력 피해 없음, 연승·연패 유지, 소비칸 유지, 위로금 지급 (BattleSettlement)

@export var threshold: float = 0.3


func on_battle_start(sim: BattleSimulation, team: int, state: Dictionary) -> void:
	state["initial"] = sim.get_team_hp(team)


func on_battle_step(sim: BattleSimulation, team: int, state: Dictionary, _elapsed: float, _dt: float) -> void:
	var initial: float = float(state.get("initial", 0.0))
	if initial <= 0.0 or sim.is_finished():
		return
	if sim.get_team_hp(team) <= initial * threshold:
		sim.events.append({ "type": "tarot_blast", "kind": "world", "pos": Vector2.ZERO, "radius": 0.0 })
		sim.void_battle()
