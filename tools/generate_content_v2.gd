extends SceneTree
## 주사위 성질 10종 · 타로카드 17종(1인용) · 유저 아이템 19종 .tres 생성. 이미 있는 파일은 덮어쓰지 않는다.
## 등급(C/B/A/S)은 쓸모·위력 기준 임시값 — 가격은 GameBalance.*_PRICE_BY_RANK
## 실행: godot --headless --path <프로젝트> --script res://tools/generate_content_v2.gd

const C: int = 0
const B: int = 1
const A: int = 2
const S: int = 3


func _initialize() -> void:
	for dir: String in ["res://data/traits/", "res://data/tarots/", "res://data/items/"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_traits()
	_tarots()
	_items()
	quit(0)


# --- 주사위 성질 -------------------------------------------------------------

func _traits() -> void:
	_trait(BoneTrait.new(), &"bone", "뼈주사위", "뼈", Color("e8e2d0"), B,
		"보스 연산 기믹·저주를 완전히 무시한다.\n소환 유닛 최대 체력 +25%, 받는 피해 -15%.")
	var blood: BloodTrait = BloodTrait.new()
	blood.final_multiplier = 2.5
	_trait(blood, &"blood", "피주사위", "피", Color("e05a5a"), A,
		"최종 소환값 ×2.5.\n확정 시 원시 눈금만큼 체력 소모 (최대 50, 체력 1 아래로는 안 내려감).")
	var glass: GlassTrait = GlassTrait.new()
	glass.final_multiplier = 3.0
	_trait(glass, &"glass", "유리주사위", "유리", Color("bfe9f2"), A,
		"최종 소환값 ×3.\n출전해 굴린 라운드가 끝나면 25% 확률로 깨진다 (인첸트는 자동 회수).")
	_trait(FairyTrait.new(), &"fairy", "요정의 주사위", "요정", Color("f4c6f0"), C,
		"확정 시 원시 눈금만큼 체력 회복 (최대 30).")
	_trait(XBottleTrait.new(), &"xbottle", "1회용 X병 주사위", "X병", Color("a7d38a"), B,
		"가방에 있어도 매 라운드 스택 +25 (최대 500).\n출전하면 눈금 대신 스택값으로 연산하고, 라운드가 끝나면 사라진다.")
	_trait(JokerTrait.new(), &"joker", "조커의 랜덤주사위", "조커", Color("c79bff"), B,
		"굴릴 때마다 결과 1개 추첨, 확정 시 발동.\n보상 70%: 아이템 / 타로 / 소환값 ×2 / 체력 30% 회복\n저주 30%: 체력 -20% / 소환값 ×0.5")
	var mirror: MirrorTrait = MirrorTrait.new()
	mirror.roll_pass = DiceTraitData.RollPass.MIRROR
	_trait(mirror, &"mirror", "거울 주사위", "거울", Color("d6dde8"), A,
		"굴리지 않고 바로 왼쪽 출전 주사위의 최종값을 복사한다.\n맨 왼쪽이거나 왼쪽도 거울이면 1.")
	var magnet: MagnetTrait = MagnetTrait.new()
	magnet.roll_pass = DiceTraitData.RollPass.MAGNET
	_trait(magnet, &"magnet", "자석 주사위", "자석", Color("ff8a7a"), B,
		"굴린 뒤 50% 확률로 다른 주사위 눈금의 최빈값(동률이면 큰 수)으로 맞춘다.")
	var gold: GoldTrait = GoldTrait.new()
	gold.final_multiplier = 0.7
	_trait(gold, &"gold", "황금 주사위", "황금", Color("ffd34d"), B,
		"최종 소환값 ×0.7.\n확정 시 최종 연산값의 50%만큼 골드 획득.")
	var overload: OverloadTrait = OverloadTrait.new()
	overload.final_multiplier = 2.0
	_trait(overload, &"overload", "과부하 주사위", "과부하", Color("ffa64d"), B,
		"최종 소환값 ×2.\n칸에 쌓이지 않는 이번 라운드 한정 병력 (승리 시 생존자 판매).")


func _trait(t: DiceTraitData, p_id: StringName, p_name: String, p_badge: String, p_color: Color, p_rank: int, desc: String) -> void:
	t.id = p_id
	t.display_name = p_name
	t.badge = p_badge
	t.color = p_color
	t.rank = p_rank as DiceTraitData.Rank
	t.description = desc
	_save(t, "res://data/traits/%s.tres" % p_id)


# --- 타로카드 ----------------------------------------------------------------

func _tarots() -> void:
	var RESERVE: TarotCardData.Category = TarotCardData.Category.RESERVE
	var WALL: TarotCardData.Category = TarotCardData.Category.WALL
	var CELL: TarotCardData.Category = TarotCardData.Category.CELL
	_tarot(FoolTarot.new(), &"fool", 0, "더 풀", B, RESERVE, null,
		"[예약] 전투 내내 양 팀 모든 유닛 공격력 ×2, 받는 피해 ×1.5.")
	_tarot(StarTarot.new(), &"star", 17, "더 스타", A, RESERVE, null,
		"[예약] 교전 10초 동안 0.5초마다 적 진영에 별똥별 (반경 120, 최대 체력 8% + 10).")
	_tarot(MoonTarot.new(), &"moon", 18, "더 문", B, RESERVE, null,
		"[예약] 교전 시작 후 10초간 아군 전체 공격 속도 +60%.")
	_tarot(SunTarot.new(), &"sun", 19, "더 썬", A, RESERVE, null,
		"[예약] 교전 3초에 적 밀집 지점에 투하 (반경 180).\n적: 5초간 초당 최대 체력 6% 화염 / 아군: 최대 체력 30% 회복.")
	_tarot(WorldTarot.new(), &"world", 21, "더 월드", S, RESERVE, null,
		"[예약] 아군 체력 합이 시작 대비 30% 이하가 되면 전투 무효.\n체력 피해 없음, 연승·연패 유지, 소비칸 유지, 위로금 +200.")
	_tarot(TowerTarot.new(), &"tower", 16, "더 타워", A, WALL, null,
		"[설치] 내 성벽에 영구 번개 포탑. 2초마다 적 3체 연쇄 번개\n(라운드 × 3 + 최대 체력 5%). 여러 장이면 장당 +50%.")
	_tarot(JusticeTarot.new(), &"justice", 11, "저스티스", B, WALL, null,
		"[설치] 매 라운드 본체 실드 +35 자동 충전 (여러 장이면 누적).")
	_tarot(TarotCardData.new(), &"magician", 1, "더 매지션", B, CELL,
		StatModifier.make("더 매지션: 광역·마법 피해 ×1.5", { "magical_mult": 1.5, "splash_damage_mult": 1.5 }),
		"[칸 지정] 그 칸 유닛의 광역·마법 피해 ×1.5.")
	_tarot(TarotCardData.new(), &"high_priestess", 2, "더 하이프리스티스", B, CELL,
		StatModifier.make("하이프리스티스: 받는 피해 -25%", { "damage_taken_mult": 0.75 }),
		"[칸 지정] 그 칸 유닛의 받는 피해 -25%.")
	_tarot(TarotCardData.new(), &"empress", 3, "더 엠프레스", A, CELL,
		StatModifier.make("엠프레스: 초당 체력 4% 회복", { "regen_ratio": 0.04 }),
		"[칸 지정] 그 칸 유닛이 전투 중 매초 최대 체력 4% 회복.")
	_tarot(TarotCardData.new(), &"emperor", 4, "더 엠페러", A, CELL,
		StatModifier.make("엠페러: 공격 +25%, 받는 피해 -15%, 크기 +20%", { "attack_mult": 1.25, "damage_taken_mult": 0.85, "size_mult": 1.2 }),
		"[칸 지정] 그 칸 유닛 공격력 +25%, 받는 피해 -15%, 크기 +20%.")
	_tarot(TarotCardData.new(), &"hierophant", 5, "더 하이로펀트", B, CELL,
		StatModifier.make("하이로펀트: 체력 30% 실드", { "shield_ratio": 0.3 }),
		"[칸 지정] 그 칸 유닛이 전투 시작 시 최대 체력 30% 실드.")
	_tarot(TarotCardData.new(), &"chariot", 7, "더 체리엇", B, CELL,
		StatModifier.make("체리엇: 이동 +35%, 공속 +30%", { "move_mult": 1.35, "haste_mult": 1.3 }),
		"[칸 지정] 그 칸 유닛 이동 속도 +35%, 공격 속도 +30%.")
	_tarot(TarotCardData.new(), &"strength", 8, "스트렝스", B, CELL,
		StatModifier.make("스트렝스: 물리 피해 ×1.5", { "physical_mult": 1.5 }),
		"[칸 지정] 그 칸 유닛의 물리 피해 ×1.5.")
	_tarot(TarotCardData.new(), &"hermit", 9, "더 허밋", C, CELL,
		StatModifier.make("허밋: 첫 5초 면역·타겟 불가", { "immune_seconds": 5.0 }),
		"[칸 지정] 그 칸 유닛이 교전 시작 후 5초간 피해 면역·타겟 불가.")
	var wheel: RandomStatModifier = RandomStatModifier.new()
	wheel.display_name = "휠 오브 포츈: 전투마다 무작위 1종"
	wheel.pool = [
		StatModifier.make("휠: 공격력 ×2", { "attack_mult": 2.0 }),
		StatModifier.make("휠: 공격 속도 ×2", { "haste_mult": 2.0 }),
		StatModifier.make("휠: 최대 체력 ×2", { "hp_mult": 2.0 }),
		StatModifier.make("휠: 체력 60% 실드", { "shield_ratio": 0.6 }),
		StatModifier.make("휠: 모든 스탯 ×1.5", { "attack_mult": 1.5, "hp_mult": 1.5, "haste_mult": 1.5 }),
	]
	_tarot(TarotCardData.new(), &"wheel", 10, "휠 오브 포츈", B, CELL, wheel,
		"[칸 지정] 전투마다 그 칸에 무작위 증폭 1종\n(공격 ×2 / 공속 ×2 / 체력 ×2 / 실드 60% / 모든 스탯 ×1.5).")
	_tarot(TarotCardData.new(), &"hanged_man", 12, "더 행맨", A, CELL,
		StatModifier.make("행맨: 받는 피해 -40%", { "damage_taken_mult": 0.6 }),
		"[칸 지정] 그 칸 유닛의 받는 피해 -40%.")


func _tarot(t: TarotCardData, p_id: StringName, numeral: int, p_name: String, p_rank: int,
		category: TarotCardData.Category, mod: StatModifier, desc: String) -> void:
	t.id = p_id
	t.numeral = numeral
	t.display_name = p_name
	t.rank = p_rank as TarotCardData.Rank
	t.category = category
	t.cell_modifier = mod
	t.description = desc
	_save(t, "res://data/tarots/%s.tres" % p_id)


# --- 유저 아이템 -------------------------------------------------------------

func _items() -> void:
	_item(DidntRollItem.new(), &"didnt_roll", "나 안굴렸는데?", "↻+1", A, 50, "매 라운드 재굴림 +1 (영구).")
	var chisel: SlotExpandItem = SlotExpandItem.new()
	chisel.amount = 1
	chisel.target = UserItemData.Target.DICE
	_item(chisel, &"chisel", "조각칼", "+1칸", C, 50, "고른 주사위의 인첸트 슬롯 +1 (최대 5칸).")
	var drill: SlotExpandItem = SlotExpandItem.new()
	drill.amount = 2
	drill.target = UserItemData.Target.DICE
	drill.price_override = 350
	_item(drill, &"hand_drill", "핸드드릴", "+2칸", B, 50, "고른 주사위의 인첸트 슬롯 +2 (최대 5칸).")
	var weighted: WeightedDiceItem = WeightedDiceItem.new()
	weighted.target = UserItemData.Target.DICE
	_item(weighted, &"weighted_dice", "속임 무게추", "⚖", B, 50, "고른 주사위의 가장 큰 면이 나올 확률이 3배가 된다 (영구).")
	_item(LoveFiftyItem.new(), &"love_fifty", "50이좋아", "50", B, 10, "지정 눈금(획득 시 1~6 중 결정)이 나오면 연산 시작값을 50으로.")
	_item(ConditionalMathItem.new(), &"conditional_math", "+? 곱?", "+×", C, 20, "지정 눈금이 나오면 +10 또는 ×2 (획득 시 결정).")
	_item(FeastItem.new(), &"feast", "?의 향연", "향연", C, 30, "지정 눈금이 나오면 보너스 1개:\n이번 굴림 ×2 / 확정 시 +60원 / 확정 시 실드 +25.")
	var reverse: ReverseGearItem = ReverseGearItem.new()
	reverse.target = UserItemData.Target.DICE
	_item(reverse, &"reverse_gear", "역방향 기어", "⇄", C, 50, "고른 주사위의 인첸트를 5→1 역순으로 연산 (영구).")
	var overflow: FinalBonusItem = FinalBonusItem.new()
	overflow.mode = FinalBonusItem.Mode.OVERFLOW
	_item(overflow, &"overflow_battery", "오버플로우 배터리", "⚡", C, 60, "연산 중 0 아래로 떨어진 만큼을 최종값에 더한다.")
	var washer: FinalBonusItem = FinalBonusItem.new()
	washer.mode = FinalBonusItem.Mode.LAST_DIGIT
	_item(washer, &"last_digit_washer", "끝자리 세탁기", "□9", A, 90, "모든 주사위의 최종값 1의 자리를 9로 올린다 (12 → 19).", false)
	var empty: FinalBonusItem = FinalBonusItem.new()
	empty.mode = FinalBonusItem.Mode.EMPTY_SLOT
	empty.per_unit_bonus = 0.25
	_item(empty, &"empty_slot", "빈 슬롯의 미학", "○", B, 70, "개방됐지만 비어 있는 인첸트 슬롯 1칸당 최종값 +25%.")
	var bench: FinalBonusItem = FinalBonusItem.new()
	bench.mode = FinalBonusItem.Mode.BENCH
	bench.per_unit_bonus = 0.1
	_item(bench, &"bench_cheer", "벤치 응원봉", "📣", B, 70, "가방 속 주사위 1개당 출전 주사위 최종값 +10%.")
	_item(DiceMirrorItem.new(), &"dice_mirror", "주사위 복제 거울", "◫", A, 50, "얏츠판 기록 시 가방 맨 앞 주사위의 기대값만큼 1회 추가 소환 (쿨타임 3라운드).", false)
	var piggy: PiggyBankItem = PiggyBankItem.new()
	piggy.per_round = 150
	_item(piggy, &"piggy_bank", "돼지저금통", "🐷", B, 50, "매 라운드 +150원 적립. 준비 단계에 [깨기]로 전액 획득.")
	var dice_piggy: PiggyBankItem = PiggyBankItem.new()
	dice_piggy.per_round = 50
	dice_piggy.dice_multiplier = true
	_item(dice_piggy, &"dice_piggy_bank", "주사위저금통", "🎲", B, 50, "매 라운드 +50원 적립. [깨기] 시 1~6배를 굴려 획득.")
	_item(LoanSharkItem.new(), &"loan_shark", "고리대금 계약서", "₩", B, 50, "즉시 +800원. 이후 3라운드 동안 얏츠판·연승 보상의 50%를 자동 상환.", false)
	_item(HandForgeryItem.new(), &"hand_forgery", "족보 위조권", "✎", A, 50, "스트레이트 숫자 1개 누락 허용, 4개 동일도 얏츠 인정.", false)
	_item(InsuranceItem.new(), &"insurance", "패배 보험 증서", "보험", C, 50, "전투에서 지면 이번 라운드에 새로 소환한 인원의 40%만큼 골드 환급.")
	_item(BarracksCopierItem.new(), &"barracks_copier", "병영 복사기", "⎘", A, 50, "전투마다 가장 적은 중첩칸에 가장 많은 중첩칸의 30%를 임시 증원.", false)


func _item(it: UserItemData, p_id: StringName, p_name: String, p_icon: String, p_rank: int, p_priority: int, desc: String, p_stackable: bool = true) -> void:
	it.id = p_id
	it.display_name = p_name
	it.icon_text = p_icon
	it.rank = p_rank as UserItemData.Rank
	it.priority = p_priority
	it.description = desc
	it.stackable = p_stackable
	_save(it, "res://data/items/%s.tres" % p_id)


func _save(r: Resource, path: String) -> void:
	if ResourceLoader.exists(path):
		print("건너뜀 (이미 존재): ", path)
		return
	var err: Error = ResourceSaver.save(r, path)
	print("생성: " if err == OK else "실패(%d): " % err, path)
