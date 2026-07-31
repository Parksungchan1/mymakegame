extends Area3D
## 스킬 투사체 — 로드맵 2단계 "고정 스킬 1개 발사".
##
## 이 파일은 **세기를 정하지 않는다.** 속도·사거리·판정 크기·데미지는 전부
## 쏘는 쪽이 Balance.derive() 로 뽑아서 넘겨준 값을 그대로 쓴다.
## (기획서 대원칙: 그림은 모양을, 수치는 세기를 정한다. 코드가 임의로 세게 만들지 않는다)
##
## 2단계에서 실제로 나가는 건 태그 **둥긂**(구체) 하나뿐이다.
## 길쭉함(캡슐)·뾰족함(부채꼴)·흩어짐(산탄) 히트박스는 로드맵 3단계에서
## 스킬 에디터가 붙을 때 함께 구현한다. 여기서 미리 만들지 않는다.
##
## 노드를 .tscn 이 아니라 코드로 짓는다. 판정 반경이 밸런스 계산 결과라
## 매번 달라지고, SkillEditor.gd 도 같은 이유로 코드로 짓고 있다.

## 몸에 맞았을 때. 맞은 대상이 인자로 온다(벽이면 null).
signal hit(target: Node3D)

## 판정 레이어 — project.godot 의 [layer_names] 와 맞춘다.
## 1=world · 2=player · 3=enemy · 4=projectile
const LAYER_PROJECTILE := 1 << 3
const MASK_WORLD_AND_ENEMY := (1 << 0) | (1 << 2)

## 맞은 자리에 남기는 잔상이 사라지기까지(초)
const FLASH_TIME := 0.12

var speed: float = 20.0
var max_distance: float = 12.0
var radius: float = 0.5
var damage: float = 10.0
var color: Color = Color(1.0, 0.45, 0.15)

var _dir: Vector3 = Vector3.FORWARD
var _travelled: float = 0.0
var _spent: bool = false


## add_child 하기 **전에** 부른다. 노드를 만지지 않으니 트리 밖에서도 안전하다.
## derived 는 Balance.derive() 가 돌려준 Dictionary 그대로.
func configure(dir: Vector3, derived: Dictionary, dmg: float, col: Color) -> void:
	_dir = dir.normalized()
	speed = float(derived.get("speed", speed))
	max_distance = float(derived.get("distance", max_distance))
	damage = dmg
	color = col

	var box: Dictionary = derived.get("hitbox", {})
	radius = float(box.get("radius", radius))


func _ready() -> void:
	collision_layer = LAYER_PROJECTILE
	collision_mask = MASK_WORLD_AND_ENEMY
	monitoring = true
	# monitorable 은 켜둔 채로 둔다(기본값).
	# 이 투사체를 감지할 다른 Area 가 아직 없어서 꺼도 될 것 같지만, 끄면
	# Godot 4.7 브로드페이즈가 이 Area 를 정적으로 취급해 StaticBody3D 와 아예
	# 짝지어주지 않는다 → 허수아비·벽에 영영 안 맞는다. 실제로 그렇게 한 번 깨졌다.
	monitorable = true

	_build_shape()
	_build_look()
	body_entered.connect(_on_body_entered)


func _build_shape() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var col := CollisionShape3D.new()
	col.shape = sphere
	add_child(col)


## 마법봉에서 나간 마법처럼 보이게 — 빛나는 구 + 은은한 광원.
func _build_look() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	add_child(view)

	var lamp := OmniLight3D.new()
	lamp.light_color = color
	lamp.light_energy = 1.6
	lamp.omni_range = maxf(radius * 5.0, 3.0)
	add_child(lamp)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var step := speed * delta
	global_position += _dir * step
	_travelled += step
	if _travelled >= max_distance:
		_finish(null)


func _on_body_entered(body: Node3D) -> void:
	if _spent:
		return
	# 데미지를 받을 수 있는 대상이면 넣는다. 벽·바닥이면 그냥 사라진다.
	if body.has_method("take_damage"):
		body.take_damage(damage)
		_finish(body)
	else:
		_finish(null)


## 판정을 끄고 잠깐 남았다가 사라진다. 맞은 순간이 눈에 보이게 하려는 것.
func _finish(target: Node3D) -> void:
	if _spent:
		return
	_spent = true
	hit.emit(target)
	set_deferred("monitoring", false)
	set_physics_process(false)
	await get_tree().create_timer(FLASH_TIME).timeout
	queue_free()
