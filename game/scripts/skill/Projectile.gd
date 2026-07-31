extends Area3D
## 스킬 투사체 — 로드맵 3b. **유저가 그린 그림이 그대로 날아간다.**
##
## 이 파일은 **세기를 정하지 않는다.** 속도·사거리·판정 크기·데미지는 전부
## 쏘는 쪽이 Balance.derive() 로 뽑아서 넘겨준 값을 그대로 쓴다.
## (기획서 대원칙: 그림은 모양을, 수치는 세기를 정한다. 코드가 임의로 세게 만들지 않는다)
##
## 겉모습 = 유저가 그린 32×32 마스크를 그대로 스프라이트로 띄운다(기획서 35행).
## 판정  = 그림 픽셀 모양이 아니라, 형태 태그가 고른 프리셋이다.
##         픽셀 그대로를 판정으로 쓰는 안(완전 B안)은 기획서가 채택하지 않았다 —
##         얇은 선 하나로 맵을 관통하는 악용이 열리기 때문이다.
##
## 부채꼴·산탄은 이 투사체를 여러 발 뿌려서 만든다. 나누는 건 쏘는 쪽(Player)의 일이고,
## 여기는 "한 발"만 안다.
##
## 노드를 .tscn 이 아니라 코드로 짓는다. 판정 크기도 겉모습도 매번 달라져서
## .tscn 으로 고정할 수 없다. SkillEditor.gd 도 같은 이유로 코드로 짓는다.

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
var damage: float = 10.0
var color: Color = Color(1.0, 0.45, 0.15)

## Balance.hitbox_for() 가 준 모양. kind = sphere | capsule
var shape_spec: Dictionary = {"kind": "sphere", "radius": 0.5}
## 유저가 그린 32×32 마스크. 비어 있으면 밋밋한 구로 그린다.
var mask: PackedByteArray = PackedByteArray()

var _dir: Vector3 = Vector3.FORWARD
var _travelled: float = 0.0
var _spent: bool = false


## add_child 하기 **전에** 부른다. 노드를 만지지 않으니 트리 밖에서도 안전하다.
## spec 키: speed, distance, shape, damage, color, mask
func configure(dir: Vector3, spec: Dictionary) -> void:
	_dir = dir.normalized()
	speed = float(spec.get("speed", speed))
	max_distance = float(spec.get("distance", max_distance))
	damage = float(spec.get("damage", damage))
	color = spec.get("color", color)
	shape_spec = spec.get("shape", shape_spec)
	mask = spec.get("mask", mask)


func _ready() -> void:
	collision_layer = LAYER_PROJECTILE
	collision_mask = MASK_WORLD_AND_ENEMY
	monitoring = true
	# monitorable 은 켜둔 채로 둔다(기본값).
	# 이 투사체를 감지할 다른 Area 가 아직 없어서 꺼도 될 것 같지만, 끄면
	# Godot 4.7 브로드페이즈가 이 Area 를 정적으로 취급해 StaticBody3D 와 아예
	# 짝지어주지 않는다 → 허수아비·벽에 영영 안 맞는다. 실제로 그렇게 한 번 깨졌다.
	monitorable = true

	# 캡슐을 진행 방향으로 눕히려면 몸 자체가 진행 방향을 봐야 한다.
	if _dir.length_squared() > 0.0:
		basis = Basis.looking_at(_dir)

	_build_shape()
	_build_look()
	body_entered.connect(_on_body_entered)


func _radius() -> float:
	return float(shape_spec.get("radius", 0.5))


func _build_shape() -> void:
	var col := CollisionShape3D.new()
	if String(shape_spec.get("kind", "sphere")) == "capsule":
		var cap := CapsuleShape3D.new()
		cap.radius = _radius()
		# Godot 캡슐의 height 는 반구까지 포함한 전체 길이다.
		cap.height = maxf(float(shape_spec.get("length", 1.0)), cap.radius * 2.0)
		col.shape = cap
		# 캡슐은 Y축으로 서 있다. -90° 돌려 진행 방향(-Z)으로 눕힌다.
		col.rotation.x = -PI * 0.5
		# 원점을 캡슐 가운데가 아니라 **뒤끝**에 둔다.
		# 가운데에 두면 창의 절반이 총구 뒤로 삐져나와 등 뒤 5m 를 때린다(QA 실측).
		col.position.z = -cap.height * 0.5
	else:
		var sph := SphereShape3D.new()
		sph.radius = _radius()
		col.shape = sph
	add_child(col)


## 유저가 그린 그림을 그대로 띄운다. 이게 이 게임의 정체성이다.
func _build_look() -> void:
	var drawn := _draw_sprite()
	if drawn == null:
		_fallback_ball()

	var lamp := OmniLight3D.new()
	lamp.light_color = color
	lamp.light_energy = 1.6
	lamp.omni_range = maxf(_radius() * 5.0, 3.0)
	add_child(lamp)


## 마스크 → 스프라이트. 그린 게 없으면 null.
func _draw_sprite() -> Sprite3D:
	var tex := _mask_texture()
	if tex == null:
		return null

	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# 그림이 **판정 크기만 하게** 보여야 한다.
	# 32×32 판 전체를 기준으로 잡으면, 한쪽 구석에만 그린 작은 그림이
	# 판정보다 훨씬 작게 보인다(1픽셀만 그리면 32배 차이). 그래서 그린 부분
	# (바운딩박스)만 잘라내서, 그 잘라낸 조각이 판정 크기를 채우게 한다.
	var box := _drawn_box()
	var side: float = maxf(box.size.x, box.size.y)
	if side <= 0.0:
		return null
	sprite.region_enabled = true
	sprite.region_rect = box

	var span: float = _radius() * 2.0
	if String(shape_spec.get("kind", "sphere")) == "capsule":
		span = maxf(float(shape_spec.get("length", span)), span)
	sprite.pixel_size = span / side
	add_child(sprite)
	return sprite


## 칠한 픽셀만 감싸는 사각형. 아무것도 안 칠했으면 크기 0.
func _drawn_box() -> Rect2:
	var g := Balance.GRID
	var min_x := g
	var min_y := g
	var max_x := -1
	var max_y := -1
	for y in g:
		for x in g:
			if mask[y * g + x] == 0:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2(0, 0, 0, 0)
	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## 32×32 마스크를 스킬 색으로 칠한 텍스처로. 빈 그림이면 null.
func _mask_texture() -> ImageTexture:
	var g := Balance.GRID
	if mask.size() < g * g:
		return null

	var img := Image.create(g, g, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var filled := 0
	for y in g:
		for x in g:
			if mask[y * g + x] != 0:
				img.set_pixel(x, y, color)
				filled += 1
	if filled == 0:
		return null
	return ImageTexture.create_from_image(img)


## 그린 게 없을 때만 쓰는 밋밋한 구. 유저가 스킬을 아직 안 그린 경우다.
func _fallback_ball() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = _radius()
	mesh.height = _radius() * 2.0

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

	if body.has_method("take_damage"):
		# 이미 쓰러진 대상은 탄을 먹지 않고 지나가게 한다.
		# 안 그러면 시체가 방패가 돼서 뒤에 선 적이 안 맞는다(QA 실측).
		if body.take_damage(damage) == false:
			return
		_finish(body)
		return

	# 벽·바닥. 태어나는 순간 겹쳐 있는 건 무시한다 —
	# 판정 반경이 총구 높이보다 크면 스폰 즉시 바닥에 자폭해버린다.
	if _travelled <= 0.0:
		return
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
