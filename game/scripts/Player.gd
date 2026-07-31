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

# ── 스킬 (로드맵 3b: 그린 그림이 그대로 날아간다) ────────────
## Tab 으로 제작창을 열어 **그림을 그리고** 데미지·범위를 정한 뒤 저장하면
## 그 그림이 그대로 투사체가 되어 날아간다. 이 게임의 심장이다.
##
## 그림이 정하는 것: 겉모습 + 형태 태그(길쭉함/둥긂/뾰족함/흩어짐)
## 수치가 정하는 것: 세기 — 데미지·범위. 총 판정 면적은 범위 값으로 정규화된다.
## 그래서 어떤 그림을 그려도 같은 범위면 총 면적이 같다. 그림으로 세지게 만들 수 없다.
const PROJECTILE := preload("res://scripts/skill/Projectile.gd")

## 읽어올 슬롯. 지금은 Q 하나만 쓴다. QWER 4슬롯은 로드맵 4단계다.
const SKILL_SLOT := "Q"

## 투사체가 바닥에서 최소한 이만큼은 떠서 태어나야 한다(판정 반경 위에 더한다).
const GROUND_CLEARANCE := 0.08

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
var skill_mask: PackedByteArray = PackedByteArray()
var skill_tag: String = ""

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


## SkillDB → 지금 들고 있는 스킬. 그림·형태 태그까지 전부 읽는다.
func _reload_skill() -> void:
	var s: Dictionary = SkillDB.get_slot(SKILL_SLOT)
	if s.is_empty():
		skill_name = fallback_skill_name
		skill_damage = fallback_damage
		skill_range_pt = fallback_range_pt
		skill_color = fallback_color
		skill_mask = PackedByteArray()
		skill_tag = Balance.TAG_ROUND
	else:
		skill_name = String(s["name"])
		skill_damage = float(s["damage"])
		skill_range_pt = float(s["range_pt"])
		skill_color = s["color"]
		skill_mask = s["mask"]
		# 저장된 태그를 믿지 않고 그림에서 다시 뽑는다.
		# 기획 담당이 판정 임계값을 바꾸면 저장된 스킬에도 바로 반영돼야 한다.
		skill_tag = Balance.tag_from_mask(skill_mask)
	_skill = Balance.derive(skill_damage, skill_range_pt, skill_tag)


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
		# NaN 이 들어오면 어떤 비교도 false 라 _casting 이 영영 안 풀리고
		# 스킬이 완전히 잠긴다. 망가진 값은 여기서 걸러낸다.
		_cast_left = _safe_time(_skill.get("cast_time", 0.3), 0.3)


## 시간 값이 NaN·무한대·음수면 기본값으로 되돌린다.
func _safe_time(value: Variant, fallback: float) -> float:
	var v := float(value)
	if is_nan(v) or is_inf(v) or v < 0.0:
		return fallback
	return v


## 형태 태그에 따라 한 발 또는 여러 발을 뿌린다.
## 나누는 건 여기 일이고, 투사체는 "한 발"만 안다.
## 발 수와 한 발 데미지는 Balance 가 정한 것을 그대로 따른다 —
## 여기서 발 수를 바꾸면 총 데미지가 어긋난다.
func _shoot() -> void:
	var dir := aim_direction()
	var box: Dictionary = _skill.get("hitbox", {})
	var kind := String(box.get("kind", "sphere"))
	var dmg: float = Balance.damage_per_hit(skill_damage, skill_tag)

	match kind:
		"scatter":
			# 산탄 다발 — 작은 탄이 좁게 퍼진다
			_spawn_spread(dir, int(box.get("pellets", 5)),
				Balance.SCATTER_SPREAD_DEG, float(box.get("pellet_radius", 0.3)), dmg)
		"cone":
			# 부채꼴 다단 히트 — 작은 탄을 부챗살로 뿌린다.
			# 퍼짐각에 히트박스의 angle_deg(판정 각 90°)를 쓰면 안 된다.
			# 그러면 10m 앞에서 바깥 탄이 10m 옆으로 날아가 사실상 안 맞는다.
			_spawn_spread(dir, int(box.get("pellets", Balance.CONE_PELLETS)),
				Balance.CONE_SPREAD_DEG, float(box.get("pellet_radius", 0.3)), dmg)
		_:
			# 둥긂(구) · 길쭉함(캡슐) — 한 발
			_spawn(dir, box, dmg)

	_cooldown_left = _safe_time(_skill.get("cooldown", 3.0), 3.0)


## 부챗살로 count 발. 가운데를 기준으로 spread_deg 안에 고르게 편다.
func _spawn_spread(dir: Vector3, count: int, spread_deg: float,
		pellet_radius: float, dmg: float) -> void:
	count = maxi(count, 1)
	var shape := {"kind": "sphere", "radius": pellet_radius}
	for i in count:
		# count 가 1이면 정가운데, 아니면 -spread/2 ~ +spread/2 로 편다
		var t: float = 0.5 if count == 1 else float(i) / float(count - 1)
		var angle := deg_to_rad(lerpf(-spread_deg * 0.5, spread_deg * 0.5, t))
		_spawn(dir.rotated(Vector3.UP, angle), shape, dmg)


## 투사체 한 발. 그림·색·수치를 실어 보낸다.
func _spawn(dir: Vector3, shape: Dictionary, dmg: float) -> void:
	# 플레이어 밑에 달면 플레이어가 움직일 때 투사체가 같이 끌려간다.
	# 그래서 형제로 붙인다. current_scene 은 씬을 코드로 올렸을 때 비어 있어 쓰지 않는다.
	var world := get_parent()
	if world == null:
		return

	var shot := PROJECTILE.new()
	shot.configure(dir, {
		"speed": _skill.get("speed", 20.0),
		"distance": _skill.get("distance", 12.0),
		"shape": shape,
		"damage": dmg,
		"color": skill_color,
		"mask": skill_mask,
	})
	world.add_child(shot)
	shot.global_position = _spawn_point(shape)


## 투사체가 태어날 자리.
## 총구 높이는 1m 남짓인데 판정 반경은 범위 값에 따라 그보다 커질 수 있다.
## 그대로 두면 태어나는 순간 바닥과 겹쳐 `body_entered` 가 터지고 즉시 사라진다 —
## 실제로 기본 스킬 Q(불꽃탄)와 R(대폭발)이 한 발도 안 나가고 있었다.
## 그래서 판정이 바닥을 벗어나도록 최소 높이를 보장한다.
func _spawn_point(shape: Dictionary) -> Vector3:
	var pos := _muzzle.global_position
	var clearance := float(shape.get("radius", 0.5)) + GROUND_CLEARANCE
	pos.y = maxf(pos.y, global_position.y + clearance)
	return pos


## 쿨타임이 얼마나 남았는지 (0.0 = 지금 쏠 수 있음). HUD 가 붙으면 이걸 쓴다.
func cooldown_left() -> float:
	return _cooldown_left
