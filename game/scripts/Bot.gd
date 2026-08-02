extends CharacterBody3D
## 봇 — 로드맵 4단계의 나머지 절반. **드디어 상대가 생긴다.**
##
## 2026-08-02 사용자 요구: "봇을 만들어서 한번 해볼 수 있도록 만들어줘"
## QA 6차가 「이건 게임이 아니라 사격장이다」라고 판정한 그 자리다.
## 봇이 생기면 다섯 세션째 막혀 있던 것들이 한꺼번에 풀린다 —
## 더블 점프가 실제로 스킬을 피하는지, 길쭉함과 둥긂이 구분되는지, 다중 표적 위력이 어떤지.
##
## ## 설계 원칙
## **플레이어와 같은 규칙으로 논다.** 같은 `Balance` 수치, 같은 `Projectile`,
## 같은 쿨타임·발동시간을 쓴다. 봇만 아는 지름길을 주지 않는다 —
## 그러면 밸런스를 봇으로 검증할 수 없게 된다.
##
## **완벽하게 조준하지 않는다.** 완벽한 봇은 재미가 없고 밸런스도 못 잰다.
## 사람이 그렇듯 조금 빗나가고, 반응에 시간이 걸리고, 가끔 가만히 있는다.

signal health_changed(hp: float, max_hp: float)
signal died

const PROJECTILE := preload("res://scripts/skill/Projectile.gd")

# ── 체력 ──────────────────────────────────────────────────────
@export var max_hp: float = 100.0
@export var respawn_delay: float = 3.0

# ── 이동 ──────────────────────────────────────────────────────
@export var move_speed: float = 5.2      ## 플레이어(6.0)보다 살짝 느리다. 도망칠 수 있어야 한다
@export var accel: float = 40.0
@export var friction: float = 50.0
@export var gravity: float = 22.0
@export var turn_speed: float = 10.0

## 이 거리를 유지하려 한다. 너무 붙으면 물러나고 멀면 다가온다.
@export var keep_distance: float = 11.0
@export var distance_slack: float = 3.5

# ── 사격 ──────────────────────────────────────────────────────
## 조준이 얼마나 빗나가는가(도). 0 이면 백발백중이라 재미가 없다.
##
## 🔑 첫 실측에서 **봇 2마리가 6.6초 만에 플레이어를 죽였다.**
## 사람은 화면을 보고 판단하고 손을 움직여야 하는데 봇은 즉시 조준한다.
## 그래서 오차를 키우고 반응을 늦췄다 — **처음 만나는 상대가 곧바로 죽이면 배울 기회가 없다.**
## 강하게 하고 싶으면 이 세 값만 줄이면 된다. 그게 난이도 손잡이다.
@export var aim_error_deg: float = 16.0
## 쏠 마음을 먹기까지 걸리는 시간(초). 사람의 반응 시간에 해당한다.
@export var reaction_min: float = 0.9
@export var reaction_max: float = 2.2
## 쏘는 스킬. 플레이어의 QWER 과 같은 슬롯을 쓴다.
@export var slots: PackedStringArray = ["Q", "W", "E", "R"]

@onready var _body: Node3D = get_node_or_null("Body")
@onready var _muzzle: Node3D = get_node_or_null("Body/Wand/Muzzle")

var hp: float = 100.0
var _dead: bool = false
var _target: Node3D
var _cooldowns: Dictionary = {}
var _think_wait: float = 0.0
var _casting_slot: String = ""
var _cast_left: float = 0.0
## 옆으로 도는 방향(1 또는 -1). 가끔 바꿔서 예측이 안 되게 한다.
var _strafe: float = 1.0
var _strafe_wait: float = 0.0
## 부활 지점. 함수 `_spawn()` 과 이름이 겹치면 안 된다.
var _home: Vector3


func _ready() -> void:
	# world(1) 은 안 켠다 — 봇끼리·플레이어와 밀치지 않게. enemy(3) 로만 존재한다.
	collision_layer = 1 << 2
	collision_mask = 1          # 벽·바닥에만 부딪힌다
	hp = max_hp
	_home = global_position
	for s in slots:
		_cooldowns[s] = 0.0
	_find_target()
	health_changed.emit(hp, max_hp)


func _find_target() -> void:
	var world := get_parent()
	while world != null and world.get_node_or_null("Player") == null:
		world = world.get_parent()
	if world != null:
		_target = world.get_node_or_null("Player")


# ─────────────────────────────────────────────────────────────
# 피격
# ─────────────────────────────────────────────────────────────

## 투사체가 부르는 창구. `Player`·`Dummy` 와 같은 계약이다.
func take_damage(amount: float) -> bool:
	if _dead:
		return false
	hp = maxf(hp - amount, 0.0)
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()
	return true


func is_dead() -> bool:
	return _dead


func _die() -> void:
	_dead = true
	died.emit()
	if _body != null:
		_body.rotation.z = deg_to_rad(80.0)
	# 쓰러뜨린 사람에게 「쿵」을 알린다. 허수아비와 같은 방식이다.
	if _target != null and _target.has_method("shake_kill"):
		_target.shake_kill()
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


func _respawn() -> void:
	if _body != null:
		_body.rotation.z = 0.0
	global_position = _home
	velocity = Vector3.ZERO
	hp = max_hp
	_dead = false
	_casting_slot = ""
	for s in slots:
		_cooldowns[s] = 0.0
	health_changed.emit(hp, max_hp)


# ─────────────────────────────────────────────────────────────
# 생각하고 움직이고 쏜다
# ─────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _dead:
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if _target == null or (_target.has_method("is_dead") and _target.is_dead()):
		_idle(delta)
		return

	_tick_cooldowns(delta)
	_move_toward_range(delta)
	_tick_fire(delta)


func _idle(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, friction * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()


func _tick_cooldowns(delta: float) -> void:
	for s in _cooldowns:
		if _cooldowns[s] > 0.0:
			_cooldowns[s] = maxf(_cooldowns[s] - delta, 0.0)


## 적정 거리를 유지하며 옆으로 돈다.
## 정면으로만 다가오면 맞히기 너무 쉽고, 도망만 다니면 답답하다.
func _move_toward_range(delta: float) -> void:
	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist < 0.01:
		return
	var forward := to_target / dist

	# 옆으로 도는 방향을 가끔 바꾼다 — 예측 가능하면 봇이 아니라 과녁이다.
	_strafe_wait -= delta
	if _strafe_wait <= 0.0:
		_strafe_wait = randf_range(1.2, 2.8)
		_strafe = 1.0 if randf() < 0.5 else -1.0

	var side := Vector3(-forward.z, 0.0, forward.x) * _strafe
	var want := side * 0.7
	if dist > keep_distance + distance_slack:
		want += forward            # 너무 멀다 → 다가간다
	elif dist < keep_distance - distance_slack:
		want -= forward            # 너무 가깝다 → 물러난다
	if want.length_squared() > 0.0:
		want = want.normalized()

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if want != Vector3.ZERO:
		flat = flat.move_toward(want * move_speed, accel * delta)
	else:
		flat = flat.move_toward(Vector3.ZERO, friction * delta)
	velocity.x = flat.x
	velocity.z = flat.z

	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()
	_face(forward, delta)


## 몸은 늘 플레이어를 본다. Godot 의 앞은 -Z 다.
func _face(dir: Vector3, delta: float) -> void:
	if _body == null or dir.length_squared() <= 0.0:
		return
	var target := atan2(-dir.x, -dir.z)
	_body.rotation.y = lerp_angle(_body.rotation.y, target, turn_speed * delta)


## 발동 → 발사. 플레이어와 **같은 순서**를 밟는다.
func _tick_fire(delta: float) -> void:
	if not _casting_slot.is_empty():
		_cast_left -= delta
		if _cast_left <= 0.0:
			var s := _casting_slot
			_casting_slot = ""
			_shoot(s)
		return

	_think_wait -= delta
	if _think_wait > 0.0:
		return

	var ready_slots: Array = []
	for s in slots:
		if float(_cooldowns.get(s, 0.0)) <= 0.0 and not SkillDB.get_slot(s).is_empty():
			ready_slots.append(s)
	if ready_slots.is_empty():
		_think_wait = 0.25
		return

	var pick: String = String(ready_slots[randi() % ready_slots.size()])
	var d: Dictionary = _derived(pick)
	# 사거리 밖이면 안 쏜다. 허공에 쏘면 바보처럼 보인다.
	var dist: float = global_position.distance_to(_target.global_position)
	if dist > float(d.get("reach", d.get("distance", 12.0))):
		_think_wait = 0.3
		return

	_casting_slot = pick
	_cast_left = float(d.get("cast_time", 0.3))
	_think_wait = randf_range(reaction_min, reaction_max)


func _derived(slot: String) -> Dictionary:
	var s: Dictionary = SkillDB.get_slot(slot)
	if s.is_empty():
		return {}
	var m: Dictionary = Balance.analyze_mask(s["mask"])
	return Balance.derive(float(s["damage"]), float(s["range_pt"]),
		Balance.tag_from_metrics(m), m)


func _shoot(slot: String) -> void:
	var s: Dictionary = SkillDB.get_slot(slot)
	if s.is_empty():
		return
	var d: Dictionary = _derived(slot)
	if d.is_empty():
		return

	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.0:
		return
	var dir := to_target.normalized()
	# **일부러 빗나간다.** 백발백중이면 피하는 재미가 없고 밸런스도 못 잰다.
	dir = dir.rotated(Vector3.UP, deg_to_rad(randf_range(-aim_error_deg, aim_error_deg)))

	var box: Dictionary = d.get("hitbox", {})
	var tag := String(d.get("tag", Balance.TAG_ROUND))
	var dmg: float = Balance.damage_per_hit(
		float(s["damage"]), tag, int(box.get("pellets", 0)))

	match String(box.get("kind", "sphere")):
		"scatter", "cone":
			var count := int(box.get("pellets", 3))
			var spread := float(box.get("angle_deg", 20.0))
			var shape := {"kind": "sphere", "radius": float(box.get("pellet_radius", 0.3))}
			for i in count:
				var t: float = 0.5 if count == 1 else float(i) / float(count - 1)
				var a := deg_to_rad(lerpf(-spread * 0.5, spread * 0.5, t))
				_spawn(dir.rotated(Vector3.UP, a), shape, dmg, d, s)
		_:
			_spawn(dir, box, dmg, d, s)

	_cooldowns[slot] = float(d.get("cooldown", 3.0))


func _spawn(dir: Vector3, shape: Dictionary, dmg: float,
		d: Dictionary, s: Dictionary) -> void:
	var world := get_parent()
	if world == null:
		return
	var shot := PROJECTILE.new()
	shot.configure(dir, {
		"speed": d.get("speed", 20.0),
		"distance": d.get("distance", 12.0),
		"shape": shape,
		"damage": dmg,
		"color": s.get("color", Color.WHITE),
		"mask": s.get("mask", PackedByteArray()),
		"shooter": self,
	})
	world.add_child(shot)

	# 총구가 없으면 몸 앞에서 쏜다. 플레이어와 같은 이유로 바닥을 벗어나게 띄운다.
	var pos: Vector3 = _muzzle.global_position if _muzzle != null \
		else global_position + dir * 0.8 + Vector3(0, 1.0, 0)
	pos.y = maxf(pos.y, global_position.y + float(shape.get("radius", 0.5)) + 0.08)
	shot.global_position = pos
