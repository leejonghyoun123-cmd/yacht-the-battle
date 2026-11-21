class_name OverloadTrait
extends MultiplyTrait
## 과부하 주사위: 최종 소환값 ×2. 중첩칸에 놓아도 이번 라운드 한정(소비칸 판정)으로 처리된다.


func forces_consumable() -> bool:
	return true
