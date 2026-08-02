extends Node3D
## 명중 폭발 — 파편 + 충격파 링 + 빛.
##
## 2026-08-02. 사용자 지적: "다른게임이랑 다르게 너무 단조롭고 뭔가 날라가는 임펙트나 이런게 없어"
## 종전엔 그림이 커지며 사라지는 게 전부였다. **터졌다는 느낌이 없었다.**
##
## 색은 스킬 색을 그대로 쓴다 — 유저가 고른 색이 주인공이다.
## 다만 아트 실측대로 **역할을 가른다**: 파편·링은 혼합(색 담당), 코어 플래시는 가산(밝기 담당).
## 가산은 한가운데가 무슨 색이든 흰색으로 타므로 **아주 짧게만** 쓴다.

const LIFE := 0.45

var color: Color = Color.WHITE
var radius: float = 1.0
## 처치 여부. 죽였을 때는 더 크게 터진다.
var lethal: bool = false


func _ready() -> void:
	_spawn_ring()
	_spawn_shards()
	_spawn_flash()
	await get_tree().create_timer(LIFE + 0.2).timeout
	queue_free()


## 바닥에 퍼지는 충격파 링. 카메라가 -32° 부감이라 이게 가장 잘 읽힌다.
func _spawn_ring() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.62
	mesh.outer_radius = 0.78
	mesh.rings = 24

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.material_override = mat
	ring.scale = Vector3.ONE * (radius * 0.4)
	add_child(ring)

	var grow: float = radius * (4.2 if lethal else 2.8)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * grow, LIFE) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, LIFE)


## 사방으로 튀는 파편. 「터졌다」를 만드는 건 결국 이거다.
func _spawn_shards() -> void:
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 26 if lethal else 16
	p.lifetime = 0.42
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = radius * 5.0
	p.initial_velocity_max = radius * 11.0
	p.gravity = Vector3(0, -14.0, 0)
	p.scale_amount_min = radius * 0.16
	p.scale_amount_max = radius * 0.34
	p.damping_min = 2.0
	p.damping_max = 5.0

	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	p.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	p.material_override = mat

	# 끝으로 갈수록 흐려진다. `color_ramp` 는 Gradient 를 **그대로** 받는다
	# (GradientTexture1D 를 넣으면 타입이 안 맞아 컴파일이 깨진다).
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, 1.0))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp

	add_child(p)


## 한순간 확 밝아진다. 가산이라 한가운데는 흰색으로 탄다 — 그래서 아주 짧게만.
func _spawn_flash() -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = color
	lamp.light_energy = 0.0
	lamp.omni_range = radius * (9.0 if lethal else 6.0)
	add_child(lamp)

	var tw := lamp.create_tween()
	tw.tween_property(lamp, "light_energy", 9.0 if lethal else 5.5, 0.03)
	tw.tween_property(lamp, "light_energy", 0.0, 0.22)
