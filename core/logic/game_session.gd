class_name GameSession
extends RefCounted
## 솔로 한 판 진행 (UI 없는 순수 로직).
##   BARRACKS  : 연병장(준비). 중첩칸 판매·덱 편집 가능 → [주사위 굴리기]
##   ROLLING   : RoundFlow로 굴림·재굴림 → 얏츠판 기록
##   PLACEMENT : 주사위마다 병과 선택 → 칸에 소환 (보스 소환 보정 적용)
##   BATTLE    : 전투 시뮬레이션 진행 (화면이 step을 돌림)
##   SETTLED   : 정산 완료 → 다음 라운드 연병장 / 게임 오버 / 15R 클리어

signal changed
signal phase_changed(new_phase: Phase)
signal game_over(cleared: bool)

enum Phase { BARRACKS, ROLLING, PLACEMENT, BATTLE, SETTLED, GAME_OVER }

var player: PlayerState
var deck: DeckManager
var yacht: YachtBoard
var flow: RoundFlow
var board: BoardState
var streak: StreakState
var rng: RandomNumberGenerator

var phase: Phase = Phase.BARRACKS
## 소환 목록: [{ "dice_index", "base", "value", "reason", "placed", "unit_id", "cell" }]
var summons: Array[Dictionary] = []
var battle: BattleSimulation = null
## 보유 아이템·타로
var inventory: Inventory = Inventory.new()
## 이번 전투 소비칸(+과부하) 소환 환산 인원 (소비칸 보험)
var battle_consumable_total: int = 0
var last_summary: Dictionary = {}
var _board_snapshot: Array = []


## use_prep_timer: 준비 시간 타이머 사용 (친선전 true, 솔로 false)
func _init(seed_value: int = 0, use_prep_timer: bool = false) -> void:
	rng = RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	player = PlayerState.new()
	deck = DeckManager.new()
	StarterDeck.build_plain_into(deck)
	yacht = YachtBoard.new()
	flow = RoundFlow.new(player, deck, yacht, rng)
	board = BoardState.new()
	streak = StreakState.new()
	shop = ShopState.new(player, deck, rng)
	shop.inventory = inventory
	shop.acquire_item_cb = acquire_item
	shop.acquire_tarot_cb = acquire_tarot
	shop.restock(flow.round_number)
	timer = RoundTimer.new()
	timer.enabled = use_prep_timer
	timer.reset()
	flow.yacht_recorded.connect(_on_yacht_recorded)
	apply_round_rules()


## 상점 (연병장에서 이동)
var shop: ShopState
## 준비 시간 타이머 (2분 + 1회 30초 연장). 화면이 tick을 넘겨주고, 만료 시 auto_finalize 호출.
var timer: RoundTimer


## 준비 단계인가 (연병장·굴림·배치 — 전투 전)
func is_preparing() -> bool:
	return phase == Phase.BARRACKS or phase == Phase.ROLLING or phase == Phase.PLACEMENT


## 굴림 화면 → 연병장 (화면은 자유롭게 오갈 수 있다)
func go_to_barracks() -> bool:
	if phase == Phase.ROLLING:
		_set_phase(Phase.BARRACKS)
		return true
	return phase == Phase.BARRACKS


## 준비 시간 만료: 굴리지 않았으면 자동 굴림 → 가장 비싼 얏츠판 항목 기록 →
## 남은 주사위는 소드로 빈 소비칸(없으면 소드를 받을 수 있는 칸)에 소환 → 전투 시작.
func auto_finalize() -> BattleSimulation:
	if phase == Phase.BARRACKS or phase == Phase.ROLLING:
		if phase == Phase.BARRACKS:
			_set_phase(Phase.ROLLING)
		if flow.phase == RoundFlow.Phase.PREP:
			flow.roll()
		var preview: Dictionary = flow.get_yacht_preview()
		var best: int = -1
		for c: int in preview.keys():
			if best < 0 or preview[c] > preview[best]:
				best = c
		flow.record_yacht(best)
	if phase != Phase.PLACEMENT:
		return null
	for i: int in range(summons.size()):
		if summons[i]["placed"]:
			continue
		var target: Dictionary = _auto_target()
		place(i, target["unit"], target["cell"])
	return start_battle()


## 자동 소환 위치: 소드를 받을 수 있는 소비칸 → 중첩칸 → (없으면) 첫 칸의 병과 그대로
func _auto_target() -> Dictionary:
	for stack_pass: bool in [false, true]:
		for cell: CellState in board.cells:
			if cell.is_stack == stack_pass and cell.can_accept(&"sword"):
				return { "unit": &"sword", "cell": cell.index }
	return { "unit": board.cells[0].unit_id, "cell": 0 }


func get_round() -> int:
	return flow.round_number


# --- 연병장 (준비) ---------------------------------------------------------

## 중첩칸 판매: 연병장·굴림 단계 (배치 중에는 이번 라운드 소환과 섞여 되돌리기가 꼬이므로 불가)
func can_sell_stack() -> bool:
	return phase == Phase.BARRACKS or phase == Phase.ROLLING


## 중첩칸 판매 (준비 단계에서만). 받은 골드 반환.
func sell_stack_cell(cell_index: int) -> int:
	if not can_sell_stack():
		return 0
	var gold: int = board.sell_stack_cell(cell_index)
	if gold > 0:
		player.add_gold(gold, PlayerState.GoldSource.OTHER)
		changed.emit()
	return gold


## 연병장 → 주사위 테이블
func go_to_rolling() -> bool:
	if phase == Phase.ROLLING:
		return true
	if phase != Phase.BARRACKS:
		return false
	_set_phase(Phase.ROLLING)
	return true


## 적 정보 힌트 (솔로: 대략적인 규모와 병과)
func get_enemy_hint() -> Dictionary:
	var r: int = get_round()
	var names: PackedStringArray = []
	for id: StringName in EnemyTable.get_unit_ids(r):
		names.append(UnitCatalog.get_unit(id).display_name)
	return {
		"round": r,
		"approx_total": _approximate(EnemyTable.get_total(r)),
		"units": names,
		"boss": LevelTable.BOSSES.get(r, {}),
	}


static func _approximate(value: int) -> int:
	if value < 20:
		return value
	var magnitude: int = int(pow(10.0, floorf(log(float(value)) / log(10.0)) - 1.0))
	return int(roundf(float(value) / float(magnitude))) * magnitude


# --- 배치 -------------------------------------------------------------------

func _on_yacht_recorded(_category: int, _gold: int) -> void:
	summons.clear()
	messages.clear()
	for result: DiceRollResult in flow.results:
		var mod: Dictionary = BossRules.modify_summon(get_round(), result)
		# 포커카드 등 성질이 원시 눈금에 따라 해금하는 병과 (A → 거인, K → 킹) + 칸 보정(수트·로열·뼈)
		var die: DiceInstance = deck.active[result.dice_index]
		var unlocks: Array[StringName] = []
		var mods: Array[StatModifier] = []
		var temporary: bool = false
		if die.trait_data != null:
			unlocks = die.trait_data.get_unlocked_units(result.raw_roll, die)
			mods = die.trait_data.get_cell_modifiers(result.raw_roll, die)
			temporary = die.trait_data.forces_consumable()
			_push_message(die.trait_data.on_confirm(die, result, self))
		for it: ItemInstance in inventory.items:
			if it.data is FeastItem:
				_push_message((it.data as FeastItem).pay_pending(die, self))
		summons.append({
			"dice_index": result.dice_index, "base": result.summon_value,
			"value": mod["value"], "reason": mod["reason"],
			"raw": result.raw_roll, "unlocks": unlocks, "amount": 0,
			"mods": mods, "temporary": temporary,
			"placed": false, "unit_id": &"", "cell": -1,
		})
	for it: ItemInstance in inventory.items:
		_push_message(it.data.on_record(it, self))
	_board_snapshot = board.to_dict()
	_set_phase(Phase.PLACEMENT)


## 이번 확정·정산에서 생긴 알림 (화면이 띄우고 비운다)
var messages: Array[String] = []


func _push_message(text: String) -> void:
	if text != "":
		messages.append(text)


## 추가 소환 (주사위 복제 거울). 주사위가 없는 소환이므로 dice_index = -1
func add_bonus_summon(value: int, reason: String) -> void:
	summons.append({
		"dice_index": -1, "base": value, "value": maxi(1, value), "reason": "", "bonus_name": reason,
		"raw": 0, "unlocks": [] as Array[StringName], "amount": 0,
		"mods": [] as Array[StatModifier], "temporary": false,
		"placed": false, "unit_id": &"", "cell": -1,
	})


## 소환에 쓰인 주사위 (추가 소환이면 null)
func get_summon_dice(summon_index: int) -> DiceInstance:
	var di: int = int(summons[summon_index]["dice_index"])
	return deck.active[di] if di >= 0 and di < deck.active.size() else null


func can_place(summon_index: int, unit_id: StringName, cell_index: int) -> bool:
	if phase != Phase.PLACEMENT or summon_index < 0 or summon_index >= summons.size():
		return false
	if summons[summon_index]["placed"]:
		return false
	if not can_use_unit(summon_index, unit_id):
		return false
	return board.can_place(cell_index, unit_id)


## 이 주사위로 이 병과를 배치할 수 있는가. 거인·킹은 포커카드 전용 (A → 거인, K → 킹).
func can_use_unit(summon_index: int, unit_id: StringName) -> bool:
	if not UnitCatalog.is_poker_only(unit_id):
		return true
	if summon_index < 0 or summon_index >= summons.size():
		return false
	return (summons[summon_index]["unlocks"] as Array).has(unit_id)


## 이 소환으로 칸에 더해질 인원. 유일 유닛(킹)은 소환값과 상관없이 1 (= 누적 K 수)
func get_place_amount(summon_index: int, unit_id: StringName) -> int:
	var data: UnitData = UnitCatalog.get_unit(unit_id)
	if data != null and data.is_unique:
		return 1
	return int(summons[summon_index]["value"])


func place(summon_index: int, unit_id: StringName, cell_index: int) -> bool:
	if not can_place(summon_index, unit_id, cell_index):
		return false
	var amount: int = get_place_amount(summon_index, unit_id)
	var s_mods: Array[StatModifier] = []
	for m: StatModifier in summons[summon_index].get("mods", []):
		s_mods.append(m)
	board.place(cell_index, unit_id, amount, s_mods, bool(summons[summon_index].get("temporary", false)))
	summons[summon_index]["amount"] = amount
	summons[summon_index]["placed"] = true
	summons[summon_index]["unit_id"] = unit_id
	summons[summon_index]["cell"] = cell_index
	changed.emit()
	return true


## 다른 병과가 있는 칸에 배치하려 할 때의 처리 미리보기 (경고창 문구용)
## 반환: { "needed": bool, "old_unit", "sell_count", "sell_gold", "returned": 이번 라운드에 그 칸에 놓았다가 되돌아올 주사위 목록 }
func get_replace_info(cell_index: int, unit_id: StringName) -> Dictionary:
	var cell: CellState = board.cells[cell_index]
	if cell.can_accept(unit_id):
		return { "needed": false }
	var returned: Array[int] = []
	var this_round: int = 0
	for i: int in range(summons.size()):
		if summons[i]["placed"] and summons[i]["cell"] == cell_index:
			returned.append(i)
			this_round += int(summons[i]["amount"])
	# 이번 라운드에 놓은 인원은 판매가 아니라 주사위로 되돌리고, 이전 라운드부터 있던 인원만 판매
	var persistent: int = maxi(0, cell.count - this_round)
	var gold: int = persistent * GameBalance.STACK_SELL_PER_UNIT if cell.is_stack else 0
	return {
		"needed": true, "old_unit": cell.unit_id, "sell_count": persistent,
		"sell_gold": gold, "returned": returned,
	}


## 덮어쓰기 배치: 칸의 기존 유닛을 자동 판매(이번 라운드 배치분은 주사위로 되돌림)한 뒤 새 병과를 배치
func replace_and_place(summon_index: int, unit_id: StringName, cell_index: int) -> bool:
	if phase != Phase.PLACEMENT or summon_index < 0 or summon_index >= summons.size():
		return false
	if summons[summon_index]["placed"]:
		return false
	var info: Dictionary = get_replace_info(cell_index, unit_id)
	if info["needed"]:
		for i: int in info["returned"]:
			summons[i]["placed"] = false
			summons[i]["unit_id"] = &""
			summons[i]["cell"] = -1
		board.cells[cell_index].clear()
		if info["sell_gold"] > 0:
			player.add_gold(info["sell_gold"], PlayerState.GoldSource.OTHER)
		# 판매한 칸은 [배치 초기화] 시에도 되살아나지 않도록 기준 상태에서도 비운다
		for entry: Dictionary in _board_snapshot:
			if entry["index"] == cell_index:
				entry["unit"] = ""
				entry["count"] = 0
	return place(summon_index, unit_id, cell_index)


func next_unplaced_index() -> int:
	for i: int in range(summons.size()):
		if not summons[i]["placed"]:
			return i
	return -1


func all_placed() -> bool:
	return phase == Phase.PLACEMENT and next_unplaced_index() == -1


## 이번 라운드 배치를 모두 되돌린다
func reset_placement() -> void:
	if phase != Phase.PLACEMENT:
		return
	_restore_board(_board_snapshot)
	for s: Dictionary in summons:
		s["placed"] = false
		s["unit_id"] = &""
		s["cell"] = -1
	changed.emit()


func _restore_board(snapshot: Array) -> void:
	for entry: Dictionary in snapshot:
		var cell: CellState = board.cells[entry["index"]]
		cell.unit_id = StringName(entry["unit"])
		cell.count = entry["count"]
		cell.temp_count = int(entry.get("temp", 0))
		cell.modifiers.clear()
		for m: StatModifier in entry.get("mods", []):
			cell.modifiers.append(m)
	board.board_changed.emit()


# --- 전투 ·정산 --------------------------------------------------------------

## 배치 완료 → 전투 시뮬레이션 생성 (화면이 step을 돌리거나 run_to_end로 스킵)
func start_battle() -> BattleSimulation:
	if not all_placed():
		return null
	battle = BattleSimulation.new()
	var enemy: BoardState = EnemyTable.build_board(get_round())
	var mine: Array[SpawnPacket] = board.get_spawn_packets()
	for it: ItemInstance in inventory.items:
		it.data.modify_packets(it, mine)
	battle_consumable_total = 0
	for p: SpawnPacket in mine:
		if p.is_consumable:
			battle_consumable_total = FixedNum.add(battle_consumable_total, p.total_count)
		else:
			battle_consumable_total = FixedNum.add(battle_consumable_total, p.temp_count)
	battle.round_number = get_round()
	battle.team_compression[0] = inventory.get_compression()
	battle.team_links[0] = board.slot_links.duplicate()
	battle.setup([mine, enemy.get_spawn_packets()], rng.randi())
	# 예약한 전투 타로 + 설치한 더 타워
	for card: TarotCardData in inventory.tarot_reserved:
		battle.add_battle_tarot(0, card)
	if inventory.towers > 0 and inventory.tower_card != null:
		battle.add_battle_tarot(0, inventory.tower_card, inventory.towers)
	timer.stop()
	_set_phase(Phase.BATTLE)
	return battle


## 전투 결과 정산. 게임 오버가 아니면 다음 라운드로 넘어가 연병장으로 돌아온다.
func settle_battle() -> Dictionary:
	if phase != Phase.BATTLE or battle == null or not battle.is_finished():
		return {}
	var finished_round: int = get_round()
	messages.clear()
	last_summary = BattleSettlement.settle_solo(battle.result, player, board, streak, finished_round, yacht.get_reward_multiplier())
	last_summary["round"] = finished_round
	for it: ItemInstance in inventory.items:
		_push_message(it.data.on_settle(it, self, battle.result, last_summary))
	battle = null
	# 성벽증축 임시 실드는 해당 라운드에만 유효
	player.round_shield = 0
	# 예약 타로는 전투 1회 발동 후 소모
	inventory.tarot_reserved.clear()
	_round_end_hooks()
	if player.is_dead():
		_set_phase(Phase.GAME_OVER)
		game_over.emit(false)
		return last_summary
	if finished_round >= LevelTable.FINAL_ROUND:
		# 15R 결과로 한 판 종료 (승리 = 클리어). 무한모드 연결은 이후 단계에서.
		_set_phase(Phase.GAME_OVER)
		game_over.emit(last_summary["winner"] == 0)
		return last_summary
	flow.advance_round()
	apply_round_rules()
	shop.restock(get_round())
	shop.free_reroll = streak.has_free_reroll()
	_set_phase(Phase.SETTLED)
	return last_summary


## 정산 화면 확인 후 연병장으로
func return_to_barracks() -> void:
	if phase == Phase.SETTLED:
		timer.reset()
		_set_phase(Phase.BARRACKS)


func _set_phase(p: Phase) -> void:
	phase = p
	phase_changed.emit(p)
	changed.emit()


## 라운드별 보스 규칙을 굴림 흐름에 적용 (9R 슬롯 정지, 12R 곱연산 과세, 15R 재굴림 -1)
func apply_round_rules() -> void:
	var r: int = get_round()
	flow.roll_modifiers = BossRules.roll_modifiers(r)
	flow.reroll_penalty = BossRules.reroll_penalty(r)
	player.refill_justice_shield()
	refresh_item_rules()


## 아이템이 바뀌면 굴림 규칙 갱신 (아이템 목록·재굴림 보너스·족보 위조)
func refresh_item_rules() -> void:
	flow.roll_modifiers["items"] = inventory.get_sorted_items()
	flow.reroll_bonus = inventory.get_reroll_bonus()
	yacht.forgery = inventory.has_forgery()
	changed.emit()


## 라운드 종료: 주사위 성질(유리 파괴·X병 누적) → 아이템(저금통 적립·쿨타임)
func _round_end_hooks() -> void:
	for d: DiceInstance in deck.all_dice():
		if d.trait_data != null:
			_push_message(d.trait_data.on_round_end(d, deck.rolled_dice.has(d), self))
	for it: ItemInstance in inventory.items:
		it.data.on_round_end(it, self)
	inventory.remove_expired()
	refresh_item_rules()


## 주사위 파괴 (인첸트 자동 회수, 출전 칸 보충). 회수 못 한 인첸트는 판매가로 환급.
func destroy_dice(dice: DiceInstance) -> void:
	var r: Dictionary = deck.destroy_dice(dice)
	if int(r["refund"]) > 0:
		player.add_gold(int(r["refund"]), PlayerState.GoldSource.OTHER)
		_push_message("자리가 없어 회수 못 한 인첸트 환급 +%d원" % int(r["refund"]))


# --- 유저 아이템 · 타로카드 -------------------------------------------------

## 아이템 획득 (상점·조커). 대상 주사위가 필요한 아이템은 target에 바로 적용하고 사라진다.
func acquire_item(data: UserItemData, target: DiceInstance = null, picks: Array = []) -> String:
	var inst: ItemInstance = ItemInstance.new(data)
	inst.state["picks"] = picks
	if data.target == UserItemData.Target.DICE:
		if target == null or not data.can_apply_to(target):
			return ""
		data.apply_to_dice(target, inst)
		if not data.is_consumed_on_apply():
			inventory.items.append(inst)
		refresh_item_rules()
		return "%s → %s 적용" % [data.display_name, target.data.display_name]
	var text: String = data.on_acquire(inst, self)
	inventory.items.append(inst)
	inventory.changed.emit()
	refresh_item_rules()
	return text if text != "" else "%s 획득" % data.display_name


func can_activate_item(inst: ItemInstance) -> bool:
	return is_preparing() and inventory.items.has(inst) and inst.data.can_activate(inst)


## 능동 아이템 사용 (저금통 깨기)
func activate_item(inst: ItemInstance, choice: Variant = null) -> String:
	if not can_activate_item(inst):
		return ""
	var text: String = inst.data.activate(inst, self) if choice == null else inst.data.activate_choice(inst, self, choice)
	if text == "":
		return ""
	if inst.data.is_consumed_on_activate():
		inventory.items.erase(inst)
	inventory.changed.emit()
	refresh_item_rules()
	return text


func acquire_tarot(card: TarotCardData) -> bool:
	if not inventory.has_tarot_space():
		return false
	inventory.tarot_hand.append(card)
	inventory.changed.emit()
	changed.emit()
	return true


## 타로 사용 가능 여부 ("" = 가능). 유닛칸 카드는 cell_index 필요.
func can_use_tarot(card: TarotCardData, cell_index: int = -1, cell_index_2: int = -1) -> String:
	if not is_preparing():
		return "준비 단계에서만 사용할 수 있습니다"
	if not inventory.tarot_hand.has(card):
		return "손에 없는 카드입니다"
	match card.category:
		TarotCardData.Category.RESERVE:
			if inventory.tarot_reserved.size() >= Inventory.MAX_RESERVED:
				return "전투 예약은 %d장까지입니다" % Inventory.MAX_RESERVED
		TarotCardData.Category.CELL:
			if cell_index < 0 or cell_index >= BoardState.CELL_COUNT:
				return "버프를 줄 내 배치 칸을 고르세요"
			if card.cells_required >= 2 and (cell_index_2 < 0 or cell_index_2 >= BoardState.CELL_COUNT or cell_index_2 == cell_index):
				return "연결할 두 번째 칸을 고르세요 (서로 다른 칸)"
		TarotCardData.Category.INTERFERE:
			return "1인용에서는 쓸 수 없는 카드입니다"
	return ""


## 타로 사용: 예약 / 즉시 설치 / 칸 지정
func use_tarot(card: TarotCardData, cell_index: int = -1, cell_index_2: int = -1) -> String:
	var reason: String = can_use_tarot(card, cell_index, cell_index_2)
	if reason != "":
		return reason
	inventory.tarot_hand.erase(card)
	match card.category:
		TarotCardData.Category.RESERVE:
			inventory.tarot_reserved.append(card)
		TarotCardData.Category.WALL:
			if card is TowerTarot:
				inventory.towers += 1
				inventory.tower_card = card
			elif card is JusticeTarot:
				player.justice_shield_max += (card as JusticeTarot).shield
				player.justice_shield += (card as JusticeTarot).shield
		TarotCardData.Category.CELL:
			var cells: Array[int] = [cell_index]
			if card.cells_required >= 2:
				board.add_link(cell_index, cell_index_2)
				cells.append(cell_index_2)
			elif card.cell_modifier != null:
				board.add_slot_modifier(cell_index, card.cell_modifier)
			for c: int in cells:
				if not inventory.cell_tarots.has(c):
					inventory.cell_tarots[c] = [] as Array[TarotCardData]
				(inventory.cell_tarots[c] as Array).append(card)
	inventory.changed.emit()
	changed.emit()
	return ""


## 예약 취소 (전투 전, 손으로 되돌리기)
func unreserve_tarot(card: TarotCardData) -> bool:
	if not is_preparing() or not inventory.tarot_reserved.has(card) or not inventory.has_tarot_space():
		return false
	inventory.tarot_reserved.erase(card)
	inventory.tarot_hand.append(card)
	inventory.changed.emit()
	changed.emit()
	return true


## 조커 보상: 랜덤 아이템 (대상 지정 아이템 제외). 획득한 이름 반환, 실패 시 ""
func grant_random_item() -> String:
	if not inventory.has_item_space():
		return ""
	var pool: Array[UserItemData] = []
	for d: UserItemData in ShopCatalog.item_pool(get_round()):
		if d.target == UserItemData.Target.NONE and (d.stackable or not inventory.owns_item(d.id)):
			pool.append(d)
	if pool.is_empty():
		return ""
	var pick: UserItemData = pool[rng.randi_range(0, pool.size() - 1)]
	acquire_item(pick)
	return pick.display_name


func grant_random_tarot() -> String:
	var pool: Array[TarotCardData] = ShopCatalog.tarot_pool(get_round())
	if pool.is_empty() or not inventory.has_tarot_space():
		return ""
	var pick: TarotCardData = pool[rng.randi_range(0, pool.size() - 1)]
	acquire_tarot(pick)
	return pick.display_name


# --- 무단 침입 통행증 ---------------------------------------------------------

## 첫 굴림 뒤(기록 전) 주사위 교체가 가능한가
func can_trespass_swap() -> bool:
	return phase == Phase.ROLLING and flow.phase == RoundFlow.Phase.ROLLING and inventory.get_rolling_swap_item() != null \
		and not deck.reserve_filled_indices().is_empty()


## 굴림 중 교체: 들어온 주사위는 바로 1번 굴려 결과를 채운다 (재굴림 횟수 소모 없음)
func trespass_swap(active_index: int, reserve_index: int) -> bool:
	if not can_trespass_swap():
		return false
	var item: ItemInstance = inventory.get_rolling_swap_item()
	if not deck.force_swap(active_index, reserve_index):
		return false
	item.state[TrespassItem.STATE_USED_ROUND] = get_round()
	flow.reroll_single(active_index)
	inventory.changed.emit()
	changed.emit()
	return true


func get_compression_threshold() -> int:
	return int(inventory.get_compression().get("threshold", BattleRules.get_compression_threshold()))
