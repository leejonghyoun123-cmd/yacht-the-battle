class_name RandomStatModifier
extends StatModifier
## 전투마다 후보 중 1개를 무작위로 골라 적용하는 보정 (10. 더 휠 오브 포츈).
## 추첨은 전투 시뮬레이션의 결정론 RNG로만 한다 (BattleSimulation.setup에서 resolve).

@export var pool: Array[StatModifier] = []


func resolve(rng: RandomNumberGenerator) -> StatModifier:
	if pool.is_empty():
		return self
	return pool[rng.randi_range(0, pool.size() - 1)]
