extends CanvasLayer
## 스킬 제작창 — Tab 으로 열고 닫는다. 로드맵 3단계(3a 수치 + 3b 그림판)를 한 화면에 담았다.
##
## UI 를 .tscn 이 아니라 코드로 짓는다. 노드가 많아 손으로 쓴 .tscn 은 깨지기 쉽고,
## 여기서 필요한 배치는 전부 단순한 세로/가로 나열이라 코드가 더 읽기 쉽다.
##
## 이 창은 값을 "보여주고 저장"만 한다. 밸런스 계산은 전부 Balance 에 물어본다.
## 공식을 바꾸려면 Balance.gd 를 고치면 되고 여기는 손댈 필요가 없다.

const PANEL_BG := Color(0.11, 0.10, 0.15, 0.97)
const OK_COLOR := Color(0.62, 0.86, 0.55)
const OVER_COLOR := Color(1.0, 0.44, 0.44)

var _slot: String = "Q"

var _canvas: SkillCanvas
var _dim: ColorRect
var _root: Control
var _name_edit: LineEdit
var _damage: HSlider
var _range: HSlider
var _damage_num: Label
var _range_num: Label
var _color_pick: ColorPickerButton
var _tag_label: Label
var _cost_label: Label
var _stat_label: RichTextLabel
var _slot_buttons: Dictionary = {}


func _ready() -> void:
	layer = 10
	# 창이 열리면 트리를 멈추므로, 이 창만은 멈춰도 계속 돌아야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func is_open() -> bool:
	return visible


# ─────────────────────────────────────────────────────────────
# 열기 / 닫기
# ─────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_skill_editor"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_load_slot(_slot)
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


# ─────────────────────────────────────────────────────────────
# 화면 짓기
# ─────────────────────────────────────────────────────────────

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color(1, 1, 1, 0.12)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	_root = VBoxContainer.new()
	(_root as VBoxContainer).add_theme_constant_override("separation", 14)
	panel.add_child(_root)

	_build_header()
	_build_slot_row()
	_build_body()
	_build_footer()


func _build_header() -> void:
	var title := Label.new()
	title.text = "스킬 제작"
	title.add_theme_font_size_override("font_size", 24)
	_root.add_child(title)

	var hint := Label.new()
	hint.text = "좌클릭 그리기 · 우클릭 지우기 · Tab 닫기"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.55)
	_root.add_child(hint)


func _build_slot_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_root.add_child(row)

	for slot in SkillDB.SLOTS:
		var b := Button.new()
		b.text = slot
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(58, 40)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_on_slot_pressed.bind(slot))
		row.add_child(b)
		_slot_buttons[slot] = b


func _build_body() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	_root.add_child(row)

	# ── 왼쪽: 그림판 ──
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)

	_canvas = SkillCanvas.new()
	_canvas.custom_minimum_size = Vector2(360, 360)
	_canvas.mask_changed.connect(_refresh)
	left.add_child(_canvas)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	left.add_child(tools)

	var clear_btn := Button.new()
	clear_btn.text = "전부 지우기"
	clear_btn.pressed.connect(func() -> void: _canvas.clear_mask())
	tools.add_child(clear_btn)

	_tag_label = Label.new()
	_tag_label.add_theme_font_size_override("font_size", 17)
	tools.add_child(_tag_label)

	# ── 오른쪽: 수치 ──
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.custom_minimum_size = Vector2(330, 0)
	row.add_child(right)

	var name_label := Label.new()
	name_label.text = "이름"
	right.add_child(name_label)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "스킬 이름"
	right.add_child(_name_edit)

	_damage_num = Label.new()
	_damage = _add_slider(right, "데미지", _damage_num)

	_range_num = Label.new()
	_range = _add_slider(right, "범위", _range_num)

	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 10)
	right.add_child(color_row)
	var color_label := Label.new()
	color_label.text = "색"
	color_row.add_child(color_label)
	_color_pick = ColorPickerButton.new()
	_color_pick.custom_minimum_size = Vector2(80, 30)
	_color_pick.color_changed.connect(func(c: Color) -> void:
		_canvas.ink = c
		_canvas.queue_redraw())
	color_row.add_child(_color_pick)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 17)
	right.add_child(_cost_label)

	_stat_label = RichTextLabel.new()
	_stat_label.bbcode_enabled = true
	_stat_label.fit_content = true
	_stat_label.custom_minimum_size = Vector2(330, 190)
	right.add_child(_stat_label)


func _add_slider(parent: Node, label_text: String, num: Label) -> HSlider:
	var head := HBoxContainer.new()
	parent.add_child(head)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(70, 0)
	head.add_child(l)
	num.add_theme_font_size_override("font_size", 16)
	head.add_child(num)

	var s := HSlider.new()
	s.min_value = 1
	s.max_value = 100
	s.step = 1
	s.custom_minimum_size = Vector2(330, 22)
	s.value_changed.connect(func(_v: float) -> void: _refresh())
	parent.add_child(s)
	return s


func _build_footer() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(row)

	var reset := Button.new()
	reset.text = "기본 스킬로 되돌리기"
	reset.pressed.connect(func() -> void:
		SkillDB.reset_to_defaults()
		_load_slot(_slot))
	row.add_child(reset)

	var save := Button.new()
	save.text = "저장"
	save.custom_minimum_size = Vector2(110, 38)
	save.pressed.connect(_save)
	row.add_child(save)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(90, 38)
	close_btn.pressed.connect(close)
	row.add_child(close_btn)


# ─────────────────────────────────────────────────────────────
# 슬롯 읽기 / 저장 / 표시 갱신
# ─────────────────────────────────────────────────────────────

func _on_slot_pressed(slot: String) -> void:
	_slot = slot
	_load_slot(slot)


func _load_slot(slot: String) -> void:
	_slot = slot
	for s in _slot_buttons:
		(_slot_buttons[s] as Button).button_pressed = (s == slot)

	var skill: Dictionary = SkillDB.get_slot(slot)
	if skill.is_empty():
		_name_edit.text = ""
		_canvas.clear_mask()
		_damage.value = 20
		_range.value = 20
		_color_pick.color = Color(1, 1, 1)
	else:
		_name_edit.text = String(skill["name"])
		_canvas.set_mask(skill["mask"])
		_damage.value = float(skill["damage"])
		_range.value = float(skill["range_pt"])
		_color_pick.color = skill["color"]
	_canvas.ink = _color_pick.color
	_canvas.queue_redraw()
	_refresh()


func _save() -> void:
	var skill_name := _name_edit.text.strip_edges()
	if skill_name.is_empty():
		skill_name = "%s 스킬" % _slot
	SkillDB.set_slot(_slot, SkillDB.make_skill(
		skill_name,
		_canvas.get_mask(),
		_color_pick.color,
		_damage.value,
		_range.value,
	))
	_cost_label.text = "저장됨 — %s 슬롯" % _slot


## 그림이나 수치가 바뀔 때마다 실제 전투 수치를 다시 계산해 보여준다.
func _refresh() -> void:
	if _canvas == null or _stat_label == null:
		return

	_damage_num.text = "%d" % int(_damage.value)
	_range_num.text = "%d" % int(_range.value)

	var mask := _canvas.get_mask()
	var metrics: Dictionary = Balance.analyze_mask(mask)
	var tag: String = Balance.tag_from_metrics(metrics)
	var d: Dictionary = Balance.derive(_damage.value, _range.value, tag)

	_tag_label.text = "형태: %s" % tag

	var cost := float(d["cost"])
	if bool(d["over_budget"]):
		_cost_label.text = "예산 %d / %d — 초과!" % [int(cost), int(Balance.BUDGET)]
		_cost_label.modulate = OVER_COLOR
	else:
		_cost_label.text = "예산 %d / %d — 남음 %d" % [
			int(cost), int(Balance.BUDGET), int(d["leftover"])
		]
		_cost_label.modulate = OK_COLOR

	var box: Dictionary = d["hitbox"]
	var lines := PackedStringArray([
		"[b]전투 수치[/b] (밸런스가 자동 계산)",
		"쿨타임        %.1f 초" % float(d["cooldown"]),
		"발동 시간     %.2f 초" % float(d["cast_time"]),
		"투사체 속도   %.1f m/s" % float(d["speed"]),
		"사거리        %.1f m" % float(d["distance"]),
		"판정 면적     %.2f m²" % float(d["total_area"]),
		"히트박스      %s" % _describe_box(box),
		"한 방 데미지  %.1f" % Balance.damage_per_hit(_damage.value, tag),
		"",
		"[i]그림 지표 — 채움 %.2f · 종횡 %.2f · 복잡 %.2f · 덩어리 %d[/i]" % [
			float(metrics["fill_ratio"]), float(metrics["aspect"]),
			float(metrics["complexity"]), int(metrics["blobs"]),
		],
	])
	_stat_label.text = "\n".join(lines)


func _describe_box(box: Dictionary) -> String:
	match String(box["kind"]):
		"capsule":
			return "캡슐 길이 %.1fm 폭 %.2fm" % [float(box["length"]), float(box["width"])]
		"cone":
			return "부채꼴 %d° 반경 %.1fm" % [int(box["angle_deg"]), float(box["radius"])]
		"scatter":
			return "산탄 %d발 반경 %.2fm" % [int(box["pellets"]), float(box["pellet_radius"])]
		_:
			return "구 반경 %.1fm" % float(box["radius"])
