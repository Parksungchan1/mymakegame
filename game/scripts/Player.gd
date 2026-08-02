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
## 점프로 뜨는 높이(m).
@export var jump_height: float = 1.2

## 공중에서 한 번 더 뛸 수 있는 높이(m). 1단보다 살짝 낮게 잡아 남발을 막는다.
## 2026-08-01 사용자 요구로 추가 — **"스킬을 피하면서 해야 하기 때문"** 이 이유다.
## 즉 이건 이동 편의가 아니라 **회피 수단**이다. 그래서 공중에서 방향을 꺾을 수 있어야
## 의미가 있고, 실제로 그렇게 만들었다(`_move` 의 가감속이 공중에서도 그대로 먹는다).
@export var double_jump_height: float = 1.0

## 공중 덤블링 한 바퀴에 걸리는 시간(초). 짧을수록 팽팽 돈다.
## 연출이지만 기능도 겸한다 — 2단을 썼는지 눈으로 바로 알 수 있다.
@export var flip_time: float = 0.42

# ── 대쉬 (Shift) ───────────────────────────────────────────────
## 2026-08-01 사용자 요구. **회피 수단**이고 스킬창에 칸을 갖는다.
## 아래 수치는 개발이 임시로 잡은 것이다 — **밸런스는 기획 담당이 정한다.**
## 확정되면 Balance 로 옮기거나 여기 값을 기획이 준 값으로 갈아끼운다.
@export var dash_speed: float = 22.0
@export var dash_time: float = 0.18
@export var dash_cooldown: float = 3.0
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
## 2026-08-02: 7.0 → 6.0. 사용자가 "캐릭터도 좀 작아" 라고 해서 아트가
## 7.0/6.2/6.0/5.6/5.2/5.0 을 전부 렌더해 6.0 을 골랐다.
## 🔑 예상과 달리 **당겨도 북쪽(적이 오는 쪽) 시야는 거의 안 줄어든다** —
## 화면 위 가장자리가 수평선 위라 거리와 무관하게 벽까지 보인다. 줄어드는 건 좌우뿐(−14%).
## 5.0(−29%)은 「스킬을 피하는 게임」의 전제를 건드리기 시작해서 뺐다.
@export var cam_distance: float = 6.0

# ── 스킬 (로드맵 3b: 그린 그림이 그대로 날아간다) ────────────
## Tab 으로 제작창을 열어 **그림을 그리고** 데미지·범위를 정한 뒤 저장하면
## 그 그림이 그대로 투사체가 되어 날아간다. 이 게임의 심장이다.
##
## 그림이 정하는 것: 겉모습 + 형태 태그(길쭉함/둥긂/뾰족함/흩어짐)
## 수치가 정하는 것: 세기 — 데미지·범위. 총 판정 면적은 범위 값으로 정규화된다.
## 그래서 어떤 그림을 그려도 같은 범위면 총 면적이 같다. 그림으로 세지게 만들 수 없다.
const PROJECTILE := preload("res://scripts/skill/Projectile.gd")

## QWER 4슬롯. 슬롯마다 쿨타임이 따로 돈다 — 하나 쓰고 다른 걸 바로 쓸 수 있다.
## 슬롯 이름은 `SkillDB.SLOTS` 와 같고, 입력 액션 이름은 `skill_<소문자>` 규칙이다.
const SLOT_ACTIONS := {
	"Q": "skill_q",
	"W": "skill_w",
	"E": "skill_e",
	"R": "skill_r",
}

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
## 조준 화살표. 아트가 만든 노드라 없을 수도 있다고 보고 안전하게 받는다.
@onready var _arrow: Node3D = get_node_or_null("Body/AimArrow")

# ── 애니메이션 관절 (아트가 만든 피벗) ────────────────────────
## 아트 계약: 피벗은 전부 basis 단위행렬이고 **`rotation.x` 양수 = 앞(-Z)으로 돈다.**
## `Body/Wand` 가 오른쪽 어깨를 겸한다 — 그래서 **한 줄로 팔+손+마법봉이 통째로 올라간다.**
## (`$Body/Wand/Muzzle` 경로를 지키려고 그 위에 노드를 못 끼웠기 때문)
@onready var _hip_l: Node3D = get_node_or_null("Body/HipL")
@onready var _hip_r: Node3D = get_node_or_null("Body/HipR")
@onready var _shoulder_l: Node3D = get_node_or_null("Body/ShoulderL")
@onready var _wand_arm: Node3D = get_node_or_null("Body/Wand")

## 걷기 위상(라디안). 속도에 비례해 돌아간다.
var _step_phase: float = 0.0
## 시전 모션 진행도(0=안 함, 1=시작). 시간이 흐르며 0 으로 줄어든다.
var _cast_anim: float = 0.0
var _cast_anim_time: float = 0.45

## 슬롯 하나가 들고 있는 것. `_reload_slot()` 이 SkillDB 에서 채운다.
## 키: name · damage · range_pt · color · mask · tag · derived(Balance 계산 결과)
var _slots: Dictionary = {}
## 슬롯별 남은 쿨타임(초). 슬롯마다 따로 돈다.
var _cooldowns: Dictionary = {}
## 슬롯별 **직전** 전체 쿨타임. 스킬을 갈아끼울 때 "얼마나 식었는지" 비율을 지키는 데 쓴다.
var _prev_cooldown_total: Dictionary = {}

## 지금 발동 중인 슬롯("" = 없음). 발동 중에는 다른 스킬도 못 쓴다 —
## 네 개를 동시에 캐스팅하면 마법봉이 네 개 필요하다.
var _casting_slot: String = ""
var _cast_left: float = 0.0

## 공중에서 2단 점프를 아직 쓸 수 있는가. 땅에 닿으면 다시 채워진다.
var _double_ready: bool = false
## 덤블링 남은 시간(초). 0 보다 크면 도는 중이다.
var _flip_left: float = 0.0

## 대쉬 남은 시간(초)과 방향. 0 보다 크면 대쉬 중이다.
var _dash_left: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
var _dash_cool: float = 0.0


## 화면 흔들림. 카메라에 코드로 붙인다 —
## `Player.tscn` 은 아트 담당 파일이라 개발이 노드를 심지 않는다.
const SCREEN_SHAKE := preload("res://scripts/ScreenShake.gd")
var _shake: Node

# ── 체력 / 죽음 ───────────────────────────────────────────────
## 2026-08-02 신설. 그 전까지 **플레이어는 맞지도 죽지도 않았다**(QA 6차 1-A).
## 기획서가 `DAMAGE_SCALE 0.40` 의 근거로 「HP 바가 100→60→20 으로 꺾인다」를 들었는데
## 정작 HP 가 없었다. 이제 실재한다.
signal health_changed(hp: float, max_hp: float)
signal died

@export var max_hp: float = 100.0
## 죽고 다시 살아나기까지(초)
@export var respawn_delay: float = 2.0
## 부활 직후 잠깐 무적. 스폰 지점에 탄이 깔려 있으면 계속 죽는다.
@export var spawn_grace: float = 1.2

var hp: float = 100.0
var _dead: bool = false
var _grace: float = 0.0
var _spawn_point_saved: Vector3 = Vector3.ZERO


func _ready() -> void:
	# 시점 조작이 없으니 마우스는 잡지 않는다. 스킬 제작창에서 그대로 쓴다.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_camera_angle()
	_attach_shake()
	_attach_bots()
	# 제작창에서 저장하면 곧바로 다음 발사에 반영된다.
	SkillDB.slot_changed.connect(_on_slot_changed)
	for slot in SLOT_ACTIONS:
		_cooldowns[slot] = 0.0
		_reload_slot(slot)
	hp = max_hp
	_spawn_point_saved = global_position
	health_changed.emit(hp, max_hp)


func _on_slot_changed(slot: String) -> void:
	if SLOT_ACTIONS.has(slot):
		_reload_slot(slot)


## SkillDB → 슬롯 하나. 그림·형태 태그까지 전부 읽는다.
func _reload_slot(slot: String) -> void:
	var s: Dictionary = SkillDB.get_slot(slot)
	var entry := {}
	# 그림 지표. 빈 그림이면 빈 Dictionary — 그러면 미세 파라미터 없이 태그 기본값으로 간다.
	var metrics := {}
	if s.is_empty():
		entry["name"] = fallback_skill_name
		entry["damage"] = fallback_damage
		entry["range_pt"] = fallback_range_pt
		entry["color"] = fallback_color
		entry["mask"] = PackedByteArray()
		entry["tag"] = Balance.TAG_ROUND
	else:
		entry["name"] = String(s["name"])
		entry["damage"] = float(s["damage"])
		entry["range_pt"] = float(s["range_pt"])
		entry["color"] = s["color"]
		entry["mask"] = s["mask"]
		# 저장된 태그를 믿지 않고 그림에서 다시 뽑는다.
		# 기획 담당이 판정 임계값을 바꾸면 저장된 스킬에도 바로 반영돼야 한다.
		metrics = Balance.analyze_mask(entry["mask"])
		entry["tag"] = Balance.tag_from_metrics(metrics)
	entry["metrics"] = metrics
	# 지표를 함께 넘겨야 **같은 태그 안에서도 어떻게 그렸는지가 전투에 반영된다.**
	# (흩어짐의 탄 수, 뾰족함의 탄 수·퍼짐각 등 — 안 넘기면 태그 기본값으로만 나간다)
	entry["derived"] = Balance.derive(
		float(entry["damage"]), float(entry["range_pt"]), String(entry["tag"]), metrics)
	_slots[slot] = entry

	# 🐞 쿨타임 건너뛰기 막기 (QA 6차 실증)
	# 싼 스킬(쿨 0.6초)을 쏘고 → 제작창에서 그 슬롯을 비싼 스킬(쿨 25.2초)로 바꾸면
	# 남은 쿨 0.6초만 기다리고 25.2초짜리를 쏠 수 있었다.
	# **예산 초과 페널티라는 유일한 방어선을 통째로 우회한다.**
	# 그래서 스킬을 갈아끼우면 남은 쿨을 새 스킬 기준으로 다시 잡는다.
	# 이미 식은 만큼의 **비율**은 인정한다 — 다 기다린 걸 처음부터 다시 시키면 그건 벌이다.
	var new_cool: float = float(entry["derived"].get("cooldown", 0.0))
	var old_left: float = float(_cooldowns.get(slot, 0.0))
	if old_left > 0.0 and new_cool > 0.0:
		var old_total: float = maxf(_prev_cooldown_total.get(slot, new_cool), 0.001)
		var ratio: float = clampf(old_left / old_total, 0.0, 1.0)
		_cooldowns[slot] = new_cool * ratio
	_prev_cooldown_total[slot] = new_cool


## 봇을 아레나에 심는다.
## `Arena.tscn` 은 아트 담당 파일이라 개발이 노드를 심지 않는다 — 코드로 붙인다.
## 플레이어가 씬에 있을 때만 봇이 의미가 있으므로 여기서 부른다.
func _attach_bots() -> void:
	var world := get_parent()
	if world == null or world.get_node_or_null("Bots") != null:
		return
	# `preload` 금지 — BotSpawner 가 Player.tscn 을 부르므로 순환이 된다.
	var script: GDScript = load("res://scripts/BotSpawner.gd")
	if script == null:
		return
	var spawner: Node = script.new()
	spawner.name = "Bots"
	# `_ready` 중에는 부모가 자식을 세우는 중이라 형제를 못 붙인다. 한 프레임 미룬다.
	world.add_child.call_deferred(spawner)


## 카메라에 흔들림 노드를 매단다. 카메라 각도는 건드리지 않고 화면 오프셋만 흔든다.
func _attach_shake() -> void:
	var cam := _arm.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	_shake = SCREEN_SHAKE.new()
	_shake.name = "ScreenShake"
	cam.add_child(_shake)


## 「쿵」. 적을 쓰러뜨렸을 때 부른다.
## 흔들림 + **히트스톱**. 아트 판단: 히트스톱이 "제일 싸고 제일 센" 타격감 장치다.
## 시간을 아주 잠깐 늦추면 뇌가 "묵직하게 맞았다" 로 읽는다.
func shake_kill() -> void:
	if _shake != null:
		_shake.kill()
	Sfx.play("kill", 1.0, 2.0)
	_hitstop(0.07)


## 아주 짧게 시간을 늦춘다. 길면 렉으로 느껴지므로 0.1초를 넘기지 않는다.
func _hitstop(seconds: float) -> void:
	if seconds <= 0.0 or Engine.time_scale < 1.0:
		return   # 이미 걸려 있으면 겹쳐 걸지 않는다
	Engine.time_scale = 0.05
	# 늦춰진 시간 기준이 아니라 **실제 시간** 기준으로 풀어야 한다.
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


## 맞혔을 때. 죽인 것보다 훨씬 약하다.
func shake_hit() -> void:
	if _shake != null:
		_shake.hit()


## 고정각을 실제 노드에 반영. 인스펙터에서 값을 바꿔도 다시 부르면 된다.
func _apply_camera_angle() -> void:
	_pivot.rotation.y = deg_to_rad(cam_yaw_deg)
	_arm.rotation.x = deg_to_rad(cam_pitch_deg)
	_arm.spring_length = cam_distance


func _physics_process(delta: float) -> void:
	if _grace > 0.0:
		_grace = maxf(_grace - delta, 0.0)
	if _dead:
		# 죽어 있는 동안엔 조작도 발사도 안 된다. 중력만 받는다.
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	_move(delta)
	_tick_skill(delta)
	_animate(delta)


# ── 피격 / 죽음 ───────────────────────────────────────────────
## 투사체가 부르는 창구. `Dummy.take_damage` 와 **같은 계약**이다 —
## false 를 돌려주면 "안 맞았다" 는 뜻이고 투사체가 그냥 지나간다.
func take_damage(amount: float) -> bool:
	if _dead or _grace > 0.0:
		return false
	hp = maxf(hp - amount, 0.0)
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()
	else:
		# 맞은 걸 화면으로 알린다. 소리와 흔들림이 없으면 맞았는지도 모른다.
		shake_hit()
		Sfx.play("hit", 1.15, -3.0)
	return true


func is_dead() -> bool:
	return _dead


func _die() -> void:
	_dead = true
	died.emit()
	Sfx.play("kill", 0.85, 0.0)
	if _shake != null:
		_shake.kill()
	# 쓰러진다. 부활할 때 되돌린다.
	_body.rotation.z = deg_to_rad(80.0)
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


func _respawn() -> void:
	_body.rotation.z = 0.0
	_body.rotation.x = 0.0
	global_position = _spawn_point_saved
	velocity = Vector3.ZERO
	hp = max_hp
	_dead = false
	_grace = spawn_grace
	_flip_left = 0.0
	_dash_left = 0.0
	for slot in SLOT_ACTIONS:
		_cooldowns[slot] = 0.0
	_dash_cool = 0.0
	health_changed.emit(hp, max_hp)


# ── 애니메이션 ────────────────────────────────────────────────
## 걷기(다리·왼팔 흔들기) · 점프(다리 모으기) · 시전(팔 올렸다 내리치기).
##
## 뼈대 애니메이션 리소스를 쓰지 않고 코드로 각도를 준다.
## 관절이 여섯 개뿐이고 전부 한 축 회전이라, 리소스를 만드는 것보다
## 여기서 수식으로 도는 게 읽기도 쉽고 속도에 맞춰 늘였다 줄였다 하기도 쉽다.
const STEP_SWING := 0.62      ## 걸을 때 다리가 앞뒤로 흔들리는 최대 각(라디안)
const STEP_RATE := 1.45       ## 속도 1m/s 당 걷기 위상이 도는 속도
const AIR_TUCK := 0.45        ## 공중에서 다리를 모으는 각
const CAST_LIFT := 1.26       ## 시전 때 팔이 올라가는 최대 각(약 72°)
const CAST_STRIKE := -0.31    ## 내리칠 때 반대로 넘어가는 각(약 -18°)


func _animate(delta: float) -> void:
	if _cast_anim > 0.0:
		_cast_anim = maxf(_cast_anim - delta / _cast_anim_time, 0.0)

	var speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor():
		_step_phase += speed * STEP_RATE * delta
	else:
		# 공중에선 다리를 멈춘다. 허공에서 걷는 것처럼 보이면 안 된다.
		_step_phase = lerpf(_step_phase, 0.0, minf(delta * 6.0, 1.0))

	_animate_legs(speed, delta)
	_animate_arms(delta)


## 다리 — 걸으면 앞뒤로 엇갈리고, 공중에선 모은다.
func _animate_legs(speed: float, delta: float) -> void:
	if _hip_l == null or _hip_r == null:
		return
	var target_l: float
	var target_r: float
	if is_on_floor():
		# 속도가 빠를수록 크게 흔든다. 멈추면 0 으로 잦아든다.
		var amp: float = STEP_SWING * clampf(speed / move_speed, 0.0, 1.0)
		target_l = sin(_step_phase) * amp
		target_r = -target_l
	else:
		# 점프 중엔 앞다리를 접고 뒷다리를 편다 — 웅크린 실루엣이 뜬 느낌을 준다.
		target_l = AIR_TUCK
		target_r = AIR_TUCK * 0.45

	var k: float = minf(delta * 14.0, 1.0)
	_hip_l.rotation.x = lerpf(_hip_l.rotation.x, target_l, k)
	_hip_r.rotation.x = lerpf(_hip_r.rotation.x, target_r, k)


## 팔 — 왼팔은 걷기에 맞춰 반대로 흔들고, 오른팔(마법봉)은 시전 모션을 한다.
## 사용자 요구: "스킬을 날릴 때 팔을 위로 올렸다가 내리는 모션"
func _animate_arms(delta: float) -> void:
	var k: float = minf(delta * 14.0, 1.0)

	if _shoulder_l != null:
		var swing: float = 0.0
		if is_on_floor():
			var speed := Vector2(velocity.x, velocity.z).length()
			# 왼팔은 오른다리와 같은 쪽으로 — 사람이 그렇게 걷는다.
			swing = -sin(_step_phase) * STEP_SWING * 0.55 * clampf(speed / move_speed, 0.0, 1.0)
		else:
			swing = -0.5
		_shoulder_l.rotation.x = lerpf(_shoulder_l.rotation.x, swing, k)

	if _wand_arm == null:
		return
	if _cast_anim > 0.0:
		_wand_arm.rotation.x = _cast_swing(1.0 - _cast_anim)
	else:
		# 시전이 끝나면 걷기에 맞춰 살짝만 흔든다. 마법봉을 든 팔이라 크게 안 흔든다.
		var idle: float = 0.0
		if is_on_floor():
			var speed := Vector2(velocity.x, velocity.z).length()
			idle = sin(_step_phase) * STEP_SWING * 0.22 * clampf(speed / move_speed, 0.0, 1.0)
		_wand_arm.rotation.x = lerpf(_wand_arm.rotation.x, idle, k)


## 시전 한 동작의 각도 곡선. t 는 0(시작) → 1(끝).
## 0~55% 올린다 → 잠깐 멈춘다 → 78~100% 내리친다(반대로 살짝 넘어갔다 돌아온다).
## 멈추는 구간이 있어야 "올렸다"가 눈에 읽힌다. 쭉 이어 돌리면 그냥 팔 젓기로 보인다.
func _cast_swing(t: float) -> float:
	if t < 0.55:
		var u: float = t / 0.55
		return CAST_LIFT * (1.0 - pow(1.0 - u, 3.0))   # 빠르게 올라갔다 천천히 멈춤
	if t < 0.78:
		return CAST_LIFT                                # 정지 — 힘을 모으는 순간
	var v: float = (t - 0.78) / 0.22
	return lerpf(CAST_LIFT, CAST_STRIKE, v * v)         # 가속하며 내리침


func _move(delta: float) -> void:
	# 방향키 → 화면 기준 이동. 카메라가 고정각이라 이 기준은 절대 안 바뀐다.
	# 조준도 같은 방향을 쓴다(`aim_direction()`) — 방향키가 곧 조준이다.
	var dir := _input_direction()

	# 대쉬는 이동 규칙을 통째로 덮어쓴다. 가감속을 태우면 "확" 나가는 맛이 죽는다.
	if _tick_dash(delta, dir):
		return

	# 수평 속도만 가감속한다. 수직(중력/점프)은 따로 둔다.
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if dir != Vector3.ZERO:
		flat = flat.move_toward(dir * move_speed, accel * delta)
	else:
		flat = flat.move_toward(Vector3.ZERO, friction * delta)
	velocity.x = flat.x
	velocity.z = flat.z

	# 중력 + 점프 (땅에서 1단, 공중에서 한 번 더)
	if is_on_floor():
		_double_ready = true
		if Input.is_action_just_pressed("jump"):
			velocity.y = sqrt(2.0 * gravity * jump_height)
			_double_ready = true   # 뜨자마자 2단을 쓸 수 있어야 급회피가 된다
	else:
		velocity.y -= gravity * delta
		if _double_ready and Input.is_action_just_pressed("jump"):
			_double_ready = false
			# 떨어지는 중이었어도 확실히 뜨도록 **속도를 덮어쓴다**(더하지 않는다).
			# 안 그러면 낙하 속도가 클수록 2단이 안 먹혀서 정작 필요할 때 안 뜬다.
			velocity.y = sqrt(2.0 * gravity * double_jump_height)
			_flip_left = flip_time

	move_and_slide()
	_face(dir, delta)
	_tick_flip(delta)
	_tick_arrow()


## 조준 화살표를 켜고 끈다.
## 아트가 `$Body/AimArrow` 를 **Body 밑에** 달아줬다 — 그래서 방향을 코드로 돌릴 필요가 없다.
## `_face()` 가 Body 를 돌리면 화살표도 같이 돈다.
##
## 언제 보이나: **방향키를 누르고 있을 때만.** 가만히 서 있을 때도 띄우면 화면이 지저분하고,
## 어차피 그때는 몸이 보는 쪽이 자명하다.
## 덤블링 중에는 끈다 — 몸이 통째로 돌아서 화살표가 하늘을 가리킨다.
func _tick_arrow() -> void:
	if _arrow == null:
		return
	_arrow.visible = _flip_left <= 0.0 and _input_direction().length_squared() > 0.0


## 대쉬. true 를 돌려주면 이번 프레임 이동은 대쉬가 책임진다.
##
## 방향은 **방향키가 있으면 그쪽, 없으면 보는 쪽**이다.
## 뒤로 빼는 게 회피의 절반이라 「보는 쪽으로만」은 회피 수단으로 못 쓴다.
##
## 중력은 그대로 두되 **아래로 떨어지지는 않게** 잡는다 —
## 공중 대쉬가 낙하에 먹혀버리면 정작 피할 때 안 듣는다(2단 점프와 같은 이유).
func _tick_dash(delta: float, input_dir: Vector3) -> bool:
	if _dash_cool > 0.0:
		_dash_cool = maxf(_dash_cool - delta, 0.0)

	if _dash_left > 0.0:
		_dash_left = maxf(_dash_left - delta, 0.0)
		velocity.x = _dash_dir.x * dash_speed
		velocity.z = _dash_dir.z * dash_speed
		velocity.y = maxf(velocity.y, 0.0)   # 대쉬 중에는 가라앉지 않는다
		move_and_slide()
		_face(_dash_dir, delta)
		_tick_flip(delta)
		return true

	if _dash_cool <= 0.0 and Input.is_action_just_pressed("dash"):
		var d := input_dir if input_dir.length_squared() > 0.0 else aim_direction()
		_dash_dir = d.normalized()
		_dash_left = dash_time
		_dash_cool = dash_cooldown
		Sfx.play("dash", 1.0, -4.0)
		return true

	return false


## 대쉬 쿨타임 — HUD 가 QWER 옆 칸에 그린다.
func dash_cooldown_left() -> float:
	return _dash_cool


func dash_cooldown_total() -> float:
	return dash_cooldown


## 지금 대쉬 중인가. 연출·무적 판정이 붙으면 여기를 본다.
func is_dashing() -> bool:
	return _dash_left > 0.0


## 2단 점프를 쓰면 몸이 앞으로 한 바퀴 돈다.
## 연출이면서 표시이기도 하다 — 2단을 이미 썼는지 눈으로 알 수 있다.
## 땅에 닿으면 남은 회전을 버리고 바로 똑바로 선다(착지가 어정쩡해 보이면 안 된다).
func _tick_flip(delta: float) -> void:
	if _flip_left <= 0.0:
		if not is_equal_approx(_body.rotation.x, 0.0):
			_body.rotation.x = 0.0
		return
	if is_on_floor():
		_flip_left = 0.0
		_body.rotation.x = 0.0
		return
	_flip_left = maxf(_flip_left - delta, 0.0)
	# 남은 시간을 각도로 환산한다. 0 이 되면 정확히 한 바퀴 끝난 자세다.
	var done: float = 1.0 - (_flip_left / flip_time)
	_body.rotation.x = -TAU * done


## 캐릭터는 자기가 가는 방향을 본다.
## Godot 에서 앞은 -Z 다. Player.tscn 의 얼굴·마법봉도 -Z 쪽에 붙어 있으니
## 몸의 -Z 축을 진행 방향에 맞춘다. (+Z 로 맞추면 뒤를 보고 달린다)
func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() <= 0.0:
		return
	var target := atan2(-dir.x, -dir.z)
	_body.rotation.y = lerp_angle(_body.rotation.y, target, turn_speed * delta)


## 스킬이 날아갈 방향.
##
## 2026-08-02 사용자 확정: **"스킬을 쓸 때는 움직임 키패드로 정할 수 있는 거지"**
## → **방향키가 곧 조준이다.** 누르고 있는 방향으로 **즉시** 나간다.
##
## 몸이 보는 방향을 쓰면 안 되는 이유: `_face()` 가 `turn_speed` 로 **부드럽게 돌기 때문에**
## 방향을 꺾은 직후에 쏘면 몸이 아직 안 돌아서 **엉뚱한 데로 나간다.**
## 조준은 늦으면 안 된다 — 누른 대로 나가야 내가 맞힌 게 된다.
##
## 방향키를 안 누르고 있으면(제자리) 몸이 보는 쪽으로 나간다.
func aim_direction() -> Vector3:
	var keyed := _input_direction()
	if keyed.length_squared() > 0.0:
		return keyed

	var forward := -_body.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0:
		return Vector3.FORWARD
	return forward.normalized()


## 지금 누르고 있는 방향키 → 화면 기준 방향. 아무것도 안 누르면 ZERO.
func _input_direction() -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := _pivot.global_transform.basis
	var dir := (basis.x * input_dir.x + basis.z * input_dir.y)
	dir.y = 0.0
	if dir.length_squared() <= 0.0:
		return Vector3.ZERO
	return dir.normalized()


# ── 스킬 발사 ────────────────────────────────────────────────
## 순서: Q 누름 → 발동 시간만큼 기다림 → 투사체 발사 → 쿨타임.
## 발동 시간·쿨타임은 Balance 가 정한 값이다. 여기서 임의로 줄이지 않는다.
##
## 발동 중에 느려지게 하지 않는다 — 기획서가 "조준 중 감속"을 넣지 말라고 못박았다.
## 피하는 수단은 이동과 점프뿐이고, 그건 발동 중에도 그대로 살아 있어야 한다.
func _tick_skill(delta: float) -> void:
	# 쿨타임은 슬롯마다 따로 돈다. 하나 쓰는 동안 나머지도 계속 식는다.
	for slot in _cooldowns:
		if _cooldowns[slot] > 0.0:
			_cooldowns[slot] = maxf(_cooldowns[slot] - delta, 0.0)

	# 발동 중에는 다른 스킬을 못 쓴다. 마법봉은 하나뿐이다.
	if not _casting_slot.is_empty():
		_cast_left -= delta
		if _cast_left <= 0.0:
			var slot := _casting_slot
			_casting_slot = ""
			_shoot(slot)
		return

	for slot in SLOT_ACTIONS:
		if float(_cooldowns.get(slot, 0.0)) > 0.0:
			continue
		if not Input.is_action_just_pressed(String(SLOT_ACTIONS[slot])):
			continue
		_casting_slot = slot
		# NaN 이 들어오면 어떤 비교도 false 라 발동이 영영 안 풀리고
		# 스킬이 완전히 잠긴다. 망가진 값은 여기서 걸러낸다.
		_cast_left = _safe_time(_derived(slot).get("cast_time", 0.3), 0.3)
		# 팔 올렸다 내리치는 모션. **발동 시간에 맞춰 늘였다 줄인다** —
		# 발동이 0.12초인 싼 스킬과 1.1초인 비싼 스킬이 같은 속도로 움직이면
		# 모션이 수치와 따로 논다. 내리치는 순간이 곧 발사 순간이어야 한다.
		_cast_anim_time = maxf(_cast_left, 0.18)
		_cast_anim = 1.0
		break


## 그 슬롯의 Balance 계산 결과. 슬롯이 아직 안 읽혔으면 빈 Dictionary.
func _derived(slot: String) -> Dictionary:
	var entry: Dictionary = _slots.get(slot, {})
	return entry.get("derived", {})


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
func _shoot(slot: String) -> void:
	var entry: Dictionary = _slots.get(slot, {})
	var skill: Dictionary = entry.get("derived", {})
	if skill.is_empty():
		return

	var dir := aim_direction()
	var box: Dictionary = skill.get("hitbox", {})
	var kind := String(box.get("kind", "sphere"))
	# 탄 수를 명시해서 넘긴다. 태그 기본값(÷3·÷5)에 기대면, 나중에 그림에서 탄 수를
	# 뽑는 미세 파라미터가 붙었을 때 총 데미지가 조용히 어긋난다.
	var dmg: float = Balance.damage_per_hit(
		float(entry["damage"]), String(entry["tag"]), int(box.get("pellets", 0)))

	match kind:
		"scatter":
			# 산탄 다발 — 작은 탄이 퍼진다.
			# 퍼짐각을 상수가 아니라 `angle_deg` 에서 읽는다. 그림에 따라 달라지기 때문이다.
			_spawn_spread(slot, dir, int(box.get("pellets", 5)),
				float(box.get("angle_deg", Balance.SCATTER_SPREAD_DEG)),
				float(box.get("pellet_radius", 0.3)), dmg)
		"cone":
			# 부채꼴 다단 히트 — 작은 탄을 부챗살로 뿌린다.
			# `angle_deg` 는 이제 실제 퍼짐각과 같은 값이다(기획 담당이 하나로 묶었다).
			# 예전엔 판정각 90° 를 그대로 퍼짐각으로 써서 10m 앞 바깥 탄이
			# 10m 옆으로 날아갔다 — 사실상 안 맞는 태그였다.
			_spawn_spread(slot, dir, int(box.get("pellets", Balance.CONE_PELLETS)),
				float(box.get("angle_deg", Balance.CONE_SPREAD_DEG)),
				float(box.get("pellet_radius", 0.3)), dmg)
		_:
			# 둥긂(구) · 길쭉함(캡슐) — 한 발
			_spawn(slot, dir, box, dmg)

	_cooldowns[slot] = _safe_time(skill.get("cooldown", 3.0), 3.0)


## 부챗살로 count 발. 가운데를 기준으로 spread_deg 안에 고르게 편다.
func _spawn_spread(slot: String, dir: Vector3, count: int, spread_deg: float,
		pellet_radius: float, dmg: float) -> void:
	count = maxi(count, 1)
	var shape := {"kind": "sphere", "radius": pellet_radius}
	for i in count:
		# count 가 1이면 정가운데, 아니면 -spread/2 ~ +spread/2 로 편다
		var t: float = 0.5 if count == 1 else float(i) / float(count - 1)
		var angle := deg_to_rad(lerpf(-spread_deg * 0.5, spread_deg * 0.5, t))
		_spawn(slot, dir.rotated(Vector3.UP, angle), shape, dmg)


## 투사체 한 발. 그 슬롯의 그림·색·수치를 실어 보낸다.
func _spawn(slot: String, dir: Vector3, shape: Dictionary, dmg: float) -> void:
	# 플레이어 밑에 달면 플레이어가 움직일 때 투사체가 같이 끌려간다.
	# 그래서 형제로 붙인다. current_scene 은 씬을 코드로 올렸을 때 비어 있어 쓰지 않는다.
	var world := get_parent()
	if world == null:
		return

	var entry: Dictionary = _slots.get(slot, {})
	var skill: Dictionary = entry.get("derived", {})

	var shot := PROJECTILE.new()
	shot.configure(dir, {
		"speed": skill.get("speed", 20.0),
		"distance": skill.get("distance", 12.0),
		"shape": shape,
		"damage": dmg,
		"color": entry.get("color", Color.WHITE),
		"mask": entry.get("mask", PackedByteArray()),
		"shooter": self,
	})
	world.add_child(shot)
	shot.global_position = _spawn_point(shape)
	_muzzle_flash(entry.get("color", Color.WHITE))


## 총구 섬광. 발사 순간이 화면에 보여야 "쐈다" 가 된다.
## 종전엔 마법봉 끝 발광이 **상시로 켜져 있어서** 쏘는 순간이 전혀 티가 안 났다.
##
## 아트가 `Body/Wand/Muzzle` 밑에 `Flash/Halo` · `Flash/Core` · `FireLight` 를
## **잠든 상태로 심어 놨다.** 개발은 켜고 끄기만 한다.
## 역할이 갈려 있다 — 헤일로는 **혼합**(색 담당), 코어는 **가산**(밝기 담당).
## 가산은 한가운데가 무슨 색이든 흰색으로 타므로 **코어를 훨씬 짧게** 껐다.
func _muzzle_flash(col: Color) -> void:
	if _muzzle == null:
		return

	var halo := _muzzle.get_node_or_null("Flash/Halo") as MeshInstance3D
	var core := _muzzle.get_node_or_null("Flash/Core") as MeshInstance3D
	var lamp := _muzzle.get_node_or_null("FireLight") as OmniLight3D

	_pop_flash(halo, col, 0.14, 1.0)    # 색 헤일로 — 길게
	_pop_flash(core, col, 0.03, 0.55)   # 흰 코어 — 아주 짧게
	if lamp != null:
		lamp.light_color = col
		var lt := lamp.create_tween()
		lt.tween_property(lamp, "light_energy", 2.4, 0.02)
		lt.tween_property(lamp, "light_energy", 0.0, 0.12)

	Sfx.play("fire", clampf(1.3 - skill_range_hint() * 0.006, 0.7, 1.4))


## 섬광 조각 하나를 확 켰다 끈다. 잠들어 있던 노드를 잠깐 깨우는 방식이다.
func _pop_flash(node: MeshInstance3D, col: Color, life: float, size: float) -> void:
	if node == null:
		return
	# 재질이 없을 수도 있으니(노드가 잠들어 있으면 `get_active_material` 이 null 을 준다)
	# 없으면 만들어 쓴다. 없다고 그냥 넘어가면 색이 안 실려 흰 판때기가 뜬다.
	# ⚠ 메시가 없으면 `get_active_material` 자체가 엔진 경고를 뱉으므로 먼저 거른다.
	var m: StandardMaterial3D
	var mat: Material = null
	if node.mesh != null:
		mat = node.get_active_material(0)
	if mat is StandardMaterial3D:
		m = (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(col.r, col.g, col.b, 1.0)
	node.material_override = m
	var tw := node.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	node.visible = true
	node.scale = Vector3.ONE * size * 0.5
	var st := node.create_tween()
	st.tween_property(node, "scale", Vector3.ONE * size * 1.6, life) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	st.tween_callback(func() -> void: node.visible = false)


## 소리에 스킬 크기를 싣기 위한 힌트값(범위 pt). 큰 스킬일수록 낮게 운다.
func skill_range_hint() -> float:
	var e: Dictionary = _slots.get(_casting_slot if not _casting_slot.is_empty() else "Q", {})
	return float(e.get("range_pt", 20.0))


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


## 그 슬롯의 쿨타임이 얼마나 남았는지 (0.0 = 지금 쏠 수 있음). HUD 가 붙으면 이걸 쓴다.
func cooldown_left(slot: String = "Q") -> float:
	return float(_cooldowns.get(slot, 0.0))


## 그 슬롯에 든 스킬 이름. HUD·디버그용.
func slot_name(slot: String) -> String:
	return String((_slots.get(slot, {}) as Dictionary).get("name", ""))


## 그 슬롯의 **전체** 쿨타임(초). HUD 가 남은 비율을 그리려면 분모가 필요하다.
func cooldown_total(slot: String) -> float:
	return float(_derived(slot).get("cooldown", 0.0))


## 지금 발동 중인 슬롯("" = 없음). HUD 가 발동 표시를 띄우는 데 쓴다.
func casting_slot() -> String:
	return _casting_slot
