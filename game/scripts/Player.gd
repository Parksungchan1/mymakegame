extends CharacterBody2D
## 플레이어 — 로드맵 1단계: 방향키 이동 + 스페이스 점프
##
## 탑다운이라 진짜 중력 점프가 아니라 "홉(hop)"이다.
## 몸통 스프라이트만 위로 떴다 내려오고, 그림자는 작아진다.
## 기획서의 회피 수단(이동 + 점프)이 이 홉이다.

@export var speed: float = 260.0
@export var accel: float = 2000.0
@export var friction: float = 2400.0

## 홉이 얼마나 높이 뜨는지(픽셀)
@export var hop_height: float = 34.0
## 홉 한 번에 걸리는 시간(초)
@export var hop_time: float = 0.40

@onready var _body: Node2D = $Body
@onready var _shadow: Node2D = $Shadow

## 홉 진행 시간. 음수면 땅에 있는 상태.
var _hop_t: float = -1.0


func is_hopping() -> bool:
	return _hop_t >= 0.0


func _physics_process(delta: float) -> void:
	_move(delta)
	_hop(delta)


func _move(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(dir * speed, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()


func _hop(delta: float) -> void:
	if Input.is_action_just_pressed("jump") and not is_hopping():
		_hop_t = 0.0

	if not is_hopping():
		return

	_hop_t += delta
	var p := _hop_t / hop_time
	if p >= 1.0:
		# 착지 — 원래 자리로 정확히 되돌린다
		_hop_t = -1.0
		_body.position.y = 0.0
		_shadow.scale = Vector2.ONE
		return

	# 0 → 1 → 0 으로 떴다 내려오는 곡선
	var h := sin(p * PI)
	_body.position.y = -h * hop_height
	var s := 1.0 - h * 0.35
	_shadow.scale = Vector2(s, s)
