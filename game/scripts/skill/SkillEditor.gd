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

## 저장 안 한 편집이 있는가. 슬롯을 옮기거나 창을 닫을 때 그림이 조용히 날아가는 걸 막는다.
## 공들여 그린 걸 잃는 건 이 게임에서 제일 아픈 사고다.
var _dirty: bool = false
var _loading: bool = false
var _confirm: ConfirmationDialog
var _pending_slot: String = ""
var _save_btn: Button
var _pen_btn: Button
var _eraser_btn: Button


## 그리기 ↔ 지우개 전환. 두 버튼이 항상 서로 반대 상태가 되게 묶는다.
func _set_erasing(on: bool) -> void:
	_canvas.erasing = on
	_pen_btn.button_pressed = not on
	_eraser_btn.button_pressed = on


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
	_build_confirm()


func _build_confirm() -> void:
	_confirm = ConfirmationDialog.new()
	_confirm.title = "저장 안 한 편집이 있습니다"
	_confirm.ok_button_text = "버리고 옮기기"
	_confirm.cancel_button_text = "돌아가기"
	_confirm.confirmed.connect(_on_confirm_discard)
	_confirm.canceled.connect(_on_confirm_cancel)
	_confirm.close_requested.connect(_on_confirm_cancel)
	add_child(_confirm)


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

	# 그림이 전투에서 뭘 바꾸고 뭘 안 바꾸는지 적어둔다.
	# 이걸 모르면 "선을 얇게 그리면 관통하겠지" 같은 오해를 하게 된다.
	var stage := Label.new()
	stage.text = "그림은 겉모습과 형태를 정합니다. 세기는 수치가 정합니다 — 총 판정 면적은 범위 값으로 고정."
	stage.add_theme_font_size_override("font_size", 13)
	stage.modulate = Color(1.0, 0.85, 0.5, 0.9)
	_root.add_child(stage)


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
	_canvas.mask_changed.connect(_touch)
	left.add_child(_canvas)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	left.add_child(tools)

	# 도구 버튼 — 지우개가 우클릭에만 있어서 아무도 못 찾았다(사용자 보고).
	# 이제 눈에 보이고, 지금 무슨 도구인지도 보인다.
	_pen_btn = Button.new()
	_pen_btn.text = "✏ 그리기"
	_pen_btn.toggle_mode = true
	_pen_btn.button_pressed = true
	_pen_btn.custom_minimum_size = Vector2(96, 34)
	_pen_btn.pressed.connect(func() -> void: _set_erasing(false))
	tools.add_child(_pen_btn)

	_eraser_btn = Button.new()
	_eraser_btn.text = "🧽 지우개"
	_eraser_btn.toggle_mode = true
	_eraser_btn.custom_minimum_size = Vector2(96, 34)
	_eraser_btn.pressed.connect(func() -> void: _set_erasing(true))
	tools.add_child(_eraser_btn)

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
	_name_edit.text_changed.connect(func(_t: String) -> void: _touch())
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
		_canvas.queue_redraw()
		_touch())
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
	s.value_changed.connect(func(_v: float) -> void:
		_refresh()
		_touch())
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

	_save_btn = Button.new()
	_save_btn.text = "저장"
	_save_btn.custom_minimum_size = Vector2(110, 38)
	_save_btn.pressed.connect(_save)
	row.add_child(_save_btn)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(90, 38)
	close_btn.pressed.connect(close)
	row.add_child(close_btn)


# ─────────────────────────────────────────────────────────────
# 슬롯 읽기 / 저장 / 표시 갱신
# ─────────────────────────────────────────────────────────────

func _on_slot_pressed(slot: String) -> void:
	if slot == _slot:
		_sync_slot_buttons()
		return
	# 저장 안 한 편집이 있으면 먼저 물어본다. 안 그러면 그림이 말없이 사라진다.
	if _dirty:
		_pending_slot = slot
		_sync_slot_buttons()   # 아직 안 옮겼으니 버튼은 원래 슬롯에 둔다
		_confirm.dialog_text = "저장하지 않은 편집이 있습니다.\n%s 슬롯으로 옮기면 사라집니다." % slot
		_confirm.popup_centered()
		return
	_load_slot(slot)


func _on_confirm_discard() -> void:
	if _pending_slot.is_empty():
		return
	var slot := _pending_slot
	_pending_slot = ""
	_load_slot(slot)


func _on_confirm_cancel() -> void:
	_pending_slot = ""
	_sync_slot_buttons()


func _sync_slot_buttons() -> void:
	for s in _slot_buttons:
		(_slot_buttons[s] as Button).button_pressed = (s == _slot)


## 편집이 생겼다는 표시. 불러오는 중에는 세지 않는다.
func _touch() -> void:
	if _loading:
		return
	_dirty = true
	_mark_save_button()


## 저장 안 한 게 있으면 버튼에 티를 낸다. 창을 닫아도 편집은 사라지므로
## 슬롯 전환 확인창만으로는 부족하다.
func _mark_save_button() -> void:
	if _save_btn == null:
		return
	_save_btn.text = "저장 ●" if _dirty else "저장"


func _load_slot(slot: String) -> void:
	_slot = slot
	# 불러오는 동안 일어나는 값 변경은 "유저의 편집"이 아니다.
	_loading = true
	_sync_slot_buttons()

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
	_loading = false
	_dirty = false
	_mark_save_button()


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
	_dirty = false
	_mark_save_button()
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

	# 아래 수치는 **실제 전투에 쓰이는 값**이다. 그린 태그가 그대로 전투에 들어간다.
	# 지표(metrics)를 반드시 함께 넘긴다 — 안 넘기면 태그 기본값으로 계산돼
	# 화면과 실제 발사가 어긋난다. Player 도 같은 지표를 넘긴다.
	var combat_tag: String = tag
	var d: Dictionary = Balance.derive(_damage.value, _range.value, combat_tag, metrics)

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
		# `distance` 는 이제 「투사체가 실제로 나는 거리」다. 유저가 알고 싶은 건
		# **어디까지 닿느냐**(`reach`) 이고, 캡슐은 판정이 앞으로 뻗어 있어서 둘이 다르다.
		# `distance` 를 띄우면 길쭉함만 사거리가 짧아 보인다.
		"사거리        %.1f m" % float(d["reach"]),
		"유효 명중 폭  %.2f m" % float(d["effective_width"]),
		"히트박스      %s" % _describe_box(box),
		"전탄 명중     %s" % _describe_full_hit(box, float(d["reach"])),
		"한 방 데미지  %.1f" % Balance.damage_per_hit(
			_damage.value, combat_tag, int(box.get("pellets", 0))),
		"",
		# `신장` 은 회전과 무관한 길쭉함 지표다. 길쭉함 태그는 **이걸** 본다.
		# `종횡` 은 여전히 바운딩박스 가로/세로다 — 이름과 뜻이 그대로라 거짓말은 아니지만,
		# 대각선 막대는 종횡이 1.00 인데 태그가 길쭉함이라 이유가 안 보인다. 그래서 둘 다 띄운다.
		# ⚠ 「종횡」 이라는 이름표를 신장도 값에 붙이지 말 것.
		"[i]그림 지표 — 채움 %.2f · 신장 %.2f · 종횡 %.2f · 복잡 %.2f · 덩어리 %d[/i]" % [
			float(metrics["fill_ratio"]), float(metrics.get("elongation", 1.0)),
			float(metrics["aspect"]),
			float(metrics["complexity"]), int(metrics["blobs"]),
		],
	])
	_stat_label.text = "\n".join(lines)


## 여러 발로 나가는 태그는 멀어지면 바깥 탄부터 빗나가 데미지가 계단식으로 떨어진다.
## 그 경계가 어디인지 안 보여주면 유저는 "왜 멀리서는 약하지?" 를 영영 알 수 없다.
## (기획서 87행 — 유저가 예측 가능하게 한다)
func _describe_full_hit(box: Dictionary, distance: float) -> String:
	var pellets := int(box.get("pellets", 1))
	if pellets <= 1:
		return "사거리 전체 (단발)"

	var keep: float = Balance.full_hit_distance(
		float(box.get("pellet_radius", 0.0)), _spread_of(box))
	if is_inf(keep) or keep >= distance:
		return "사거리 전체 (%.1fm)" % distance
	return "%.1fm 까지 — 그 뒤로는 일부만 맞는다 (사거리 %.1fm)" % [keep, distance]


## 이 히트박스가 실제로 퍼지는 각도(도).
## `hitbox_for` 가 흩어짐에는 `angle_deg` 를 안 채운다. 그걸 그대로 믿으면 0° →
## `full_hit_distance` 가 INF → 화면에 "사거리 전체" 라고 뜬다. 실제로는 8.6m 부터
## 3발, 16.9m 부터 1발만 맞는데도. (QA N1 — 위반 4가 흩어짐에서 재발한 자리다)
func _spread_of(box: Dictionary) -> float:
	var angle := float(box.get("angle_deg", 0.0))
	if angle > 0.0:
		return angle
	match String(box.get("kind", "sphere")):
		"scatter":
			return Balance.SCATTER_SPREAD_DEG
		"cone":
			return Balance.CONE_SPREAD_DEG
		_:
			return 0.0


func _describe_box(box: Dictionary) -> String:
	match String(box["kind"]):
		"capsule":
			return "캡슐 길이 %.1fm 폭 %.2fm" % [float(box["length"]), float(box["width"])]
		"cone":
			# `angle_deg` 는 이제 실제로 쏘는 퍼짐각과 같은 값이다.
			# (예전엔 판정각 90° 를 띄우면서 실제로는 11° 로 쏴 화면이 거짓말을 했다)
			return "부채꼴 %.0f° · 작은 탄 %d발" % [
				float(box.get("angle_deg", Balance.CONE_SPREAD_DEG)),
				int(box.get("pellets", Balance.CONE_PELLETS))]
		"scatter":
			# 퍼짐각을 상수로 띄우면 안 된다. 탄 수에 따라 18/24/27° 로 갈리므로
			# 상수를 띄우는 순간 화면이 틀린 값을 말하게 된다. 부채꼴과 같은 규칙이다.
			return "산탄 %d발 · 반경 %.2fm · 퍼짐 %.0f°" % [
				int(box["pellets"]), float(box["pellet_radius"]), _spread_of(box)]
		_:
			return "구 반경 %.1fm" % float(box["radius"])
