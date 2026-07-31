extends Node
## 밸런스 엔진 (autoload: Balance) — 순수 계산만 한다. 씬/노드를 건드리지 않는다.
##
## 담당: 기획/밸런스(game-designer). 이 파일의 **숫자**는 기획 담당이 조정한다.
## 함수 이름과 반환 키(=인터페이스)는 개발/에디터가 의존하므로 함부로 바꾸지 않는다.
##
## 대원칙 (docs/게임기획.md):
##   그림은 모양을 바꾸고, 수치는 세기를 바꾼다.
##   어떤 그림을 그려도 총 유효 판정 면적은 `범위` 값으로 정규화된다.

## 그림판 격자 크기
const GRID: int = 32

## 스킬 하나에 쓸 수 있는 총 예산
const BUDGET: float = 100.0
## 범위 1pt 당 예산 소모 계수
const RANGE_COEF: float = 0.6

## ── 예산 초과 처리 (2026-07-31, 기획 담당 결정) ────────────────────────
## 예산을 넘겨도 **만들 수는 있다.** 대신 초과분 1%마다 쿨타임·발동시간이 더 늘어난다.
## 저장이나 발사를 막지 않는 이유:
##   · 기획서 8행이 데미지 1~100 을 명시했는데, 막으면 데미지 100 이 사실상 존재할 수 없다
##     (데미지 100 + 최소 범위 1 = 100.6pt 라 무조건 초과다)
##   · 기획서 9행 형평성 원칙이 "셀수록 쿨 길게" 이므로, 초과분에 쿨을 더 붙이는 것은
##     새 규칙을 만드는 게 아니라 기존 원칙을 끝까지 적용하는 것이다
##   · 거부당하는 것보다 대가를 치르는 쪽이 만드는 재미가 산다
## 계수 3.0 의 근거 — 데미지×범위 1~100 전 조합(10,000개)을 훑어
## "유효 지속딜 = (데미지÷쿨) × 판정 반경" 을 비교했다:
##   페널티 0(현행) → 초과 최강 21.72 vs 합법 최강 11.24  ← 초과가 2배 이득. 형평성 붕괴
##   페널티 1.0     → 13.57 vs 11.24  ← 아직 이득
##   페널티 2.0     → 11.09 vs 11.24  ← 여기서 뒤집힌다
##   페널티 3.0     → 11.07 vs 11.24  ← 채택(여유 마진)
## 즉 3.0 이면 **예산을 넘겨서 이득 보는 조합이 하나도 없다.**
const OVER_COOLDOWN_PENALTY: float = 3.0
const OVER_CAST_PENALTY: float = 1.5

## 형태 태그
const TAG_LONG := "길쭉함"
const TAG_ROUND := "둥긂"
const TAG_SHARP := "뾰족함"
const TAG_SCATTER := "흩어짐"

## 태그 판정 임계값 — 기획 담당 조정 지점
const T_ASPECT_LONG: float = 2.5      ## 종횡비 이 이상이면 길쭉함
const T_COMPLEXITY_SHARP: float = 2.5 ## 둘레²/(4π·면적). 1.0=완전한 원
## 뾰족함은 복잡도만으로 판정하지 않는다. 채움률이 이보다 낮아야 한다.
## 이유: 복잡도는 둘레를 제곱해서 손떨림에 2차로 반응한다. 손으로 그린 원은
## 테두리가 한 칸만 울퉁불퉁해도 복잡도가 1.9 → 5.2 로 뛴다(검산 완료).
## 그러면 "원을 그렸는데 부채꼴이 나가는" 일이 벌어진다 — 예측 불가능해 재미가 죽는다.
## 채움률은 같은 손떨림에서 0.67 → 0.61 밖에 안 움직여 훨씬 안정적이다.
## 별·번개·십자는 채움률이 0.24~0.48 이라 이 문턱으로 원과 깨끗하게 갈린다.
const T_FILL_SHARP: float = 0.50      ## 채움률이 이 미만이어야 뾰족함
const T_MIN_BLOB_PIXELS: int = 4      ## 이보다 작은 덩어리는 노이즈로 무시

## 쿨타임 범위(초) — 예산을 다 쓰면 MAX, 아끼면 MIN
const COOLDOWN_MIN: float = 0.6
const COOLDOWN_MAX: float = 9.0
## 쿨타임 곡선의 지수. 1.0 이면 예산에 정비례(=선형).
## 선형이면 "데미지가 클수록 지속 딜(데미지÷쿨)이 계속 좋아진다" — 약한 스킬이 손해다.
## 지수를 1보다 크게 두면 비싼 스킬의 쿨이 더 가파르게 늘어 지속 딜이 평평해진다.
## 검산(범위 20 고정, 데미지 10~88 의 지속 딜 최대/최소 비):
##   지수 1.0 → 2.39배 · 1.3 → 1.75배 · **1.6 → 1.52배** · 2.0 → 1.43배
## 2.0 은 중간 데미지가 오히려 최강이 되는 역전이 생겨 1.6 을 쓴다.
const COOLDOWN_CURVE: float = 1.6

## 발동(캐스팅) 시간 범위(초) — 범위가 클수록 느려서 피하기 쉽다
const CAST_MIN: float = 0.12
const CAST_MAX: float = 1.10

## 투사체 속도 범위(m/s) — 범위가 작을수록 빠르다
const SPEED_MIN: float = 12.0
const SPEED_MAX: float = 28.0

## 총 유효 판정 면적 범위(m²) — 모든 태그가 이 면적을 나눠 갖는다
const AREA_MIN: float = 0.8
const AREA_MAX: float = 12.0

## 사거리 범위(m)
const DISTANCE_MIN: float = 8.0
const DISTANCE_MAX: float = 34.0

## 산탄(흩어짐)이 퍼지는 각도(도). 좁을수록 모여 나간다.
const SCATTER_SPREAD_DEG: float = 14.0

## 부채꼴(뾰족함)이 **조준상 퍼지는** 각도(도).
## 히트박스의 `angle_deg`(부채꼴 판정 각, 90°)와 **반드시 분리해야 한다.**
## 판정 각을 그대로 퍼짐각으로 쓰면 10m 앞에서 바깥 탄이 중심에서 10m 옆으로 날아가
## 사실상 데미지 1/3 태그가 된다(QA 실측: 기대 데미지 둥긂 1.00 대 뾰족함 0.19).
## 값은 기획 담당 조정 지점.
const CONE_SPREAD_DEG: float = 11.0

## 부채꼴(뾰족함)을 실제로 쏠 때 나누는 탄 수.
## damage_per_hit 의 뾰족함 ÷3 과 맞물린다. 둘을 따로 바꾸면 총 데미지가 어긋난다.
const CONE_PELLETS: int = 3

## 길쭉함(캡슐)의 날씬함. 길이 = 이 값 × √면적, 폭 = 면적 ÷ 길이.
## → 길이÷폭 = 이 값의 제곱. 3.0 이면 9:1 창 모양이다.
##
## 예전엔 폭을 0.45m 로 고정하고 길이 = 면적÷0.45 로 뽑았는데, 면적이 범위에 비례해
## 15배까지 커지므로 길이도 15배로 늘었다: 범위 100 에서 **길이 26.7m 짜리 캡슐이
## 사거리 34m 를 날아갔다.** 기획서 24행이 "얇은 선 하나로 맵 관통"을 원천 차단한다고
## 못박았는데 실제로는 열려 있었다. √면적에 비례시키면 길이·폭이 함께 자라서
## 어느 범위에서든 같은 창 모양이 유지된다(범위 100 기준 길이 10.4m / 폭 1.15m).
const LONG_LEN_RATIO: float = 3.0
## 캡슐 폭의 하한(m). 이보다 얇아지면 길이를 줄여 면적을 지킨다.
const LONG_WIDTH_MIN: float = 0.22


# ─────────────────────────────────────────────────────────────
# 그림 미세 파라미터용 상수 — **아직 아무도 안 쓴다.**
# 기획서 47~48행 「태그별 미세 파라미터를 그림에서 더 뽑는」 확장을 위해
# 기획 담당이 값만 미리 확정해 둔 것이다. 개발이 배선할 때 이 값을 쓴다.
# 배선 방법은 reports/game-designer.md 「개발 요청」 절에 적어 뒀다.
#
# 전부 **면적 보존**이다. 어떤 값이 나와도 판정 면적 합 = total_area 이고
# 총 데미지 합 = damage 다. 그림은 배분만 바꾸지 세기를 못 바꾼다(기획서 20~24행).
# ─────────────────────────────────────────────────────────────

## 길쭉함: 종횡비(또는 회전 불변 신장도)가 T_ASPECT_LONG → 이 값으로 갈수록
## LONG_LEN_RATIO 가 MIN → MAX 로 움직인다. 이보다 길쭉해도 더는 안 변한다.
const T_ASPECT_LONG_FULL: float = 8.0
const LONG_LEN_RATIO_MIN: float = 2.0   ## 뭉툭한 창 (길이:폭 = 4:1)
const LONG_LEN_RATIO_MAX: float = 4.6   ## 바늘 (길이:폭 = 21:1)

## 뾰족함: 복잡도가 T_COMPLEXITY_SHARP → 이 값으로 갈수록 각도가 넓어지고 탄이 늘어난다.
## 각도가 좁으면 면적식에 따라 부채꼴 반지름이 길어진다(= 멀리 뻗는 근접기).
const T_COMPLEXITY_SHARP_FULL: float = 12.0
const CONE_ANGLE_MIN: float = 55.0
const CONE_ANGLE_MAX: float = 130.0
const CONE_PELLETS_MIN: int = 2
const CONE_PELLETS_MAX: int = 5

## 흩어짐: 그림의 덩어리 수가 그대로 탄 수가 된다(이 범위로 자름).
const SCATTER_PELLETS_MIN: int = 2
const SCATTER_PELLETS_MAX: int = 6
## 퍼짐각은 탄 수에 따라 √(N ÷ 이 값) 배로 조절한다.
## 이유: 총 면적을 N 발로 쪼개면 탄 하나의 반지름은 √(A/Nπ) 이고,
## 탄들의 각지름 합은 N·√(A/Nπ) = √(NA/π) — 즉 **탄이 많을수록 총 커버가 넓다.**
## 퍼짐각을 √N 에 비례시켜야 "퍼짐각 안에서 맞을 확률"이 N 과 무관해진다.
## 이걸 안 하면 덩어리를 많이 그릴수록 무조건 이득이라 형평성이 깨진다.
const SCATTER_SPREAD_REF_PELLETS: float = 5.0

## 둥긂: 채움률이 이 값 미만(= 속이 빈 그림)이면 관통형이 된다.
## 관통은 공짜가 아니다 — 총 데미지를 관통 수로 나눈다. 한 명만 맞히면 손해,
## 일직선에 두 명이 겹쳤을 때만 본전이다(제로섬).
const T_FILL_PIERCE: float = 0.35
const PIERCE_MAX: int = 2


# ─────────────────────────────────────────────────────────────
# 1. 그림(마스크) → 지표 4개
# ─────────────────────────────────────────────────────────────

## mask: GRID*GRID 길이, 0=빈칸 / 1=칠함.
## 반환: {filled, fill_ratio, aspect, complexity, blobs}
func analyze_mask(mask: PackedByteArray) -> Dictionary:
	var out := {
		"filled": 0,
		"fill_ratio": 0.0,
		"aspect": 1.0,
		"complexity": 1.0,
		"blobs": 0,
	}
	if mask.size() < GRID * GRID:
		return out

	var min_x := GRID
	var min_y := GRID
	var max_x := -1
	var max_y := -1
	var filled := 0
	for y in GRID:
		for x in GRID:
			if mask[y * GRID + x] == 0:
				continue
			filled += 1
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if filled == 0:
		return out

	var bw := float(max_x - min_x + 1)
	var bh := float(max_y - min_y + 1)
	out["filled"] = filled
	out["fill_ratio"] = float(filled) / (bw * bh)
	out["aspect"] = bw / bh
	out["complexity"] = _complexity(mask, filled)
	out["blobs"] = _count_blobs(mask)
	return out


## 둘레²/(4π·면적). 완전한 원이면 1.0, 뾰족·가늘수록 커진다.
func _complexity(mask: PackedByteArray, filled: int) -> float:
	var perimeter := 0
	for y in GRID:
		for x in GRID:
			if mask[y * GRID + x] == 0:
				continue
			# 4방향 중 비어 있거나 격자 밖인 면이 곧 둘레
			if x == 0 or mask[y * GRID + x - 1] == 0:
				perimeter += 1
			if x == GRID - 1 or mask[y * GRID + x + 1] == 0:
				perimeter += 1
			if y == 0 or mask[(y - 1) * GRID + x] == 0:
				perimeter += 1
			if y == GRID - 1 or mask[(y + 1) * GRID + x] == 0:
				perimeter += 1
	if filled <= 0:
		return 1.0
	return float(perimeter * perimeter) / (4.0 * PI * float(filled))


## 연결 판정에 쓰는 4방향. 타입을 붙여야 아래 for 문에서 d 가 Vector2i 로 추론된다.
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


## 4방향 연결 요소 개수. 아주 작은 점은 노이즈로 세지 않는다.
func _count_blobs(mask: PackedByteArray) -> int:
	var seen := PackedByteArray()
	seen.resize(GRID * GRID)
	var blobs := 0
	for start in GRID * GRID:
		if mask[start] == 0 or seen[start] == 1:
			continue
		var size := 0
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			size += 1
			var x := i % GRID
			@warning_ignore("integer_division")
			var y := i / GRID
			for d in NEIGHBORS:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= GRID or ny >= GRID:
					continue
				var ni := ny * GRID + nx
				if mask[ni] == 1 and seen[ni] == 0:
					seen[ni] = 1
					stack.append(ni)
		if size >= T_MIN_BLOB_PIXELS:
			blobs += 1
	return blobs


# ─────────────────────────────────────────────────────────────
# 2. 지표 → 형태 태그 1개
# ─────────────────────────────────────────────────────────────

func tag_from_metrics(m: Dictionary) -> String:
	if int(m.get("filled", 0)) == 0:
		return TAG_ROUND
	if int(m.get("blobs", 0)) >= 2:
		return TAG_SCATTER
	var aspect := float(m.get("aspect", 1.0))
	if aspect >= T_ASPECT_LONG or aspect <= 1.0 / T_ASPECT_LONG:
		return TAG_LONG
	# 뾰족함은 **복잡도 + 채움률 두 조건을 모두** 만족해야 한다.
	# 복잡도 하나로만 보면 손으로 그린 원이 전부 뾰족함으로 넘어간다(T_FILL_SHARP 주석 참고).
	if float(m.get("complexity", 1.0)) >= T_COMPLEXITY_SHARP \
			and float(m.get("fill_ratio", 1.0)) < T_FILL_SHARP:
		return TAG_SHARP
	return TAG_ROUND


## 그림 하나 → 태그 (편의 함수)
func tag_from_mask(mask: PackedByteArray) -> String:
	return tag_from_metrics(analyze_mask(mask))


# ─────────────────────────────────────────────────────────────
# 3. 수치 + 태그 → 실제 전투 파라미터
# ─────────────────────────────────────────────────────────────

## 예산 소모량. damage 1~100, range_pt 1~100.
func cost_of(damage: float, range_pt: float) -> float:
	return damage + range_pt * RANGE_COEF


## 이 데미지에서 예산을 넘기지 않는 최대 범위값
func max_range_for(damage: float) -> float:
	return clampf((BUDGET - damage) / RANGE_COEF, 1.0, 100.0)


## 핵심 함수. 에디터·플레이어 양쪽이 이걸 쓴다.
## 반환 키: cost, over_budget, leftover, cooldown, cast_time, speed,
##          distance, total_area, tag, hitbox{...}
##          over_ratio, over_cooldown_mult, over_cast_mult  ← 2026-07-31 추가
func derive(damage: float, range_pt: float, tag: String) -> Dictionary:
	damage = clampf(damage, 1.0, 100.0)
	range_pt = clampf(range_pt, 1.0, 100.0)

	var cost := cost_of(damage, range_pt)
	var leftover: float = maxf(BUDGET - cost, 0.0)
	var budget_ratio := cost / BUDGET
	var spent_ratio: float = clampf(budget_ratio, 0.0, 1.0)
	# 예산을 넘긴 만큼(0.6 = 60% 초과). 넘기지 않았으면 0.
	var over_ratio: float = maxf(budget_ratio - 1.0, 0.0)
	var over_cooldown_mult: float = 1.0 + over_ratio * OVER_COOLDOWN_PENALTY
	var over_cast_mult: float = 1.0 + over_ratio * OVER_CAST_PENALTY
	var range_ratio := range_pt / 100.0

	# 예산을 많이 쓸수록 쿨타임이 길다. 곡선이라 비쌀수록 더 가파르게 는다.
	# 예산을 넘겼으면 그 위에 초과 페널티가 곱해진다 — 상한 없이 계속 길어진다.
	var cooldown: float = lerpf(COOLDOWN_MIN, COOLDOWN_MAX, pow(spent_ratio, COOLDOWN_CURVE)) \
			* over_cooldown_mult
	# 범위가 클수록 발동이 느려 피하기 쉽다. 데미지도 조금 거든다.
	var cast_time: float = lerpf(CAST_MIN, CAST_MAX,
			range_ratio * 0.75 + (damage / 100.0) * 0.25) * over_cast_mult
	# 범위가 작을수록 빠르게 날아간다
	var speed: float = lerpf(SPEED_MAX, SPEED_MIN, range_ratio)
	var distance: float = lerpf(DISTANCE_MIN, DISTANCE_MAX, range_ratio)
	# 총 유효 판정 면적 — 그림이 아니라 오직 범위 값이 정한다
	var total_area: float = lerpf(AREA_MIN, AREA_MAX, range_ratio)

	return {
		"cost": cost,
		"over_budget": cost > BUDGET,
		"leftover": leftover,
		"cooldown": cooldown,
		"cast_time": cast_time,
		"speed": speed,
		"distance": distance,
		"total_area": total_area,
		"tag": tag,
		"hitbox": hitbox_for(tag, total_area),
		"over_ratio": over_ratio,
		"over_cooldown_mult": over_cooldown_mult,
		"over_cast_mult": over_cast_mult,
	}


## 태그가 정해진 총 면적을 어떤 모양으로 배분할지 결정한다.
## 어떤 태그든 (판정 면적 합)이 total_area 와 같아지도록 맞춘다.
## 반환 키: kind, radius, length, width, angle_deg, pellets, pellet_radius
func hitbox_for(tag: String, total_area: float) -> Dictionary:
	var box := {
		"kind": "sphere",
		"radius": 0.5,
		"length": 0.0,
		"width": 0.0,
		"angle_deg": 0.0,
		"pellets": 1,
		"pellet_radius": 0.5,
	}
	match tag:
		TAG_LONG:
			# 캡슐: 길이·폭이 √면적에 함께 비례한다 → 어느 범위에서도 같은 창 모양.
			# 폭이 하한에 걸리면 길이를 줄여서 면적을 지킨다(면적이 먼저다).
			var length: float = LONG_LEN_RATIO * sqrt(maxf(total_area, 0.0001))
			var width: float = total_area / maxf(length, 0.0001)
			if width < LONG_WIDTH_MIN:
				width = LONG_WIDTH_MIN
				length = total_area / width
			box["kind"] = "capsule"
			box["width"] = width
			box["radius"] = width * 0.5
			box["length"] = maxf(length, width)
		TAG_SHARP:
			# 부채꼴 90°. 면적 = (θ/2π)·πr² → r = sqrt(4·area/π)
			var angle := 90.0
			box["kind"] = "cone"
			box["angle_deg"] = angle
			box["radius"] = sqrt(total_area * (360.0 / angle) / PI)
			# 실제로는 이 부채꼴을 작은 탄 CONE_PELLETS 발로 나눠 쏜다.
			# 셋을 합친 판정 면적이 total_area 와 같아지도록 반경을 잡는다.
			box["pellets"] = CONE_PELLETS
			box["pellet_radius"] = sqrt((total_area / float(CONE_PELLETS)) / PI)
		TAG_SCATTER:
			# 작은 원 5개가 총 면적을 나눠 가진다
			var pellets := 5
			box["kind"] = "scatter"
			box["pellets"] = pellets
			box["pellet_radius"] = sqrt((total_area / float(pellets)) / PI)
			box["radius"] = box["pellet_radius"]
		_:
			box["kind"] = "sphere"
			box["radius"] = sqrt(total_area / PI)
	return box


## 한 발이 실제로 넣는 데미지. 다단히트 태그는 나눠 들어간다.
##
## pellets 를 넘기면 그 수로 나눈다(0 = 태그 기본값). 그림에서 탄 수를 뽑는
## 미세 파라미터가 붙으면 **반드시** hitbox["pellets"] 와 같은 값을 넘겨야 한다.
## 안 그러면 총 데미지가 damage 와 어긋나 형평성이 깨진다.
func damage_per_hit(damage: float, tag: String, pellets: int = 0) -> float:
	if pellets > 0:
		return damage / float(pellets)
	match tag:
		TAG_SCATTER:
			return damage / 5.0
		TAG_SHARP:
			return damage / 3.0
		_:
			return damage
