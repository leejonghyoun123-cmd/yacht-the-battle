class_name RoundTimer
extends RefCounted
## 준비 시간 타이머 (기본 2분, 라운드당 1회 30초 연장).
## 친선전 전용: 솔로에서는 enabled = false로 꺼 둔다 (시스템은 그대로 유지).
## 실제 시간은 화면이 tick(delta)으로 넘겨준다. 0이 되면 expired 1회 발생.

signal expired

var time_left: float = GameBalance.PREP_TIME
var extended: bool = false
var running: bool = false
## false면 reset해도 돌지 않는다 (솔로 모드)
var enabled: bool = true


func reset() -> void:
	time_left = GameBalance.PREP_TIME
	extended = false
	running = enabled


func stop() -> void:
	running = false


func can_extend() -> bool:
	return running and not extended


func extend() -> bool:
	if not can_extend():
		return false
	extended = true
	time_left += GameBalance.PREP_EXTENSION
	return true


func tick(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		running = false
		expired.emit()


## "1:05" 형식
func get_text() -> String:
	var total: int = ceili(time_left)
	return "%d:%02d" % [total / 60, total % 60]
