class_name LevelTable
extends RefCounted
## 1인용 15라운드 레벨 정보 (06 레벨 디자인 기획서).
## 보스: 3·6·9·12·15R. 각 챕터 시작(1·4·7·10·13R)부터 다음 보스를 예고한다.

const BOSSES: Dictionary = {
	3: { "name": "검열관의 저울", "gimmick": "원시 눈금 3 이하 주사위의 최종 소환값 50% 감소" },
	6: { "name": "홀짝의 심판관", "gimmick": "최종값이 짝수인 주사위의 소환 인원 40% 감소" },
	9: { "name": "침묵의 시계탑", "gimmick": "모든 출전 주사위의 인첸트 슬롯 1번 비활성화" },
	12: { "name": "탐욕의 수금원", "gimmick": "한 주사위의 2번째 이후 곱연산 배수 절반" },
	15: { "name": "야추의 군주", "gimmick": "재굴림 1회 감소 + 적이 타로카드 2장 자동 발동" },
}

const FINAL_ROUND: int = 15


static func is_boss_round(round_number: int) -> bool:
	return BOSSES.has(round_number)


## 현재 라운드가 속한 챕터의 보스 라운드 (무한모드도 3라운드 주기 유지)
static func get_upcoming_boss_round(round_number: int) -> int:
	return ((maxi(round_number, 1) - 1) / 3) * 3 + 3


## 예고 배너용 보스 정보. 정보가 없으면 빈 Dictionary.
static func get_upcoming_boss(round_number: int) -> Dictionary:
	var boss_round: int = get_upcoming_boss_round(round_number)
	if not BOSSES.has(boss_round):
		return {}
	var info: Dictionary = (BOSSES[boss_round] as Dictionary).duplicate()
	info["round"] = boss_round
	info["rounds_left"] = boss_round - round_number
	return info
