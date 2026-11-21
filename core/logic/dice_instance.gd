class_name DiceInstance
extends RefCounted
## 런타임 주사위 객체. 인첸트 슬롯(최대 5칸)과 연산 파이프라인을 가진다.
## 연산 순서: [굴림 전 면 변형] → [원시 눈금] → [유저 아이템] → [인첸트 슬롯 1→5] → [주사위 성질]
## UI(Control)에 의존하지 않는 순수 로직이다.

const MAX_SLOTS: int = 5

var data: DiceData
## 물리 슬롯 배열 (항상 MAX_SLOTS 길이, 빈 슬롯은 null)
var slots: Array[EnchantInstance] = []
var unlocked_slots: int = 3
## 주사위별 가변 상태 (X병 스택 등, 원본 .tres 오염 방지)
var runtime_state: Dictionary = {}


func _init(p_data: DiceData) -> void:
	data = p_data
	unlocked_slots = clampi(p_data.base_slots, 0, MAX_SLOTS)
	slots.resize(MAX_SLOTS)


# --- 슬롯 관리 -------------------------------------------------------------

## 빈 슬롯에 인첸트 장착. 잠긴 슬롯이나 이미 찬 슬롯이면 false.
func equip(instance: EnchantInstance, index: int) -> bool:
	if instance == null or index < 0 or index >= unlocked_slots:
		return false
	if slots[index] != null:
		return false
	slots[index] = instance
	return true


## 슬롯에서 인첸트를 꺼낸다 (빈 슬롯이면 null)
func unequip(index: int) -> EnchantInstance:
	if index < 0 or index >= unlocked_slots:
		return null
	var removed: EnchantInstance = slots[index]
	slots[index] = null
	return removed


## 슬롯 순서 변경: from 위치의 인첸트를 to 위치로 옮기고 사이의 슬롯을 한 칸씩 민다.
## (덱 잠금 여부 검사는 DeckManager가 담당)
func move_enchant(from: int, to: int) -> bool:
	if from == to:
		return false
	if from < 0 or to < 0 or from >= unlocked_slots or to >= unlocked_slots:
		return false
	var item: EnchantInstance = slots[from]
	slots.remove_at(from)
	slots.insert(to, item)
	return true


## 슬롯 영구 확장 (조각칼/핸드드릴). 실제로 늘어난 칸 수를 반환.
func unlock_slots(count: int) -> int:
	var before: int = unlocked_slots
	unlocked_slots = clampi(unlocked_slots + count, 0, MAX_SLOTS)
	return unlocked_slots - before


func get_enchants() -> Array[EnchantInstance]:
	var result: Array[EnchantInstance] = []
	for i: int in range(unlocked_slots):
		if slots[i] != null:
			result.append(slots[i])
	return result


# --- 굴림 전 (Pre-Roll) ----------------------------------------------------

## 굴림 전 인첸트가 적용된 면 배열. 면 삭제가 겹쳐도 최소 1면은 남는다.
func get_modified_faces(disabled_slot_indices: Array[int] = []) -> Array[int]:
	return _build_faces(null, disabled_slot_indices)


func _build_faces(ctx: RollContext, disabled_slot_indices: Array[int]) -> Array[int]:
	var faces: Array[int] = data.faces.duplicate()
	if faces.is_empty():
		faces = [1]
	var immune: bool = ctx != null and ctx.immune_to_boss_gimmicks
	for i: int in range(unlocked_slots):
		var inst: EnchantInstance = slots[i]
		if inst == null or inst.data.phase != EnchantData.Phase.PRE_ROLL:
			continue
		if not immune and disabled_slot_indices.has(i):
			if ctx != null:
				ctx.log_skip(inst.get_display_name(), "보스 기믹으로 슬롯 비활성")
			continue
		var candidate: Array[int] = inst.data.apply_pre_roll(faces, inst)
		if candidate.is_empty():
			# 면이 0개가 되는 필터는 적용하지 않는다 (최소 1면 보장)
			if ctx != null:
				ctx.log_skip(inst.get_display_name(), "모든 면이 사라져 적용 안 함")
			continue
		faces = candidate
		if ctx != null:
			ctx.log_step(inst.get_display_name(), "면 " + str(faces))
	return faces


# --- 굴림 및 굴림 후 (Post-Roll) -------------------------------------------

## 실제 굴림: 면 변형 → 결정론적 RNG로 눈금 추첨 → 파이프라인
func roll(ctx: RollContext) -> void:
	var faces: Array[int] = _build_faces(ctx, ctx.disabled_slot_indices)
	var raw: int = faces[ctx.rng.randi_range(0, faces.size() - 1)]
	run_pipeline(ctx, raw)


## 정해진 원시 눈금으로 파이프라인 실행 (재굴림 시 고정한 주사위, 미리보기 등)
func run_pipeline(ctx: RollContext, raw_roll: int) -> void:
	ctx.begin(raw_roll)
	_apply_user_items(ctx)
	_apply_enchant_slots(ctx)
	_apply_dice_trait(ctx)


## 개발 규칙 1번의 시그니처: 원시 눈금 → 최종 소환값(정수)
func calculate_final_value(raw_roll: int, round_number: int = 1) -> int:
	var ctx: RollContext = RollContext.new(null, round_number)
	run_pipeline(ctx, raw_roll)
	return ctx.get_summon_value()


## UI 미리보기용: 나올 수 있는 면별 최종 소환값 { 면: 소환값 }
func preview_outcomes(round_number: int = 1) -> Dictionary:
	var result: Dictionary = {}
	for face: int in get_modified_faces():
		result[face] = calculate_final_value(face, round_number)
	return result


## [유저 아이템 반영] 단계 — 아이템 시스템 구현 시 연결
func _apply_user_items(_ctx: RollContext) -> void:
	pass


## [인첸트 슬롯 1→5 순차 적용] 단계
func _apply_enchant_slots(ctx: RollContext) -> void:
	var previous_index: int = -1
	for i: int in range(unlocked_slots):
		# 증폭 코어 예약 배율은 바로 다음 1개 슬롯에만 적용된다
		ctx.next_slot_power_multiplier = ctx.pending_power_multiplier
		ctx.pending_power_multiplier = 1.0
		var inst: EnchantInstance = slots[i]
		if inst != null and inst.data.phase == EnchantData.Phase.POST_ROLL:
			if not ctx.immune_to_boss_gimmicks and ctx.disabled_slot_indices.has(i):
				ctx.log_skip(inst.get_display_name(), "보스 기믹으로 슬롯 비활성")
			elif inst.data.is_copy_enchant:
				_apply_copy(ctx, inst, previous_index)
			else:
				inst.data.apply_post_roll(ctx, inst)
		previous_index = i
	ctx.next_slot_power_multiplier = 1.0
	ctx.pending_power_multiplier = 1.0


## 복사 계열 인첸트 (메아리): 직전 슬롯을 1회 추가 발동. 재귀 깊이 1 강제.
func _apply_copy(ctx: RollContext, copier: EnchantInstance, previous_index: int) -> void:
	var name: String = copier.get_display_name()
	if previous_index < 0:
		ctx.log_skip(name, "직전 슬롯 없음")
		return
	var target: EnchantInstance = slots[previous_index]
	if target == null:
		ctx.log_skip(name, "직전 슬롯이 비어 있음")
		return
	if not ctx.immune_to_boss_gimmicks and ctx.disabled_slot_indices.has(previous_index):
		ctx.log_skip(name, "직전 슬롯이 비활성 상태")
		return
	if target.data.is_copy_enchant:
		ctx.log_skip(name, "복사 인첸트는 복사할 수 없음")
		return
	if target.data.phase == EnchantData.Phase.PRE_ROLL:
		ctx.log_skip(name, "굴림 전 인첸트는 복사할 수 없음")
		return
	var log_start: int = ctx.logs.size()
	# 대상의 apply_post_roll만 호출하므로 복사가 다시 복사를 부르는 재귀는 구조적으로 불가능
	target.data.apply_post_roll(ctx, target)
	for k: int in range(log_start, ctx.logs.size()):
		ctx.logs[k]["source"] = "%s → %s" % [name, target.get_display_name()]


## [주사위 성질 반영] 단계 — 성질 시스템 구현 시 연결
func _apply_dice_trait(_ctx: RollContext) -> void:
	pass
