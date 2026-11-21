class_name StackRetentionPolicy
extends RefCounted
## 전투 후 중첩칸 인원을 어떻게 남길지 정하는 정책.
## 현재 규칙: 전투에서 죽어도 줄지 않는다 (KeepAll). 플레이 후 바뀔 수 있어 교체 가능하게 분리했다.
## 바꾸려면 BoardState.retention_policy에 다른 정책 객체를 넣기만 하면 된다.

enum Mode { KEEP_ALL, KEEP_SURVIVORS }

var mode: Mode = Mode.KEEP_ALL


func _init(p_mode: Mode = Mode.KEEP_ALL) -> void:
	mode = p_mode


## previous_total: 전투 전 누적 인원 / survivors: 생존 환산 인원
func next_count(previous_total: int, survivors: int) -> int:
	match mode:
		Mode.KEEP_SURVIVORS:
			return clampi(survivors, 0, previous_total)
	return previous_total
