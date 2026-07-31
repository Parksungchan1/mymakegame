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

## 형태 태그
const TAG_LONG := "길쭉함"
const TAG_ROUND := "둥긂"
const TAG_SHARP := "뾰족함"
const TAG_SCATTER := "흩어짐"

## 태그 판정 임계값 — 기획 담당 조정 지점
const T_ASPECT_LONG: float = 2.5      ## 종횡비 이 이상이면 길쭉함
const T_COMPLEXITY_SHARP: float = 2.2 ## 둘레²/(4π·면적). 1.0=완전한 원
const T_MIN_BLOB_PIXELS: int = 4      ## 이보다 작은 덩어리는 노이즈로 무시

## 쿨타임 범위(초) — 예산을 다 쓰면 MAX, 아끼면 MIN
const COOLDOWN_MIN: float = 1.5
const COOLDOWN_MAX: float = 12.0

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
	if float(m.get("complexity", 1.0)) >= T_COMPLEXITY_SHARP:
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
func derive(damage: float, range_pt: float, tag: String) -> Dictionary:
	damage = clampf(damage, 1.0, 100.0)
	range_pt = clampf(range_pt, 1.0, 100.0)

	var cost := cost_of(damage, range_pt)
	var leftover: float = maxf(BUDGET - cost, 0.0)
	var spent_ratio: float = clampf(cost / BUDGET, 0.0, 1.0)
	var range_ratio := range_pt / 100.0

	# 예산을 많이 쓸수록 쿨타임이 길다
	var cooldown: float = lerpf(COOLDOWN_MIN, COOLDOWN_MAX, spent_ratio)
	# 범위가 클수록 발동이 느려 피하기 쉽다. 데미지도 조금 거든다.
	var cast_time: float = lerpf(CAST_MIN, CAST_MAX, range_ratio * 0.75 + (damage / 100.0) * 0.25)
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
			# 캡슐: 폭은 좁게 고정, 길이는 면적을 채우도록 늘린다
			var width: float = 0.45
			box["kind"] = "capsule"
			box["width"] = width
			box["radius"] = width * 0.5
			box["length"] = maxf(total_area / width, width)
		TAG_SHARP:
			# 부채꼴 90°. 면적 = (θ/2π)·πr² → r = sqrt(4·area/π)
			var angle := 90.0
			box["kind"] = "cone"
			box["angle_deg"] = angle
			box["radius"] = sqrt(total_area * (360.0 / angle) / PI)
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
func damage_per_hit(damage: float, tag: String) -> float:
	match tag:
		TAG_SCATTER:
			return damage / 5.0
		TAG_SHARP:
			return damage / 3.0
		_:
			return damage
