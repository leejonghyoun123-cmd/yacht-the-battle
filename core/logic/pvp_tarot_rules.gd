class_name PvpTarotRules
extends RefCounted
## 상대 간섭 타로 4종 (05 문서 카테고리 D) — 2인 친선전에서 두 GameSession 사이에 적용하는 순수 로직.
## 1인용 상점 풀에서는 제외된다 (ShopCatalog.tarot_pool). 친선전 연결 시 이 함수들을 호출한다.


## 20. 저지먼트: 상대 칸 1개의 타로 영구 버프와 그 칸이 낀 더 러버 연결을 모두 해제
static func judgement(target: GameSession, cell_index: int) -> bool:
	if cell_index < 0 or cell_index >= BoardState.CELL_COUNT:
		return false
	target.board.clear_slot_tarots(cell_index)
	target.inventory.cell_tarots.erase(cell_index)
	# 연결 해제로 다른 칸에 남은 러버 표시도 정리
	for c: int in target.inventory.cell_tarots.keys():
		var cards: Array = target.inventory.cell_tarots[c]
		for i: int in range(cards.size() - 1, -1, -1):
			if (cards[i] as TarotCardData).cells_required >= 2 and not _has_link(target.board, c):
				cards.remove_at(i)
		if cards.is_empty():
			target.inventory.cell_tarots.erase(c)
	return true


static func _has_link(board: BoardState, cell: int) -> bool:
	for l: Vector2i in board.slot_links:
		if l.x == cell or l.y == cell:
			return true
	return false


## 15. 더 데빌: 나와 상대가 가진 주사위(출전+가방) 중 각자 무작위 1개 파괴.
## 주사위가 5개 이하면 지우지 않고 기본 6면으로 바뀐다 (destroy_dice가 출전 칸을 보충) — 5주사위 보장
static func devil(user: GameSession, target: GameSession, rng: RandomNumberGenerator) -> void:
	for s: GameSession in [user, target]:
		var all: Array[DiceInstance] = s.deck.all_dice()
		if all.is_empty():
			continue
		s.destroy_dice(all[rng.randi_range(0, all.size() - 1)])


## 13. 데스: 내 체력을 X만큼 깎고(1 ≤ X ≤ 현재 체력 - 1, 자살 불가) 상대 본체에 상한 무시 고정 피해 X
static func death(user: GameSession, target: GameSession, amount: int) -> int:
	var x: int = clampi(amount, 1, maxi(1, user.player.hp - 1))
	if user.player.hp <= 1:
		return 0
	user.player.take_damage(x)
	target.player.take_damage(x)
	return x


## 14. 템퍼런스: 이번 전투에 한해 두 칸(내 칸, 상대 칸)을 평균 상태로 맞춘다 (원본 배치판은 건드리지 않음).
## 병과는 인원이 많은 쪽, 인원은 평균, 보정은 합집합. 스폰 직전 패킷에만 적용한다.
static func temperance(mine: Array[SpawnPacket], my_cell: int, theirs: Array[SpawnPacket], their_cell: int) -> bool:
	var a: SpawnPacket = _find(mine, my_cell)
	var b: SpawnPacket = _find(theirs, their_cell)
	if a == null or b == null:
		return false
	var unit: UnitData = a.unit_data if a.total_count >= b.total_count else b.unit_data
	var avg: int = maxi(1, (a.total_count + b.total_count) / 2)
	var mods: Array[StatModifier] = a.modifiers.duplicate()
	for m: StatModifier in b.modifiers:
		if not mods.has(m):
			mods.append(m)
	for p: SpawnPacket in [a, b]:
		p.unit_data = unit
		p.total_count = avg
		p.modifiers = mods.duplicate()
	return true


static func _find(packets: Array[SpawnPacket], cell: int) -> SpawnPacket:
	for p: SpawnPacket in packets:
		if p.cell_index == cell:
			return p
	return null
