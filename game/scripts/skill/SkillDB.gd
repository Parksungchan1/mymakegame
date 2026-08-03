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
## 보관함이 바뀌었을 때(추가·삭제·이름변경)
signal book_changed

const SLOTS: PackedStringArray = ["Q", "W", "E", "R"]
const SAVE_PATH := "user://skills.json"

# ── 도안첩(보관함) ────────────────────────────────────────────
## 2026-08-03 사용자 승인으로 신설.
##
## 그 전까지 그린 스킬은 **QWER 4칸 밖으로 나갈 데가 없었다.**
## 다섯 번째를 그리면 넷 중 하나가 말없이 사라졌다 —
## 「만드는 즐거움의 앞쪽 절반(그리기)만 있고 뒤쪽 절반(남기기)이 없다」(내러티브 진단).
##
## 보관함은 **성능에 관여하지 않는다.** 몇 장을 모으든 전투는 안 바뀐다.
## QWER 에 무엇을 끼우느냐만 바뀐다.
const BOOK_LIMIT := 40

var _slots: Dictionary = {}
## 보관해 둔 도안들. 항목은 슬롯과 같은 스키마 + `id`(고유 번호) + `stats`(전적).
var _book: Array = []
var _next_id: int = 1


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


# ─────────────────────────────────────────────────────────────
# 도안첩
# ─────────────────────────────────────────────────────────────

func book() -> Array:
	return _book


## 도안 하나를 보관함에 넣는다. 이미 있는 id 면 덮어쓴다.
## 반환: 저장된 도안의 id. 가득 찼으면 -1.
func book_save(skill: Dictionary, id: int = 0) -> int:
	if id > 0:
		for i in _book.size():
			if int(_book[i].get("id", 0)) == id:
				var kept: Dictionary = skill.duplicate(true)
				kept["id"] = id
				kept["stats"] = _book[i].get("stats", _new_stats())
				_book[i] = kept
				save_to_disk()
				book_changed.emit()
				return id

	if _book.size() >= BOOK_LIMIT:
		push_warning("SkillDB: 도안첩이 가득 찼다(%d장). 지우고 다시 넣어라." % BOOK_LIMIT)
		return -1

	var entry: Dictionary = skill.duplicate(true)
	entry["id"] = _next_id
	entry["stats"] = _new_stats()
	_next_id += 1
	_book.append(entry)
	save_to_disk()
	book_changed.emit()
	return int(entry["id"])


func book_delete(id: int) -> void:
	for i in _book.size():
		if int(_book[i].get("id", 0)) == id:
			_book.remove_at(i)
			save_to_disk()
			book_changed.emit()
			return


func book_get(id: int) -> Dictionary:
	for e in _book:
		if int(e.get("id", 0)) == id:
			return e
	return {}


## 보관함의 도안을 QWER 슬롯에 끼운다.
func book_equip(id: int, slot: String) -> void:
	var e := book_get(id)
	if e.is_empty():
		return
	set_slot(slot, e)


## 전적 — 「이 도안이 몇 번 맞혔는지」. 이게 「잘 그릴 이유」의 피드백이다.
func _new_stats() -> Dictionary:
	return {"fired": 0, "hits": 0, "damage": 0.0, "kills": 0}


## 전투가 그때그때 불러 전적을 쌓는다. 보관함에 없는 도안이면 조용히 넘어간다.
func record(id: int, fired: int = 0, hits: int = 0, damage: float = 0.0, kills: int = 0) -> void:
	if id <= 0:
		return
	for e in _book:
		if int(e.get("id", 0)) != id:
			continue
		var s: Dictionary = e.get("stats", _new_stats())
		s["fired"] = int(s.get("fired", 0)) + fired
		s["hits"] = int(s.get("hits", 0)) + hits
		s["damage"] = float(s.get("damage", 0.0)) + damage
		s["kills"] = int(s.get("kills", 0)) + kills
		e["stats"] = s
		return


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

## 도안 하나를 저장용 Dictionary 로. 슬롯과 보관함이 같은 모양을 쓴다.
func _to_json(s: Dictionary) -> Dictionary:
	var out := {
		"name": s["name"],
		"mask": Array(s["mask"] as PackedByteArray),
		"color": (s["color"] as Color).to_html(false),
		"damage": s["damage"],
		"range_pt": s["range_pt"],
		"tag": s["tag"],
	}
	if s.has("id"):
		out["id"] = s["id"]
	if s.has("stats"):
		out["stats"] = s["stats"]
	return out


func save_to_disk() -> void:
	var out := {}
	for slot in SLOTS:
		var s: Dictionary = _slots.get(slot, {})
		if s.is_empty():
			continue
		out[slot] = _to_json(s)

	# 도안첩. **슬롯과 나란히 저장한다** — 옛 파일에는 이 키가 없고,
	# 없으면 빈 보관함으로 읽히므로 예전에 그려둔 QWER 은 그대로 살아난다.
	var book_out := []
	for e in _book:
		book_out.append(_to_json(e))
	out["_book"] = book_out
	out["_next_id"] = _next_id

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

	var data: Dictionary = parsed

	_slots.clear()
	for slot in SLOTS:
		if not data.has(slot):
			continue
		_slots[slot] = _from_json(data[slot], slot)

	# 도안첩. 옛 파일에는 이 키가 없다 — 그러면 빈 보관함으로 시작한다.
	_book.clear()
	_next_id = int(data.get("_next_id", 1))
	for raw in data.get("_book", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var e := _from_json(raw, "도안첩")
		e["id"] = int((raw as Dictionary).get("id", _next_id))
		e["stats"] = (raw as Dictionary).get("stats", _new_stats())
		_next_id = maxi(_next_id, int(e["id"]) + 1)
		_book.append(e)

	if _slots.is_empty():
		return false
	for s in SLOTS:
		slot_changed.emit(s)
	book_changed.emit()
	return true


## 저장된 Dictionary → 도안. `where` 는 경고 문구에 쓸 자리 이름이다.
func _from_json(raw: Dictionary, where: String) -> Dictionary:
	var mask := PackedByteArray()
	mask.resize(Balance.GRID * Balance.GRID)
	var arr: Array = raw.get("mask", [])
	# 크기가 안 맞으면 그림이 잘리거나 빈칸이 남는다. 조용히 넘기면
	# "저장했는데 모양이 달라졌다" 를 아무도 설명 못 한다. 티를 낸다.
	if arr.size() != mask.size():
		push_warning("SkillDB: %s 의 그림 크기가 %d 다 (기대 %d). 격자 크기가 바뀌었거나 파일이 손상됐다." % [
			where, arr.size(), mask.size()])
	for i in mini(arr.size(), mask.size()):
		mask[i] = 1 if int(arr[i]) != 0 else 0
	return {
		"name": String(raw.get("name", "이름없음")),
		"mask": mask,
		"color": Color.from_string(String(raw.get("color", "ffffff")), Color.WHITE),
		"damage": float(raw.get("damage", 20.0)),
		"range_pt": float(raw.get("range_pt", 20.0)),
		"tag": String(raw.get("tag", Balance.TAG_ROUND)),
	}
