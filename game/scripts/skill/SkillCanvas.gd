extends Control
class_name SkillCanvas
## 32×32 그림판. 좌클릭 칠하기 / 우클릭 지우기 / 드래그 연속 칠하기.
##
## 여기서 나온 mask 가 Balance.analyze_mask() 로 들어가 형태 태그가 된다.
## 이 스크립트는 "그림"만 책임진다. 밸런스 계산은 절대 여기서 하지 않는다.

signal mask_changed

## 칠해진 칸 색 (에디터에서 스킬 색으로 바꿔준다)
var ink: Color = Color(1.0, 0.45, 0.15)

var _mask: PackedByteArray
## 지금 누르고 있는 값. 1=칠하기 0=지우기. -1 이면 안 누르는 중.
var _stroke: int = -1
## 드래그 보간용. 이전에 칠한 칸.
var _last_cell: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	_mask = PackedByteArray()
	_mask.resize(Balance.GRID * Balance.GRID)
	custom_minimum_size = Vector2(360, 360)
	focus_mode = Control.FOCUS_NONE


func get_mask() -> PackedByteArray:
	return _mask.duplicate()


func set_mask(m: PackedByteArray) -> void:
	_mask = PackedByteArray()
	_mask.resize(Balance.GRID * Balance.GRID)
	for i in mini(m.size(), _mask.size()):
		_mask[i] = 1 if m[i] != 0 else 0
	queue_redraw()
	mask_changed.emit()


func clear_mask() -> void:
	for i in _mask.size():
		_mask[i] = 0
	queue_redraw()
	mask_changed.emit()


## 한 변의 픽셀 크기. 정사각형으로 유지한다.
func _cell() -> float:
	return minf(size.x, size.y) / float(Balance.GRID)


## 그림판 왼쪽 위 모서리(가운데 정렬 여백)
func _origin() -> Vector2:
	var side := _cell() * float(Balance.GRID)
	return (size - Vector2(side, side)) * 0.5


func _pos_to_cell(p: Vector2) -> Vector2i:
	var c := _cell()
	if c <= 0.0:
		return Vector2i(-1, -1)
	var local := p - _origin()
	return Vector2i(int(floor(local.x / c)), int(floor(local.y / c)))


func _paint(cell: Vector2i, value: int) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= Balance.GRID or cell.y >= Balance.GRID:
		return
	var i := cell.y * Balance.GRID + cell.x
	if _mask[i] == value:
		return
	_mask[i] = value
	queue_redraw()
	mask_changed.emit()


## 드래그가 빨라도 칸이 빠지지 않게 이전 칸과 직선으로 이어 칠한다.
func _paint_line(from: Vector2i, to: Vector2i, value: int) -> void:
	if from.x < 0:
		_paint(to, value)
		return
	var d := to - from
	var steps := maxi(absi(d.x), absi(d.y))
	if steps == 0:
		_paint(to, value)
		return
	for s in range(steps + 1):
		var t := float(s) / float(steps)
		_paint(Vector2i(
			int(round(lerpf(float(from.x), float(to.x), t))),
			int(round(lerpf(float(from.y), float(to.y), t))),
		), value)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_stroke = 1 if mb.button_index == MOUSE_BUTTON_LEFT else 0
				_last_cell = _pos_to_cell(mb.position)
				_paint(_last_cell, _stroke)
			else:
				_stroke = -1
				_last_cell = Vector2i(-1, -1)
			accept_event()
	elif event is InputEventMouseMotion and _stroke >= 0:
		var cell := _pos_to_cell((event as InputEventMouseMotion).position)
		_paint_line(_last_cell, cell, _stroke)
		_last_cell = cell
		accept_event()


func _draw() -> void:
	var c := _cell()
	var o := _origin()
	var side := c * float(Balance.GRID)

	draw_rect(Rect2(o, Vector2(side, side)), Color(0.10, 0.10, 0.14))

	# 칠해진 칸
	for y in Balance.GRID:
		for x in Balance.GRID:
			if _mask[y * Balance.GRID + x] == 0:
				continue
			draw_rect(Rect2(o + Vector2(x * c, y * c), Vector2(c, c)), ink)

	# 격자선 — 8칸마다 진하게
	var thin := Color(1, 1, 1, 0.07)
	var thick := Color(1, 1, 1, 0.18)
	for i in Balance.GRID + 1:
		var col := thick if i % 8 == 0 else thin
		var fx := o.x + i * c
		var fy := o.y + i * c
		draw_line(Vector2(fx, o.y), Vector2(fx, o.y + side), col, 1.0)
		draw_line(Vector2(o.x, fy), Vector2(o.x + side, fy), col, 1.0)
