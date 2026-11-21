class_name RoundFlow
extends RefCounted
## 한 라운드의 준비 → 굴림 → 얏츠판 기록 흐름 (UI 없는 순수 로직).
## UI는 changed 시그널을 받아 화면 전체를 다시 그린다.
##
##   PREP     : 덱 편집 가능. [굴림] 시 덱 잠금 → ROLLING
##   ROLLING  : 고정(hold) 토글, 재굴림. 얏츠판 항목을 클릭하면 주사위 확정 + 기록 → RECORDED
##   RECORDED : 소환값 확정됨. 다음 단계(배치·전투, Step 3)로 진행 가능
##
## 매 라운드 얏츠판 1항목 기록은 필수다 (족보 불성립 시 0원).

signal changed
signal rolled(results: Array[DiceRollResult])
signal yacht_recorded(category: int, gold: int)
signal round_started(round_number: int)

enum Phase { PREP, ROLLING, RECORDED }

var player: PlayerState
var deck: DeckManager
var board: YachtBoard
var rng: RandomNumberGenerator

var round_number: int = 1
var phase: Phase = Phase.PREP
var rerolls_left: int = 0
## 아이템(나 안굴렸는데?)·보스(15R) 보정
var reroll_bonus: int = 0
var reroll_penalty: int = 0
var held: Array[bool] = []
var results: Array[DiceRollResult] = []
var recorded_category: int = -1
var recorded_gold: int = 0


func _init(p_player: PlayerState, p_deck: DeckManager, p_board: YachtBoard, p_rng: RandomNumberGenerator) -> void:
	player = p_player
	deck = p_deck
	board = p_board
	rng = p_rng
	_reset_round_state()


func get_reroll_limit() -> int:
	return maxi(GameBalance.MIN_REROLLS, GameBalance.REROLLS_PER_ROUND + reroll_bonus - reroll_penalty)


func has_rolled() -> bool:
	return not results.is_empty()


func can_roll() -> bool:
	return phase == Phase.PREP or (phase == Phase.ROLLING and rerolls_left > 0 and held.has(false))


## 첫 굴림 또는 재굴림. 첫 굴림 시 덱이 잠긴다.
func roll() -> bool:
	if not can_roll():
		return false
	if phase == Phase.PREP:
		deck.lock()
		phase = Phase.ROLLING
		rerolls_left = get_reroll_limit()
		results = DiceRollResolver.resolve(deck.active, rng, round_number)
	else:
		rerolls_left -= 1
		results = DiceRollResolver.resolve(deck.active, rng, round_number, held, results)
	rolled.emit(results)
	changed.emit()
	return true


## 재굴림에서 제외(고정)할 주사위 토글
func toggle_hold(index: int) -> bool:
	if phase != Phase.ROLLING or index < 0 or index >= held.size():
		return false
	held[index] = not held[index]
	changed.emit()
	return true


func get_summon_values() -> Array[int]:
	return DiceRollResolver.to_summon_values(results)


## 얏츠판 예상 보상 (미기록 항목만, 굴림 전이면 빈 Dictionary)
func get_yacht_preview() -> Dictionary:
	if not has_rolled():
		return {}
	return board.preview(get_summon_values(), round_number)


## 얏츠판 항목 기록 = 이번 라운드 주사위 확정. 골드 지급 후 RECORDED.
func record_yacht(category: int) -> bool:
	if phase != Phase.ROLLING or board.is_recorded(category):
		return false
	var gold: int = board.record(category, get_summon_values(), round_number)
	if gold < 0:
		return false
	player.add_gold(gold, PlayerState.GoldSource.YACHT_BOARD)
	recorded_category = category
	recorded_gold = gold
	phase = Phase.RECORDED
	yacht_recorded.emit(category, gold)
	changed.emit()
	return true


## 다음 라운드 (Step 3 전투가 붙기 전까지는 기록 직후 바로 호출)
func advance_round() -> bool:
	if phase != Phase.RECORDED:
		return false
	round_number += 1
	player.add_gold(GameBalance.ROUND_INCOME, PlayerState.GoldSource.ROUND_INCOME)
	_reset_round_state()
	deck.unlock()
	round_started.emit(round_number)
	changed.emit()
	return true


func _reset_round_state() -> void:
	phase = Phase.PREP
	rerolls_left = 0
	results.clear()
	held.clear()
	held.resize(GameBalance.ACTIVE_DICE_COUNT)
	held.fill(false)
	recorded_category = -1
	recorded_gold = 0
