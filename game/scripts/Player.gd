extends CharacterBody3D
## 플레이어 — 3D 3인칭. 로드맵 1단계(이동 + 점프).
##
## 조작은 기획서 7행 그대로다: 이동 = 방향키, 점프 = 스페이스, 스킬 = QWER.
## WASD 는 QWER 스킬과 손이 겹쳐서 쓰지 않는다.
##
## 움직임 목표는 멧챠 카멜레온풍 — 작고 날쌘 캐릭터가 톡톡 움직이는 느낌이다.
## 그래서 가속·감속을 짧게 잡아 조작이 바로 먹히게 했다.
##
## 총 게임이 아니다. 마법봉으로 QWER 스킬을 쓰는 게임이라
## 조준(ADS)·스프린트 같은 개념은 두지 않는다. 기획서에 없다.
##
## 속도 단위는 m/s.

# ── 이동 ──────────────────────────────────────────────────────
@export var move_speed: float = 6.0
## 방향키를 떼거나 꺾었을 때 바로 반응하도록 가감속을 세게 준다.
@export var accel: float = 55.0
@export var friction: float = 65.0
## 점프로 뜨는 높이(m). 기획서의 회피 수단은 이동 + 점프뿐이다.
@export var jump_height: float = 1.2
## 중력. 현실값(9.8)보다 세야 점프가 쫀득하다.
@export var gravity: float = 22.0
## 진행 방향으로 몸이 도는 속도
@export var turn_speed: float = 14.0

# ── 카메라 (뒤에서 따라오는 3인칭) ─────────────────────────────
@export var mouse_sens: float = 0.0028
@export var pitch_min_deg: float = -50.0
@export var pitch_max_deg: float = 20.0
@export var cam_distance: float = 5.0

@onready var _yaw: Node3D = $CamYaw
@onready var _arm: SpringArm3D = $CamYaw/SpringArm3D
@onready var _body: Node3D = $Body

## 카메라 상하 각(라디안)
var _pitch: float = -0.25


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_arm.spring_length = cam_distance
	_arm.rotation.x = _pitch


func _unhandled_input(event: InputEvent) -> void:
	# ESC 로 마우스를 풀어준다(스킬 제작창을 쓰거나 창 밖으로 나갈 때)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	# 화면을 다시 클릭하면 재캡처
	if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		_yaw.rotate_y(-mm.relative.x * mouse_sens)
		_pitch = clampf(
			_pitch - mm.relative.y * mouse_sens,
			deg_to_rad(pitch_min_deg),
			deg_to_rad(pitch_max_deg),
		)
		_arm.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	_move(delta)


func _move(delta: float) -> void:
	# 방향키 → 카메라가 보는 방향 기준의 이동 벡터
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := _yaw.global_transform.basis
	var dir := (basis.x * input_dir.x + basis.z * input_dir.y)
	dir.y = 0.0
	if dir.length_squared() > 0.0:
		dir = dir.normalized()

	# 수평 속도만 가감속한다. 수직(중력/점프)은 따로 둔다.
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if dir != Vector3.ZERO:
		flat = flat.move_toward(dir * move_speed, accel * delta)
	else:
		flat = flat.move_toward(Vector3.ZERO, friction * delta)
	velocity.x = flat.x
	velocity.z = flat.z

	# 중력 + 점프
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = sqrt(2.0 * gravity * jump_height)
	else:
		velocity.y -= gravity * delta

	move_and_slide()
	_face(dir, delta)


## 캐릭터는 자기가 가는 방향을 본다.
func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() <= 0.0:
		return
	var target := atan2(dir.x, dir.z)
	_body.rotation.y = lerp_angle(_body.rotation.y, target, turn_speed * delta)
