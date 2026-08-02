extends CanvasLayer
## QWER 스킬바 — 화면 아래 가운데. 롤처럼 쿨타임이 눈에 보인다.
##
## 2026-08-01 사용자 요구로 추가:
##   "qwer 의 스킬의 쿨타임이 잘보이도록 스킬이 얼마나 남았고,
##    그걸 볼 수 있도록하는 스킬창이 보여야할듯 -> 예시로 롤 qwer 스킬 쿨 볼 수 있는거처럼"
##
## 지어낸 값을 띄우지 않는다. 모든 숫자는 `Player` 와 `SkillDB` 에서 직접 읽는다.
## 그림도 유저가 그린 마스크를 그대로 쓴다 — 아이콘을 따로 만들지 않는다.
## 그게 이 게임의 정체성이다. 내가 그린 게 손에 들려 있어야 한다.
##
## UI 를 코드로 짓는다. `SkillEditor.gd` 와 같은 이유다 — 칸이 슬롯 수만큼 반복이라
## 손으로 쓴 .tscn 보다 코드가 읽기 쉽고 안 깨진다.

## 칸 크기(픽셀)
const SLOT_SIZE := 74.0
const SLOT_GAP := 10.0
## 화면 아래에서 띄우는 여백
const BOTTOM_MARGIN := 26.0

const READY_BORDER := Color(1.0, 0.85, 0.45, 0.95)
const COOL_BORDER := Color(1, 1, 1, 0.18)
const COOL_VEIL := Color(0.0, 0.0, 0.0, 0.62)
const CAST_COLOR := Color(0.55, 0.85, 1.0, 0.9)

var _player: Node
var _slots: Array = []   # [{root, icon, veil, time, key, name}]
## 대쉬 칸. 그림이 없는 고정 기술이라 아이콘 대신 글자를 쓴다.
var _dash: Dictionary = {}


func _ready() -> void:
	layer = 5
	# 제작창(layer 10)이 위에 오도록 일부러 낮게 둔다.
	_build()
	_find_player()
	SkillDB.slot_changed.connect(_on_slot_changed)


func _find_player() -> void:
	# 씬 구조에 안 묶이도록 그룹이 아니라 이름으로 찾되, 없으면 조용히 넘어간다.
	var root := get_parent()
	if root == null:
		return
	_player = root.get_node_or_null("Player")


func _build() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(SLOT_GAP))
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -BOTTOM_MARGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	for key in SkillDB.SLOTS:
		_slots.append(_build_slot(bar, String(key)))

	# 대쉬 칸 — 사용자가 "그것도 스킬창에 넣고 쿨타임을 적절히 배치" 라고 했다.
	# QWER 과 살짝 띄워 붙인다. 그림 스킬이 아니라 **고정 기술**이라 성격이 다르다.
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(14, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(gap)
	_dash = _build_slot(bar, "Shift")
	(_dash["time"] as Label).add_theme_font_size_override("font_size", 20)

	_refresh_all()


func _build_slot(parent: Node, key: String) -> Dictionary:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.13, 0.88)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = COOL_BORDER
	box.add_theme_stylebox_override("panel", style)
	parent.add_child(box)

	# 겹쳐 쌓는다: 그림 → 쿨 가림막 → 남은 초 → 키 글자
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stack)

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(icon)

	# 쿨타임 가림막 — 위에서 아래로 걷힌다. 남은 비율이 한눈에 보인다.
	var veil := ColorRect.new()
	veil.color = COOL_VEIL
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(veil)

	var time := Label.new()
	time.set_anchors_preset(Control.PRESET_FULL_RECT)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time.add_theme_font_size_override("font_size", 26)
	time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(time)

	var key_label := Label.new()
	key_label.text = key
	key_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	key_label.offset_left = -20.0
	key_label.offset_top = -24.0
	key_label.add_theme_font_size_override("font_size", 17)
	key_label.modulate = Color(1, 1, 1, 0.75)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(key_label)

	# 스킬 이름 — 칸 안쪽 아래에 작게. 예전엔 만들어 놓고 트리에 안 붙여서
	# 이름이 아예 안 보였고 고아 노드만 쌓였다(QA 6차).
	var name_label := Label.new()
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -18.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.modulate = Color(1, 1, 1, 0.72)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(name_label)

	return {
		"key": key, "box": box, "style": style, "icon": icon,
		"veil": veil, "time": time, "name": name_label,
	}


func _on_slot_changed(_slot: String) -> void:
	_refresh_all()


## 그림·색을 다시 읽는다. 제작창에서 저장하면 바로 손에 반영된다.
func _refresh_all() -> void:
	for s in _slots:
		var skill: Dictionary = SkillDB.get_slot(String(s["key"]))
		(s["icon"] as TextureRect).texture = _icon_of(skill)
		(s["name"] as Label).text = String(skill.get("name", ""))
	if not _dash.is_empty():
		(_dash["name"] as Label).text = "대쉬"


## 유저가 그린 마스크를 그대로 아이콘으로 쓴다. 빈 그림이면 없음.
func _icon_of(skill: Dictionary) -> ImageTexture:
	if skill.is_empty():
		return null
	var mask: PackedByteArray = skill["mask"]
	var g := Balance.GRID
	if mask.size() < g * g:
		return null
	var col: Color = skill["color"]
	var img := Image.create(g, g, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var filled := 0
	for y in g:
		for x in g:
			if mask[y * g + x] != 0:
				img.set_pixel(x, y, col)
				filled += 1
	if filled == 0:
		return null
	return ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	if _player == null:
		return
	for s in _slots:
		_update_slot(s)
	if not _dash.is_empty():
		_update_dash()


## 대쉬 칸. 그림이 없으므로 준비됐을 때 「⚡」 를 띄운다.
func _update_dash() -> void:
	var left: float = _player.dash_cooldown_left()
	var total: float = _player.dash_cooldown_total()
	var veil := _dash["veil"] as ColorRect
	var time := _dash["time"] as Label
	var style := _dash["style"] as StyleBoxFlat

	if left <= 0.0:
		veil.visible = false
		time.text = "⚡"
		style.border_color = READY_BORDER
	else:
		veil.visible = true
		veil.anchor_top = 1.0 - clampf(left / maxf(total, 0.001), 0.0, 1.0)
		time.text = ("%.1f" % left) if left < 1.0 else ("%d" % int(ceil(left)))
		style.border_color = COOL_BORDER

	if _player.is_dashing():
		style.border_color = CAST_COLOR


func _update_slot(s: Dictionary) -> void:
	var key := String(s["key"])
	var left: float = _player.cooldown_left(key)
	var total: float = _player.cooldown_total(key)
	var veil := s["veil"] as ColorRect
	var time := s["time"] as Label
	var style := s["style"] as StyleBoxFlat

	if left <= 0.0:
		veil.visible = false
		time.text = ""
		style.border_color = READY_BORDER
	else:
		veil.visible = true
		# 위에서부터 걷힌다 — 남은 비율만큼만 덮는다
		var ratio: float = clampf(left / maxf(total, 0.001), 0.0, 1.0)
		veil.anchor_top = 1.0 - ratio
		# 1초 미만은 소수 한 자리, 그 위는 정수. 롤도 이렇게 한다.
		time.text = ("%.1f" % left) if left < 1.0 else ("%d" % int(ceil(left)))
		style.border_color = COOL_BORDER

	# 발동 중인 슬롯은 테두리로 알린다
	if _player.casting_slot() == key:
		style.border_color = CAST_COLOR
