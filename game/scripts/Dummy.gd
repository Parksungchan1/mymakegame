extends StaticBody3D
## 허수아비 — 로드맵 2단계에서 "발사가 실제로 맞았는지" 눈으로 확인하려고 세운 표적.
##
## 봇(4단계)이 아니다. 움직이지도, 반격하지도, 생각하지도 않는다.
## 맞으면 체력이 줄고 색이 튀고, 0이 되면 잠깐 쓰러졌다가 다시 선다.
## 데미지가 들어가는 걸 확인할 대상이 없으면 2단계를 검증할 방법이 없어서 둔다.
##
## 4단계에서 진짜 봇이 들어오면 이 파일은 없어져도 된다.

@export var max_hp: float = 100.0
## 쓰러진 뒤 다시 서기까지(초)
@export var respawn_delay: float = 2.5

const BASE_COLOR := Color(0.55, 0.52, 0.62)
const HIT_COLOR := Color(1.0, 0.85, 0.45)
const DOWN_COLOR := Color(0.28, 0.26, 0.32)
const FLASH_TIME := 0.14

var hp: float = 0.0

var _mat: StandardMaterial3D
var _label: Label3D
var _down: bool = false


func _ready() -> void:
	hp = max_hp
	_build()
	_refresh()


func _build() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = BASE_COLOR
	_mat.roughness = 0.8

	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.8
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = Vector3(0.0, 0.9, 0.0)
	view.material_override = _mat
	add_child(view)

	# 체력을 머리 위에 띄운다. 데미지가 들어갔는지 이게 가장 확실하다.
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 64
	_label.pixel_size = 0.004
	_label.position = Vector3(0.0, 2.2, 0.0)
	add_child(_label)


## 투사체가 부르는 창구. 이름을 바꾸면 Projectile.gd 가 못 찾는다.
## **반환값이 계약이다** — false 면 "안 맞았다"는 뜻이고 투사체는 그냥 지나간다.
## 쓰러진 허수아비가 탄을 먹어 뒤에 선 적을 지켜주는 시체 방패를 막으려는 것이다.
func take_damage(amount: float) -> bool:
	if _down:
		return false
	hp = maxf(hp - amount, 0.0)
	_refresh()
	if hp <= 0.0:
		_fall()
	else:
		_flash()
	return true


func _refresh() -> void:
	_label.text = "%d / %d" % [int(round(hp)), int(round(max_hp))]


func _flash() -> void:
	_mat.albedo_color = HIT_COLOR
	await get_tree().create_timer(FLASH_TIME).timeout
	if not _down:
		_mat.albedo_color = BASE_COLOR


func _fall() -> void:
	_down = true
	_mat.albedo_color = DOWN_COLOR
	_label.text = "쓰러짐"
	rotation.x = deg_to_rad(-80.0)
	await get_tree().create_timer(respawn_delay).timeout
	rotation.x = 0.0
	hp = max_hp
	_down = false
	_mat.albedo_color = BASE_COLOR
	_refresh()
