class_name JusticeTarot
extends TarotCardData
## 11. 저스티스 — 정의의 영구 성벽: 매 라운드 시작 시 본체 실드 +35 자동 충전 (여러 장이면 누적).
## 피격 순서: 상한 → 성벽증축(임시) → 저스티스 → 체력 (PlayerState.take_round_damage)

@export var shield: int = 35
