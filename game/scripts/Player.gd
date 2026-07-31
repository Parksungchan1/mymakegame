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

# ── 카메라 (고정각 3인칭) ─────────────────────────────────────
## 사용자 확정(2026-07-31): 카메라는 **고정 각도**다.
## 마우스로 시점을 돌리지 않는다. 화면이 도는 일이 없으니
## 방향키 ↑는 언제나 화면 위쪽이고, 맵 방향 감각이 흔들리지 않는다.
## 각도를 바꾸고 싶으면 아래 두 값만 손보면 된다.
@export_range(-180.0, 180.0) var cam_yaw_deg: float = 0.0
@export_range(-80.0, 0.0) var cam_pitch_deg: float = -32.0
@export var cam_distance: float = 7.0

# ── 스킬 (로드맵 3a: 에디터의 수치가 실제 발사에 반영) ────────
## 2단계에서는 수치를 여기 직접 박아뒀지만, 3a 부터는 **에디터에서 정한 수치**를 쓴다.
## Tab 으로 제작창을 열어 데미지·범위 슬라이더를 바꾸고 저장하면 바로 반영된다.
##
## 아직 **수치만** 가져온다. 그림은 안 쓴다.
## 그래서 형태 태그는 무조건 기본값 "둥긂"이다 — 어떤 그림을 그려도 구체가 날아간다.
## 그림을 겉모습·형태 태그로 쓰는 건 3b 다. 기획서 87~88행이 3a → 3b 순서를 못박았다.
const PROJECTILE := preload("res://scripts/skill/Projectile.gd")

## 읽어올 슬롯. 3a 는 Q 하나만 쓴다. QWER 4슬롯은 로드맵 4단계다.
const SKILL_SLOT := "Q"

## SkillDB 슬롯이 비었을 때만 쓰는 값(저장 파일이 아직 없는 첫 실행 등)
@export var fallback_skill_name: String = "불꽃탄"
@export_range(1.0, 100.0) var fallback_damage: float = 22.0
@export_range(1.0, 100.0) var fallback_range_pt: float = 18.0
@export var fallback_color: Color = Color(1.0, 0.45, 0.15)

@onready var _pivot: Node3D = $CamPivot
@onready var _arm: SpringArm3D = $CamPivot/SpringArm3D
@onready var _body: Node3D = $Body
@onready var _muzzle: Marker3D = $Body/Wand/Muzzle

## 지금 들고 있는 스킬. `_reload_skill()` 이 SkillDB 에서 채운다.
var skill_name: String = ""
var skill_damage: float = 0.0
var skill_range_pt: float = 0.0
var skill_color: Color = Color.WHITE

## 쿨타임·발동시간·투사체 속도·판정 크기 — 전부 Balance 가 정한다.
var _skill: Dictionary = {}
var _cooldown_left: float = 0.0
var _cast_left: float = 0.0
var _casting: bool = false


func _ready() -> void:
	# 시점 조작이 없으니 마우스는 잡지 않는다. 스킬 제작창에서 그대로 쓴다.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_camera_angle()
	# 제작창에서 저장하면 곧바로 다음 발사에 반영된다.
	SkillDB.slot_changed.connect(_on_slot_changed)
	_reload_skill()


func _on_slot_changed(slot: String) -> void:
	if slot == SKILL_SLOT:
		_reload_skill()


## SkillDB → 지금 들고 있는 스킬. 그림(mask)과 저장된 태그는 일부러 읽지 않는다(3b).
func _reload_skill() -> void:
	var s: Dictionary = SkillDB.get_slot(SKILL_SLOT)
	if s.is_empty():
		skill_name = fallback_skill_name
		skill_damage = fallback_damage
		skill_range_pt = fallback_range_pt
		skill_color = fallback_color
	else:
		skill_name = String(s["name"])
		skill_damage = float(s["damage"])
		skill_range_pt = float(s["range_pt"])
		skill_color = s["color"]
	_skill = Balance.derive(skill_damage, skill_range_pt, Balance.TAG_ROUND)


## 고정각을 실제 노드에 반영. 인스펙터에서 값을 바꿔도 다시 부르면 된다.
func _apply_camera_angle() -> void:
	_pivot.rotation.y = deg_to_rad(cam_yaw_deg)
	_arm.rotation.x = deg_to_rad(cam_pitch_deg)
	_arm.spring_length = cam_distance


func _physics_process(delta: float) -> void:
	_move(delta)
	_tick_skill(delta)


func _move(delta: float) -> void:
	# 방향키 → 화면 기준 이동. 카메라가 고정각이라 이 기준은 절대 안 바뀐다.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := _pivot.global_transform.basis
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
## Godot 에서 앞은 -Z 다. Player.tscn 의 얼굴·마법봉도 -Z 쪽에 붙어 있으니
## 몸의 -Z 축을 진행 방향에 맞춘다. (+Z 로 맞추면 뒤를 보고 달린다)
func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() <= 0.0:
		return
	var target := atan2(-dir.x, -dir.z)
	_body.rotation.y = lerp_angle(_body.rotation.y, target, turn_speed * delta)


## 캐릭터가 보고 있는 방향(수평). 스킬은 이쪽으로 나간다.
func aim_direction() -> Vector3:
	var forward := -_body.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0:
		return Vector3.FORWARD
	return forward.normalized()


# ── 스킬 발사 ────────────────────────────────────────────────
## 순서: Q 누름 → 발동 시간만큼 기다림 → 투사체 발사 → 쿨타임.
## 발동 시간·쿨타임은 Balance 가 정한 값이다. 여기서 임의로 줄이지 않는다.
##
## 발동 중에 느려지게 하지 않는다 — 기획서가 "조준 중 감속"을 넣지 말라고 못박았다.
## 피하는 수단은 이동과 점프뿐이고, 그건 발동 중에도 그대로 살아 있어야 한다.
func _tick_skill(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if _casting:
		_cast_left -= delta
		if _cast_left <= 0.0:
			_casting = false
			_shoot()
		return

	if _cooldown_left <= 0.0 and Input.is_action_just_pressed("skill_q"):
		_casting = true
		_cast_left = float(_skill.get("cast_time", 0.3))


func _shoot() -> void:
	var shot := PROJECTILE.new()
	shot.configure(
		aim_direction(),
		_skill,
		Balance.damage_per_hit(skill_damage, Balance.TAG_ROUND),
		skill_color,
	)
	# 플레이어 밑에 달면 플레이어가 움직일 때 투사체가 같이 끌려간다.
	# 그래서 형제로 붙인다. current_scene 은 씬을 코드로 올렸을 때 비어 있어 쓰지 않는다.
	var world := get_parent()
	if world == null:
		return
	world.add_child(shot)
	shot.global_position = _muzzle.global_position

	_cooldown_left = float(_skill.get("cooldown", 3.0))


## 쿨타임이 얼마나 남았는지 (0.0 = 지금 쏠 수 있음). HUD 가 붙으면 이걸 쓴다.
func cooldown_left() -> float:
	return _cooldown_left
