extends Node
## 스킬 보관소 (autoload: SkillDB) — QWER 4슬롯을 들고 있고 디스크에 저장한다.
##
## 스킬 1개(Dictionary) 스키마 — 이게 에디터와 전투 코드 사이의 계약이다.
##   name      : String              스킬 이름
##   mask      : PackedByteArray     32×32, 0=빈칸 1=칠함 (그림)
##   color     : Color               투사체/이펙트 색
##   damage    : float               1~100
##   range_pt  : float               1~100 (기획서의 "범위")
##   tag       : String              Balance.tag_from_mask() 결과 캐시
##
## 실제 전투 수치(쿨타임·발동시간·속도·히트박스)는 저장하지 않는다.
## 필요할 때 Balance.derive(damage, range_pt, tag) 로 매번 계산한다.
## → 기획 담당이 공식을 고치면 저장된 스킬에도 즉시 반영된다.

signal slot_changed(slot: String)

const SLOTS: PackedStringArray = ["Q", "W", "E", "R"]
const SAVE_PATH := "user://skills.json"

var _slots: Dictionary = {}


func _ready() -> void:
	if not load_from_disk():
		reset_to_defaults()


# ─────────────────────────────────────────────────────────────
# 슬롯 읽기/쓰기
# ─────────────────────────────────────────────────────────────

func get_slot(slot: String) -> Dictionary:
	return _slots.get(slot, {})


func set_slot(slot: String, skill: Dictionary) -> void:
	if not SLOTS.has(slot):
		push_warning("SkillDB: 없는 슬롯 %s" % slot)
		return
	_slots[slot] = skill
	slot_changed.emit(slot)
	save_to_disk()


## 스킬 하나를 규격대로 만든다. tag 는 그림에서 자동 판정한다.
func make_skill(name: String, mask: PackedByteArray, color: Color,
		damage: float, range_pt: float) -> Dictionary:
	return {
		"name": name,
		"mask": mask,
		"color": color,
		"damage": clampf(damage, 1.0, 100.0),
		"range_pt": clampf(range_pt, 1.0, 100.0),
		"tag": Balance.tag_from_mask(mask),
	}


## 이 슬롯의 전투 수치. 슬롯이 비었으면 빈 Dictionary.
func derived(slot: String) -> Dictionary:
	var s := get_slot(slot)
	if s.is_empty():
		return {}
	return Balance.derive(s["damage"], s["range_pt"], s["tag"])


# ─────────────────────────────────────────────────────────────
# 기본 스킬 4개 — 처음 켰을 때 바로 쏴볼 수 있게
# ─────────────────────────────────────────────────────────────

func reset_to_defaults() -> void:
	_slots = {
		"Q": make_skill("불꽃탄", _stamp_circle(6), Color(1.0, 0.45, 0.15), 22.0, 18.0),
		"W": make_skill("관통창", _stamp_bar(3, 22), Color(0.35, 0.8, 1.0), 45.0, 30.0),
		"E": make_skill("산탄", _stamp_dots(3), Color(0.7, 1.0, 0.4), 30.0, 22.0),
		"R": make_skill("대폭발", _stamp_circle(13), Color(1.0, 0.25, 0.55), 70.0, 48.0),
	}
	for s in SLOTS:
		slot_changed.emit(s)
	save_to_disk()


func _blank() -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(Balance.GRID * Balance.GRID)
	return m


func _stamp_circle(radius: int) -> PackedByteArray:
	var m := _blank()
	var c := Balance.GRID / 2
	for y in Balance.GRID:
		for x in Balance.GRID:
			if Vector2(x - c, y - c).length() <= float(radius):
				m[y * Balance.GRID + x] = 1
	return m


func _stamp_bar(half_w: int, half_h: int) -> PackedByteArray:
	var m := _blank()
	var c := Balance.GRID / 2
	for y in range(c - half_h, c + half_h):
		for x in range(c - half_w, c + half_w):
			if x >= 0 and y >= 0 and x < Balance.GRID and y < Balance.GRID:
				m[y * Balance.GRID + x] = 1
	return m


func _stamp_dots(radius: int) -> PackedByteArray:
	var m := _blank()
	for center in [Vector2i(9, 10), Vector2i(22, 12), Vector2i(15, 23)]:
		for y in Balance.GRID:
			for x in Balance.GRID:
				if Vector2(x - center.x, y - center.y).length() <= float(radius):
					m[y * Balance.GRID + x] = 1
	return m


# ─────────────────────────────────────────────────────────────
# 저장 / 불러오기 (user://skills.json)
# ─────────────────────────────────────────────────────────────

func save_to_disk() -> void:
	var out := {}
	for slot in SLOTS:
		var s: Dictionary = _slots.get(slot, {})
		if s.is_empty():
			continue
		out[slot] = {
			"name": s["name"],
			"mask": Array(s["mask"] as PackedByteArray),
			"color": (s["color"] as Color).to_html(false),
			"damage": s["damage"],
			"range_pt": s["range_pt"],
			"tag": s["tag"],
		}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SkillDB: 저장 실패 %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(out))
	f.close()


func load_from_disk() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	_slots.clear()
	for slot in SLOTS:
		if not (parsed as Dictionary).has(slot):
			continue
		var raw: Dictionary = parsed[slot]
		var mask := PackedByteArray()
		mask.resize(Balance.GRID * Balance.GRID)
		var arr: Array = raw.get("mask", [])
		for i in mini(arr.size(), mask.size()):
			mask[i] = 1 if int(arr[i]) != 0 else 0
		_slots[slot] = {
			"name": String(raw.get("name", "이름없음")),
			"mask": mask,
			"color": Color.from_string(String(raw.get("color", "ffffff")), Color.WHITE),
			"damage": float(raw.get("damage", 20.0)),
			"range_pt": float(raw.get("range_pt", 20.0)),
			"tag": String(raw.get("tag", Balance.TAG_ROUND)),
		}
	if _slots.is_empty():
		return false
	for s in SLOTS:
		slot_changed.emit(s)
	return true
