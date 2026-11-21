class_name FoolTarot
extends TarotCardData
## 0. 더 풀 — 광폭화 개전: 전투 내내 양 팀 모든 유닛 공격력 ×2, 받는 피해 ×1.5

@export var attack_mult: float = 2.0
@export var damage_taken_mult: float = 1.5


func on_battle_start(sim: BattleSimulation, _team: int, _state: Dictionary) -> void:
	for u: BattleUnit in sim.units:
		u.tarot_attack_mult *= attack_mult
		u.tarot_damage_taken_mult *= damage_taken_mult
