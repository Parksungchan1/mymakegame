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

# ── 손맛 (2026-08-02) ─────────────────────────────────────────
## 사용자 지적: "스킬을 쏘는거나 뭔가 하는게 날라가는게 별로야"
## 종전엔 **그림 한 장이 등속으로 둥둥 떠갔다.** 쐈다는 것도, 맞혔다는 것도 화면에 안 보였다.
## 아래는 그걸 만드는 최소 장치다. 유저가 그린 그림은 **계속 읽혀야 하므로**
## 그림 자체를 가리지 않고 **주변**에 붙인다.

## 태어날 때 이만큼에서 시작해 제 크기로 커진다. "튀어나온" 느낌.
const BIRTH_SCALE := 0.45
const BIRTH_TIME := 0.07

## 꼬리(잔상) — 지나간 자리에 같은 그림을 흐리게 남긴다.
##
## 🔑 아트 결론: **스핀과 스트레치는 넣으면 안 된다.**
## 스트레치는 그림을 찌그러뜨리고 스핀은 유저가 그린 기호를 뒤집는다.
## **잔상만이 유일하게 가독성과 속도감이 같은 방향**이다 — 같은 그림을 여러 번 보여주니까.
## 그래서 회전·왜곡은 안 준다. 그림은 그림대로 두고 **과거를 남겨** 속도를 만든다.
##
## 간격을 시간이 아니라 **거리**로 잡는다. 그래야 느린 탄도 빠른 탄도 같은 밀도로 이어진다.
const TRAIL_SPACING := 0.65   ## 그림 크기의 몇 배마다 한 장 남기나
const TRAIL_GHOSTS := 4.0     ## 항상 이만큼이 화면에 남는다
const TRAIL_ALPHA := 0.45
const TRAIL_END_SCALE := 0.70

## 명중 순간 그림이 커지며 사라지는 시간
const BURST_TIME := 0.20
const BURST_SCALE := 3.4

## 명중 폭발(파편·링·빛)
const IMPACT := preload("res://scripts/skill/Impact.gd")

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

## 손맛용 상태
var _sprite: Sprite3D
var _lamp: OmniLight3D
var _age: float = 0.0
var _trail_wait: float = 0.0
var _tex: ImageTexture
var _sprite_size: float = 1.0


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

	_lamp = OmniLight3D.new()
	_lamp.light_color = color
	_lamp.light_energy = 1.6
	_lamp.omni_range = maxf(_radius() * 5.0, 3.0)
	add_child(_lamp)


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

	# 꼬리를 만들 때 이 텍스처와 크기를 그대로 복제한다.
	_tex = tex
	_sprite_size = span
	_sprite = sprite
	# 태어날 때 작게 시작한다 — "튀어나온" 느낌을 만든다.
	sprite.scale = Vector3.ONE * BIRTH_SCALE
	return sprite


## 지나간 자리에 흐려지는 복제를 남긴다.
## 그림을 가리지 않으면서 **어디서 어디로 갔는지**를 화면에 남기는 게 목적이다.
func _drop_trail(life: float) -> void:
	if _sprite == null or _tex == null:
		return
	var ghost := Sprite3D.new()
	ghost.texture = _tex
	ghost.region_enabled = _sprite.region_enabled
	ghost.region_rect = _sprite.region_rect
	ghost.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost.shaded = false
	ghost.transparent = true
	ghost.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ghost.pixel_size = _sprite.pixel_size
	ghost.scale = _sprite.scale
	ghost.modulate = Color(1, 1, 1, TRAIL_ALPHA)

	var world := get_parent()
	if world == null:
		return
	world.add_child(ghost)
	ghost.global_position = global_position
	ghost.rotation = _sprite.rotation

	# 흐려지며 쪼그라든다. 수명이 「간격 × 남길 장수」라 화면엔 항상 같은 수가 보인다.
	var tw := ghost.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "modulate:a", 0.0, life)
	tw.tween_property(ghost, "scale", ghost.scale * TRAIL_END_SCALE, life)
	tw.chain().tween_callback(ghost.queue_free)


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
	_age += delta
	_animate(delta)
	if _travelled >= max_distance:
		_finish(null)


## 날아가는 동안의 연출. 그림 자체는 안 가리고 **움직임**만 준다.
func _animate(delta: float) -> void:
	if _sprite == null:
		return

	# ① 태어날 때 확 커진다 — "튀어나왔다"
	var born: float = clampf(_age / BIRTH_TIME, 0.0, 1.0)
	var grow: float = lerpf(BIRTH_SCALE, 1.0, born * (2.0 - born))   # ease-out

	# 그림은 **왜곡하지 않는다.** 회전도 안 준다. 유저가 그린 게 그대로 읽혀야 한다.
	_sprite.scale = Vector3.ONE * grow

	# ② 빛이 맥박친다 — 멀리서도 "뭔가 날아온다" 가 읽힌다.
	if _lamp != null:
		_lamp.light_energy = 1.6 + sin(_age * 22.0) * 0.35

	# ③ 꼬리 — 간격을 **거리**로 잡는다. 느린 탄도 빠른 탄도 밀도가 같아진다.
	_trail_wait -= delta
	if _trail_wait <= 0.0:
		var spacing: float = maxf(_sprite_size * TRAIL_SPACING, 0.05)
		_trail_wait = clampf(spacing / maxf(speed, 0.1), 0.016, 0.12)
		_drop_trail(_trail_wait * TRAIL_GHOSTS)


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


## 판정을 끄고 **터진 뒤** 사라진다.
## 종전엔 그냥 0.12초 있다 없어졌다 — 맞았는지 안 맞았는지 화면에 안 보였다.
func _finish(target: Node3D) -> void:
	if _spent:
		return
	_spent = true
	hit.emit(target)
	set_deferred("monitoring", false)
	set_physics_process(false)
	_burst()
	_explode(target != null)
	await get_tree().create_timer(FLASH_TIME).timeout
	queue_free()


## 맞은 자리에 폭발을 남긴다 — 파편·충격파 링·빛.
## 투사체는 곧 사라지므로 **형제로 붙여야** 폭발이 같이 안 지워진다.
func _explode(hit_target: bool) -> void:
	var world := get_parent()
	if world == null:
		return
	var boom := IMPACT.new()
	boom.color = color
	boom.radius = maxf(_radius(), 0.35)
	boom.lethal = hit_target
	world.add_child(boom)
	boom.global_position = global_position

	# 소리 — 크면 낮게 운다. 저역이 「퍽」 을 만든다.
	var pitch: float = clampf(1.35 - _radius() * 0.35, 0.55, 1.5)
	Sfx.play("hit" if hit_target else "fire", pitch, -6.0 if not hit_target else 0.0)


## 맞은 자리에서 터진다. 그림이 확 커지며 사라지고 빛이 한 번 튄다.
func _burst() -> void:
	if _sprite != null:
		var tw := _sprite.create_tween()
		tw.set_parallel(true)
		tw.tween_property(_sprite, "scale", _sprite.scale * BURST_SCALE, BURST_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_sprite, "modulate:a", 0.0, BURST_TIME)
	if _lamp != null:
		# 빛이 한 번 확 튀었다 꺼진다. 「퍽」 하는 느낌은 이게 만든다.
		var lt := _lamp.create_tween()
		lt.tween_property(_lamp, "light_energy", 7.0, 0.04)
		lt.tween_property(_lamp, "light_energy", 0.0, BURST_TIME)
		var rt := _lamp.create_tween()
		rt.tween_property(_lamp, "omni_range", _lamp.omni_range * 2.6, BURST_TIME)
