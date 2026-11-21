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
## 주사위 성질 (03 문서, 1개). null = 성질 없음
var trait_data: DiceTraitData = null

const STATE_FACE_WEIGHTS: String = "face_weights"
const STATE_REVERSE_SLOTS: String = "reverse_slots"
## 사포와펜: [Vector2i(지운 면, 새긴 숫자)]
const STATE_FACE_REPLACE: String = "face_replace"


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
	if trait_data != null:
		faces = trait_data.modify_base_faces(faces, self)
	for rep: Vector2i in runtime_state.get(STATE_FACE_REPLACE, []):
		for k: int in range(faces.size()):
			if faces[k] == rep.x:
				faces[k] = rep.y
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
	if trait_data != null:
		trait_data.prepare_context(ctx, self)
	var faces: Array[int] = _build_faces(ctx, ctx.disabled_slot_indices)
	var raw: int = _pick_face(faces, ctx.rng)
	if trait_data != null:
		raw = trait_data.override_raw(raw, self)
		trait_data.on_rolled(ctx, self)
	run_pipeline(ctx, raw)


## 가중치 추첨 (속임 무게추: runtime_state["face_weights"] = { 면: 가중치 })
func _pick_face(faces: Array[int], rng: RandomNumberGenerator) -> int:
	var weights: Dictionary = runtime_state.get(STATE_FACE_WEIGHTS, {})
	if weights.is_empty():
		return faces[rng.randi_range(0, faces.size() - 1)]
	var total: float = 0.0
	for f: int in faces:
		total += float(weights.get(f, 1.0))
	var pick: float = rng.randf() * total
	for f: int in faces:
		pick -= float(weights.get(f, 1.0))
		if pick <= 0.0:
			return f
	return faces[faces.size() - 1]


## 정해진 원시 눈금으로 파이프라인 실행 (재굴림 시 고정한 주사위, 미리보기 등)
func run_pipeline(ctx: RollContext, raw_roll: int) -> void:
	if trait_data != null:
		trait_data.prepare_context(ctx, self)
	ctx.begin(raw_roll)
	_apply_user_items(ctx)
	_apply_enchant_slots(ctx)
	_apply_dice_trait(ctx)
	_apply_user_items_final(ctx)


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


## [유저 아이템 반영] 단계: 원시 눈금 트리거 (우선순위 순: 50이좋아 → +? 곱? → ?의 향연)
func _apply_user_items(ctx: RollContext) -> void:
	for item: ItemInstance in ctx.items:
		item.data.on_raw_trigger(ctx, item, self)


## 성질까지 끝난 뒤 아이템 최종 보정 (빈 슬롯의 미학, 벤치 응원봉, 오버플로우 배터리, 끝자리 세탁기)
func _apply_user_items_final(ctx: RollContext) -> void:
	for item: ItemInstance in ctx.items:
		item.data.on_final(ctx, item, self)


## [인첸트 슬롯 1→5 순차 적용] 단계
func _apply_enchant_slots(ctx: RollContext) -> void:
	var previous_index: int = -1
	# 역방향 기어: 슬롯을 5→1 순서로 연산 (보스 9R 정지는 물리 슬롯 번호 기준 그대로)
	var order: Array[int] = []
	for k: int in range(unlocked_slots):
		order.append(k)
	if bool(runtime_state.get(STATE_REVERSE_SLOTS, false)):
		order.reverse()
	for i: int in order:
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


## [주사위 성질 반영] 단계
func _apply_dice_trait(ctx: RollContext) -> void:
	if trait_data != null:
		trait_data.on_post_pipeline(ctx, self)


## 성질 붙이기 (상점 변환). 붙일 수 없으면 false.
func attach_trait(p_trait: DiceTraitData, rng: RandomNumberGenerator) -> bool:
	if p_trait == null or not p_trait.can_attach_to(self):
		return false
	trait_data = p_trait
	p_trait.on_attach(self, rng)
	return true


## 화면 표시용 눈금 글자 (포커카드면 A/J/Q/K)
func face_label(value: int) -> String:
	return trait_data.face_label(value) if trait_data != null else str(value)


## 주사위 짧은 이름 (아이콘 글자)
func get_short_name() -> String:
	if trait_data != null:
		return trait_data.get_badge_text(self)
	return String(data.id)


## 부작용 없는 기대값 (주사위 복제 거울 등): 나올 수 있는 면의 최종 소환값 평균 (조커·파괴·체력 변화 없음)
func simulate_expected_value(round_number: int = 1) -> int:
	var faces: Array[int] = get_modified_faces()
	if faces.is_empty():
		return 1
	var total: int = 0
	for f: int in faces:
		var raw: int = trait_data.override_raw(f, self) if trait_data != null else f
		total += calculate_final_value(raw, round_number)
	return maxi(1, roundi(float(total) / float(faces.size())))
