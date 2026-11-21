extends Node
## 전투 화면 확인용 데모 (Step 3b). 씬: 루트 Node + 이 스크립트, F6으로 실행.
## 샘플 아군 배치판 vs 지정 라운드 적군으로 전투 연출을 보여 준다. 결과는 출력 패널에도 표시.

@export var round_number: int = 9
## 0이면 무작위
@export var fixed_seed: int = 0
## 아군 규모 배율 (1이면 기본 샘플)
@export var army_scale: int = 1


func _ready() -> void:
	var view: Node2D = (load("res://ui/battle_view.gd") as GDScript).new()
	add_child(view)
	var seed_value: int = fixed_seed if fixed_seed != 0 else randi()
	var sim: BattleSimulation = BattleSimulation.new()
	sim.setup([_sample_player_board().get_spawn_packets(), EnemyTable.build_board(round_number).get_spawn_packets()], seed_value)
	view.battle_finished.connect(func(r: BattleResult) -> void:
		print("[전투 데모] %dR 시드 %d → 승자 팀 %d (%s), 생존 %s" % [round_number, seed_value, r.winner, r.reason, str(r.survivor_totals)]))
	view.call("start_battle", sim, 0)


## 샘플 아군: 중첩칸(가운데 줄)은 정예 압축 단계별로, 소비칸은 소규모
func _sample_player_board() -> BoardState:
	var b: BoardState = BoardState.new()
	var s: int = maxi(1, army_scale)
	b.place(BoardState.index_of(2, 1), &"shield", 120 * s)   # 전열 중첩: 배수 2.4 → 은색
	b.place(BoardState.index_of(1, 1), &"sword", 300 * s)    # 중열 중첩: 배수 6 → 금색
	b.place(BoardState.index_of(0, 1), &"cannon", 800 * s)   # 후열 중첩: 배수 16 → 붉은색
	b.place(BoardState.index_of(2, 0), &"shield", 60 * s)    # 전열 실드
	b.place(BoardState.index_of(1, 2), &"sword", 30 * s)     # 소비칸 소드
	b.place(BoardState.index_of(0, 0), &"bow", 45 * s)       # 소비칸 보우
	b.place(BoardState.index_of(0, 2), &"healer", 25 * s)    # 소비칸 힐러
	return b
