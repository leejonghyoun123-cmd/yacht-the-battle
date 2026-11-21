class_name UnitFigure
extends RefCounted
## 전투 유닛 스틱맨 그리기 (프로토타입 아트. 나중에 스프라이트로 교체할 때 이 파일만 바꾸면 된다).
## 발 위치(p)를 기준으로 위로 그린다. 팀 색 = 몸, 무기 = 병과별 고정 색.
## 반환값: 머리 꼭대기 화면 y (체력바 위치용)

const COLOR_STEEL: Color = Color("d8dde6")
const COLOR_WOOD: Color = Color("8a5a2b")
const COLOR_DARK: Color = Color("2a2a30")
const COLOR_GOLD: Color = Color("ffcc33")
const COLOR_HAT: Color = Color("6a4cc2")
const COLOR_GEM: Color = Color("7ff0ff")


static func draw(ci: CanvasItem, p: Vector2, u: BattleUnit, facing: float, time: float, body: Color) -> float:
	var r: float = u.radius
	var h: float = r * 3.4
	var w: float = maxf(1.2, r * 0.32)
	var outline: Color = Color(0, 0, 0, 0.55)
	# 걷기: 목표에 아직 닿지 않았으면 다리를 흔든다
	var moving: bool = u.target != null and u.target.alive and u.pos.distance_to(u.target.pos) > u.attack_range + u.radius + u.target.radius + 2.0
	var swing: float = sin(time * 11.0 + float(u.id) * 1.7) * (0.45 if moving else 0.0)
	# 공격 직후 0.18초 동안 무기 휘두름 (0~1)
	var strike: float = clampf((u.cooldown - (u.get_attack_interval() - 0.18)) / 0.18, 0.0, 1.0)

	var hip: Vector2 = p + Vector2(0.0, -h * 0.38)
	var neck: Vector2 = p + Vector2(0.0, -h * 0.72)
	var head_r: float = r * 0.5
	var head: Vector2 = neck + Vector2(0.0, -head_r)
	var foot_a: Vector2 = p + Vector2((r * 0.55 + swing * r) * facing, 0.0)
	var foot_b: Vector2 = p + Vector2((-r * 0.55 + swing * r) * facing * -1.0, 0.0)
	var shoulder: Vector2 = neck.lerp(hip, 0.2)
	var hand_front: Vector2 = shoulder + Vector2(r * 0.95 * facing, r * 0.35)
	var hand_back: Vector2 = shoulder + Vector2(-r * 0.7 * facing, r * 0.6)

	# 그림자
	_ellipse(ci, p, r * 0.9, Color(0, 0, 0, 0.25))
	# 몸 (외곽선 → 본선)
	for pass_i: int in range(2):
		var c: Color = outline if pass_i == 0 else body
		var lw: float = w + 1.4 if pass_i == 0 else w
		ci.draw_line(hip, foot_a, c, lw)
		ci.draw_line(hip, foot_b, c, lw)
		ci.draw_line(hip, neck, c, lw)
		ci.draw_line(shoulder, hand_back, c, lw)
		ci.draw_line(shoulder, hand_front, c, lw)
	ci.draw_circle(head, head_r + 0.8, outline)
	ci.draw_circle(head, head_r, body)

	var top: float = head.y - head_r
	match String(u.data.id):
		"sword":
			var ang: float = lerpf(-1.15, 0.35, strike)
			var tip: Vector2 = hand_front + Vector2(cos(ang) * facing, sin(ang)) * r * 1.5
			ci.draw_line(hand_front, tip, COLOR_STEEL, maxf(1.2, w * 0.8))
			var guard: Vector2 = Vector2(-sin(ang) * facing, cos(ang)) * r * 0.3
			ci.draw_line(hand_front - guard, hand_front + guard, COLOR_WOOD, maxf(1.0, w * 0.7))
		"bow":
			var bc: Vector2 = hand_front + Vector2(r * 0.15 * facing, 0.0)
			var start: float = -PI * 0.5 if facing > 0.0 else PI * 0.5
			ci.draw_arc(bc, r * 1.0, start, start + PI * facing, 10, COLOR_WOOD, maxf(1.2, w * 0.8))
			var pull: float = r * 0.45 * (1.0 - strike)
			var top_p: Vector2 = bc + Vector2(0.0, -r)
			var bot_p: Vector2 = bc + Vector2(0.0, r)
			var nock: Vector2 = bc + Vector2(-pull * facing, 0.0)
			ci.draw_line(top_p, nock, Color(1, 1, 1, 0.7), 1.0)
			ci.draw_line(nock, bot_p, Color(1, 1, 1, 0.7), 1.0)
		"shield":
			var sc: Vector2 = hand_front + Vector2(r * 0.35 * facing, -r * 0.2 + (-r * 0.25 * strike))
			var sh: float = r * 1.25
			var sw: float = r * 0.55
			var pts: PackedVector2Array = PackedVector2Array([
				sc + Vector2(-sw, -sh), sc + Vector2(sw, -sh), sc + Vector2(sw, sh * 0.55),
				sc + Vector2(0.0, sh), sc + Vector2(-sw, sh * 0.55),
			])
			ci.draw_colored_polygon(pts, u.data.color)
			pts.append(pts[0])
			ci.draw_polyline(pts, COLOR_DARK, 1.2)
			ci.draw_line(sc + Vector2(0.0, -sh * 0.7), sc + Vector2(0.0, sh * 0.6), COLOR_STEEL, 1.0)
		"cannon":
			# 사람 앞에 바퀴 달린 대포 (발사 순간 뒤로 반동)
			var recoil: float = -r * 0.4 * strike * facing
			var wheel: Vector2 = p + Vector2(r * 1.3 * facing + recoil, -r * 0.55)
			var muzzle: Vector2 = wheel + Vector2(r * 1.6 * facing, -r * 0.9)
			ci.draw_line(wheel, muzzle, COLOR_DARK, r * 0.75)
			ci.draw_circle(muzzle, r * 0.42, Color("111114"))
			ci.draw_circle(wheel, r * 0.55, COLOR_WOOD)
			ci.draw_arc(wheel, r * 0.55, 0.0, TAU, 12, COLOR_DARK, 1.0)
			if strike > 0.5:
				ci.draw_circle(muzzle + Vector2(r * 0.5 * facing, -r * 0.25), r * 0.5 * strike, Color(1.0, 0.75, 0.3, 0.8))
		"healer":
			var tip: Vector2 = hand_front + Vector2(r * 0.2 * facing, -r * 1.4)
			ci.draw_line(hand_front + Vector2(0.0, r * 0.3), tip, COLOR_WOOD, maxf(1.0, w * 0.7))
			ci.draw_circle(tip, r * 0.3 + r * 0.15 * strike, COLOR_GEM)
			# 마법 모자: 머리 위 뾰족 삼각형 + 챙
			var brim_y: float = head.y - head_r * 0.45
			var hat: PackedVector2Array = PackedVector2Array([
				Vector2(head.x - head_r * 1.35, brim_y), Vector2(head.x + head_r * 1.35, brim_y),
				Vector2(head.x - head_r * 0.6 * facing, brim_y - head_r * 2.6),
			])
			ci.draw_colored_polygon(hat, COLOR_HAT)
			ci.draw_polyline(PackedVector2Array([hat[0], hat[1], hat[2], hat[0]]), COLOR_DARK, 1.0)
			top = brim_y - head_r * 2.6
		"giant":
			var ang: float = lerpf(-1.4, 0.5, strike)
			var club_end: Vector2 = hand_front + Vector2(cos(ang) * facing, sin(ang)) * r * 1.7
			ci.draw_line(hand_front, club_end, COLOR_WOOD, r * 0.32)
			ci.draw_circle(club_end, r * 0.3, COLOR_WOOD)
		"king":
			var cb: float = head.y - head_r * 0.7
			var cw: float = head_r * 1.1
			var crown: PackedVector2Array = PackedVector2Array([
				Vector2(head.x - cw, cb), Vector2(head.x - cw, cb - head_r * 1.1),
				Vector2(head.x - cw * 0.5, cb - head_r * 0.5), Vector2(head.x, cb - head_r * 1.3),
				Vector2(head.x + cw * 0.5, cb - head_r * 0.5), Vector2(head.x + cw, cb - head_r * 1.1),
				Vector2(head.x + cw, cb),
			])
			ci.draw_colored_polygon(crown, COLOR_GOLD)
			crown.append(crown[0])
			ci.draw_polyline(crown, Color("8a6a10"), 1.0)
			top = cb - head_r * 1.3
			# 홀: 손에 금 막대
			ci.draw_line(hand_front, hand_front + Vector2(r * 0.2 * facing, -r * 1.2), COLOR_GOLD, maxf(1.2, w * 0.8))
	return top


static func _ellipse(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(12):
		var a: float = TAU * float(i) / 12.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.45))
	ci.draw_colored_polygon(pts, color)
