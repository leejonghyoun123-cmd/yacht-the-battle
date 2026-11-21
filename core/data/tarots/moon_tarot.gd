class_name MoonTarot
extends TarotCardData
## 18. 더 문 — 월광 가속: 교전 시작 후 10초간 아군 전체 공격 속도 +60%

@export var duration: float = 10.0
@export var haste_mult: float = 1.6


func on_battle_start(sim: BattleSimulation, team: int, state: Dictionary) -> void:
	for u: BattleUnit in sim.units:
		if u.team == team:
			u.tarot_haste_mult *= haste_mult
	state["active"] = true


func on_battle_step(sim: BattleSimulation, team: int, state: Dictionary, elapsed: float, _dt: float) -> void:
	if state.get("active", false) and elapsed >= duration:
		state["active"] = false
		for u: BattleUnit in sim.units:
			if u.team == team:
				u.tarot_haste_mult /= haste_mult
