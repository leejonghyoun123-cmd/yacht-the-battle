# 야추 더 배틀 (Yacht The Battle) — 개발 가이드

## 기준 문서
- 기획/구현 프롬프트 원본: `C:\Users\cv045\Desktop\YTB\Game Design Document Prompt\` (00~07, 개발절대규칙.txt)
- 개발 절대 규칙(정적 타이핑, Resource 전략 패턴, 로직/UI 분리, .tscn 직접 생성 금지, 4대 방어 규칙)은 `개발절대규칙 .txt`를 따른다.
- 엔진: Godot 4.7 (Steam판), GDScript 전용.

## 문서 충돌 확정 사항
- 보스 라운드: 06 레벨 디자인 기준 3·6·9·12·15R. 피격 상한 1~6R 75 / 7~12R 100 / 13R~ 무제한.
- 인첸트 수치: 02 기준 (합연산 +3/+7/+15 등).
- 포커카드: 03 기준 1~13 (A~K).
- 굴림 순서: 02의 5-Pass (일반 → 자석 → Cross-Dice → 거울 → 족보 연동).
- 3R·6R 보스 감소: 얏츠판 판정 후, 소환 인원에만 적용.

## 핵심 규칙 확정 사항
- 소환: 주사위마다 따로 소환하며, 소환 전에 병과를 선택한다.
- 배치판: 3x3. **9칸 모두 중첩칸** (2026-11-22 변경, 소비칸 폐지 — GameBalance.ALL_CELLS_STACK=false면 예전 방식: 가운데 열만 중첩칸, 좌우 소비칸). 한 칸에는 한 병과만 들어간다.
- 중첩칸 인원은 전투 사망으로 줄지 않는다. 바뀔 수 있으므로 교체 가능한 정책으로 구현한다.
- 얏츠판: 매 라운드 1항목을 반드시 기록하고, 맞는 족보가 없으면 0원으로 기록한다. 상·하단 모두 최종값의 **1의 자리**로 판정하며, 합도 1의 자리 합이다.
  - 1의 자리 0: 상단 해당 없음 / 스트레이트는 0~9 연속(9→0 순환 없음, 0·1·2·3·4 = 라지) / 포카드·풀하우스·얏츠에서 일반 숫자로 셈 / 합에는 0으로 더함.
- 솔로: 승리 = 통과, 패배 = 적 생존 환산 인원만큼 체력 차감(상한 적용), 체력 0 = 게임 오버.
- 적 환산 인원은 구성 병과별로 균등 분배하고, 병과마다 한 칸씩 압축한다.
- 경제·병과 수치는 임시값으로 시작해 플레이하며 조정한다.
- 숫자: 연산 중 소수점 1자리 유지(내부는 값×10 정수, `FixedNum`), 조건 판정은 정수부, 최종 소환값 확정 시 1회 반올림. int64 상한에서 포화.
- 메아리 등 미발동 슬롯은 로그에 사유를 남겨 UI에 명확히 표기한다.
- 얏츠(5개 동일)는 포카드로 인정, 풀하우스(정확히 3+2)로는 불인정.
- 광역 병과는 캐논(분기 2: 연발 포격).
- (예전 방식 전용) 소비칸: 승패와 무관하게 매 라운드 비워진다. 승리 시에만 생존자를 판매. 기본 방식에서는 과부하 주사위 인원만 이번 라운드 한정(승리 시 판매).
- 전투 제한 60초. 초과 시 남은 환산 체력이 더 많은 쪽이 승리한다.
- 거인 합체 수: 소환 30명 이하면 1명, 100명 이하면 2명, 그 이상이면 3명. 능력치는 소환 인원을 거인 수로 나눈 만큼 합산한다.
- 중첩칸(고정 유닛)은 준비 단계에 언제든 판매 가능. 판매가는 칸의 총 누적 인원(스폰 50이어도 누적 300이면 300)에 비례한다.
- 솔로 승리 보상: 기본 +50과 연승 보상. 패배 시에는 연패 보상과 체력 피해만 받는다.
- 실행: Godot 4.7.2 `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`. 테스트는 `--headless --script`로 실행.

## 화면·전투 연출 규칙 (기획서 외 추가 지시)
- 아이소메트릭 배경 + 탑뷰 기반 전쟁 전략 게임. 배치판은 정사각형 9칸(3x3).
- 내 화면에서는 항상 내 유닛이 좌측 위, 적이 우측 아래. 멀티에서도 각자 자기 병사가 좌측 위로 보이도록 화면을 따로 그린다.
- 배치 확정 → 유닛이 달려나와 배치대로 진열 재정비 → 3초 뒤 호각 → 전투 시작.
- 3x3 방향: 행 = 후열·중열·전열, 전열이 적 쪽. (9칸 모두 중첩칸)
- 적 배치: 탱커 전열 / 근거리 중열 / 원거리 후열 기본 자동 배치.
- 카메라: 준비 단계는 내 연병장만 비춤 → 준비 완료 시 중앙 필드로 카메라 이동 → 양측 문이 열리고 가운데로 달려나와 재진열 → 3초 후 호각.
- 정보: 솔로는 우측 상단 UI에 적 상태 힌트. 친선 2인은 준비 단계에 상대 병력을 숨기고 전투 시작 후에 공개.
- 칸 내 진열: 50명은 사각 대형(7x7+1), 1~3명 병과는 칸 중앙. 비주얼 확인 후 변경 가능.
- 구현 원칙: 전투 시뮬레이션은 화면과 무관한 논리 좌표에서 돌리고, 아이소 변환·좌우 반전은 렌더링 단계에서만 한다.

## 배운 점
(한 줄씩 추가하고, 쌓이면 중복을 정리한다)
- 새 class_name 스크립트를 추가하면 `--headless --path . --import`로 클래스 캐시를 갱신한 뒤 `--script` 테스트를 실행한다.
- .tres 데이터는 손으로 쓰지 않고 `tools/generate_data.gd`(ResourceSaver)로 생성한다. 이미 있는 파일은 덮어쓰지 않는다.
- 테스트: `godot --headless --path . --script res://tests/test_core_logic.gd`, `res://tests/test_round_flow.gd` (실패 시 종료 코드 1).
- 프로토타입 UI는 노드를 스크립트 코드로 생성하고, 씬에는 루트 Control + 스크립트만 둔다 (인스펙터 연결 누락 방지).
- UI 다시 그리기는 `call_deferred`로 미룬다. 버튼 시그널 처리 중에 그 버튼을 지우면 오류 위험.
- 에디터가 열려 있을 때 헤드리스 `--import`를 돌리면 `.godot` UID 캐시가 어긋날 수 있다("Unrecognized UID" → 메인 씬 실행 실패). 이때는 에디터에서 [프로젝트 → 현재 프로젝트 다시 불러오기].
- RefCounted끼리 서로 참조(유닛 target 등)하면 순환 참조로 해제되지 않는다. 끝날 때 참조를 null로 끊는다.
- 테스트 스위트: test_core_logic(65), test_round_flow(42), test_battle(63, 성능 측정 포함), test_game_session(26, 15R 자동 플레이 밸런스 리포트), test_shop(68), test_placement_and_swap(17).
- 코드로 만든 Control 루트는 `set_anchors_and_offsets_preset(FULL_RECT)`를 쓴다. `set_anchors_preset`만 쓰면 크기 0으로 남아 화면 배치가 틀어진다. 화면 구석 배치는 앵커+position 대신 컨테이너(UiKit.overlay_layout)로 한다.
- UI 위치·크기·색은 `ui/ui_config.gd`(UiConfig)에 모은다. 기준 해상도 1280x720은 GameRoot가 코드로 설정한다 (에디터가 project.godot를 덮어쓸 수 있어 코드 쪽이 안전).
- 상점 규칙: 식량·성벽은 매 라운드 상시 진열, 같은 라운드 재구매 시 +100원씩 비싸짐. 인첸트는 인벤토리 없이 구매 즉시 빈 슬롯에 장착. 굴린 주사위의 인첸트는 기록지에 기록할 때까지만 고정(DeckManager.can_edit_enchants). 주사위 자체 판매·성질 변환은 라운드 끝까지 잠금(can_edit_dice).
- 연출용 Tween은 참조를 들고 있다가 스킵·화면 전환 시 kill()한다. 남은 콜백이 나중에 상태를 다시 바꾼다.
- 화면 확인: 창 모드(`--headless` 없이)로 SceneTree 러너를 실행해 `root.get_texture().get_image().save_png()`로 스크린샷을 찍는다.
- 유닛배치 화면(코드상 barracks) = 배치 화면 (나인킹즈 방식). 화면 표기는 "유닛배치". 다른 병과 칸에 배치하면 확인 후 기존 유닛 자동 판매(이번 라운드 배치분은 주사위로 되돌림). 별도 배치 화면 없음.
- 굴림 화면(ui/roll_ui.gd): 왼쪽 종이 기록지, 가운데 위 주사위 쟁반(굴리는 출전 주사위, 고정 시 고정한 순서대로 선반 왼쪽부터), 아래 대기(가방) 주사위. 주사위 위 [⇅ 교체] 버튼 → 가방 주사위 선택해 교체. 아래 곡선 슬롯. [전체 교체]는 가방 주사위 수만큼 출전 주사위 선택. 굴림 연출은 화면 전용 RNG(게임 결과와 무관).
- 참고 예시 이미지: C:\Users\cv045\Desktop\YTB\ (상점·주사위 UI·굴리는 곳). 다른 게임 화면은 배치·구조만 참고하고 외형은 따라 하지 않는다.
- 굴리기는 버튼이 아니라 주사위통(ui/widgets/dice_cup.gd)을 누른 채 흔들고 놓아서 한다. 리롤 가격 25→50→75원(라운드마다 초기화).
- 유닛배치: 패에서 주사위 선택 → 왼쪽에 크게 표시 → 칸 클릭. 유닛 있는 칸 = 그 병과로 바로 투입, 빈 칸 = 칸 둘레에 병과 버튼 링이 피어남, 우클릭 = 다른 병과로 교체. [전투 시작]은 오른쪽 아래. 배치하면 패에서 사라지고 선택이 풀린다. 전투가 끝나면 상점으로 간다(정산 버튼 "상점으로").
- 주사위 테이블: 굴리기를 다 쓰면 기록지가 금빛으로 맥동, 기록하면 0.45초 뒤 자동으로 유닛배치 화면 (배치하러 가기 버튼 없음).
- 준비 화면 전환은 GameRoot._slide (탭 순서 유닛배치·주사위·상점 방향으로 EXPO ease-out 슬라이드). 유닛배치는 BattleView.set_screen_shift로 뒤 연병장도 같이 민다.
- 상점: 왼쪽 간판(widgets/shop_sign)·알림·판매/리롤/돌아가기, 오른쪽 붉은 테두리 진열대 2줄(카드가 폭을 채움) + 가격 꼬리표(widgets/price_tag).
- 에디터에 열려 있는 씬을 밖에서 지우면 에디터가 다시 저장해 되살린다. 씬 파일을 지울 땐 사용자에게 에디터 탭을 닫아 달라고 한다.
- 얏츠판 12칸: 에이스~식스(1의 자리) + 초이스(1의 자리 전부의 합) + 하단 5. 12칸 완성 시 프레스티지.
- 준비시간 2분 + 1회 30초 연장은 친선전 전용 (GameSession.new(seed, use_prep_timer=true)). 솔로는 타이머 없음 — 시스템(RoundTimer)은 유지. 거인(·킹)은 포커카드 에이스 전용 — 일반 주사위 배치 목록에 없음(GameSession.can_use_unit).
- 마우스 위치는 get_global_mouse_position() 대신 입력 이벤트 좌표를 쓴다 (리게임 직후 등 갱신이 늦어 컵·칸 클릭이 어긋난 적 있음).
- test_streak(14): 연패 보상 지급 확인.
- 연패 보상 2:100 / 3:150 / 4:200 / 5+:300(+무료 리롤). 캐논: 공격 7, 간격 2.4초, 반경 16, 광역 가장자리 40%(BattleRules.SPLASH_EDGE_DAMAGE) — 1:1 측정상 소드·힐러에 강하고 보우·실드에 약함.
- 보스 굴림 기믹: BossRules.roll_modifiers(9R 슬롯1 정지, 12R 곱연산 과세) → RoundFlow.roll_modifiers → DiceRollResolver. 15R 재굴림 -1. GameSession.apply_round_rules가 라운드마다 적용.
- 인첸트 24종(기존 9 + tools/generate_enchants_v2.gd 15). 새 인첸트는 ShopCatalog.ENCHANT_PATHS에 등록해야 상점에 나온다.
- 테스트 추가: test_boss(7), test_enchants_v2(24).
- 중첩 특수능력: UnitData.branch_thresholds(기본 50/150, 킹 3/5) + branch_1/2(UnitBranch .tres, data/unit_branches). 칸 누적 인원(packet.total_count)으로 판정, 2분기는 1분기에 누적. 전투 능력치는 BattleUnit 필드를 쓴다(u.data.* 직접 사용 금지).
- 킹: is_unique(판에 한 칸, 1명 소환, 칸 인원 = 누적 K 수). 장판 곱배수 공격 ×1.3 / 받는 피해 ×0.8, 킹 피해는 장판 안 아군과 균등 분담(share_targets, 자기 참조 금지). 포커카드(PokerTrait, 2면 전용) A → 거인, K → 킹 (GameSession summons["unlocks"]).
- 주사위 성질: DiceTraitData(.tres, data/traits, tools/generate_traits.gd) + DiceInstance.trait_data. 새 성질은 ShopCatalog.TRAIT_PATHS에 등록. 가격 GameBalance.TRAIT_PRICE_BY_RANK(C150/B250/A400/S600).
- 전투 화면: 유닛은 UnitFigure(스틱맨) — 아트 교체 시 이 파일만 바꾼다. 데미지 숫자는 동시 70개 제한 + 같은 대상 0.12초 안 합산.
- 테스트 추가: test_king_poker(45).
- 칸 보정: StatModifier(.tres 하위 리소스 또는 코드 static 캐시) — 포커 수트·로열, 뼈주사위는 CellState.modifiers(칸이 비면 사라짐), 타로 유닛칸 버프는 BoardState.slot_modifiers(칸 자리 영구). 같은 리소스는 한 칸에 한 번만.
- 성질 훅 순서: prepare_context → modify_base_faces → 추첨 → override_raw → on_rolled → 아이템 → 인첸트 → on_post_pipeline → 아이템 최종 → (기록) on_confirm → (정산 후) on_round_end. 해석기 3-Pass: 일반 → 자석 → 거울. 파괴는 GameSession.destroy_dice(인첸트 자동 회수·5주사위 보충)로만.
- 과부하 주사위: 중첩칸에 놓으면 CellState.temp_count(이번 라운드 한정, 승리 시 판매).
- 유저 아이템: UserItemData 훅 + ItemInstance.state, GameSession.inventory(최대 6). 타로: TarotCardData(RESERVE 예약 2장 / WALL 설치 / CELL 칸 지정), 전투 효과는 시뮬레이션 경과 시간으로만(BattleSimulation.add_battle_tarot). 1인용 상점 풀은 PVP_ONLY·상대 간섭 제외.
- GDScript에서 get_stack은 내장 함수라 메서드 이름으로 쓰면 파싱 오류. perl 치환으로 "\n"을 넣으면 실제 줄바꿈이 들어가 문자열이 깨진다 — 문자열 속 \n은 Edit 도구로 넣는다.
- 주사위 아이콘은 ItemIcon.setup_dice(주사위, 눈금글자): 2면 = 동전, 포커카드 = 트럼프 카드(수트는 도형으로 그림). 대상 주사위 선택은 DicePickOverlay(검은 40% + 변환 연출).
- 테스트 추가: test_content_v2(64).
- 팀별 정예 압축: BattleSimulation.team_compression[team] (유압 압축기). 공용 BattleRules.compression_threshold는 바꾸지 않는다 (적에게도 적용되므로).
- 무단 침입 통행증: GameSession.trespass_swap → DeckManager.force_swap + RoundFlow.reroll_single(재굴림 횟수 소모 없음). 더 러버 연결은 BoardState.slot_links(중앙 관리) → BattleSimulation.team_links.
- 상대 간섭 타로 4종은 PvpTarotRules(두 GameSession 사이 순수 로직) — 친선전 연결 시 호출. 1인용 풀에서는 제외.
- 단계 선택은 ChoicePopup(사포와펜: 지울 숫자 → 새길 숫자, 수정 테이프: 지울 칸). UserItemData.get_choices / get_dice_choices.
- 스크린샷 스크립트는 `timeout 90`으로 감싸고 로그를 파일로 받는다 (스크립트 오류 시 멈춰서 끝나지 않음).
- 테스트 추가: test_content_v3(41).
- 소비칸 보험 증서 → 패배 보험 증서(패배 시 이번 라운드 새 소환 인원의 40% 환급)로 변경. 데이터 문구를 바꿀 땐 .tres를 지우고 생성 도구를 다시 돌린다.
