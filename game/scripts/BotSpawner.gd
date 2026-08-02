extends Node3D
## 봇을 아레나에 심는다.
##
## `Player.tscn` 을 그대로 인스턴스해서 **겉모습을 재활용**하고, 스크립트만 `Bot.gd` 로 갈아 끼운다.
## 적을 따로 모델링하지 않는 이유: 아트가 「목도리 = 팀 구분색 자리」로 비워 뒀고,
## 같은 몸에 색만 다르면 **「같은 규칙으로 노는 상대」**라는 게 화면에서 바로 읽힌다.
##
## `Arena.tscn` 이 아니라 코드로 붙이는 이유는 그 파일이 아트 담당이라
## 개발이 동시에 손대면 서로 덮어쓰기 때문이다.

## ⚠ `preload` 를 쓰면 안 된다 — **순환 참조**가 된다.
## `Player.gd` → `BotSpawner.gd` → `Player.tscn` → `Player.gd`.
## `preload` 는 컴파일 시점에 풀어야 해서 이 고리를 못 끊는다. 런타임 `load` 로 미룬다.
const BOT_PATH := "res://scripts/Bot.gd"
const PLAYER_SCENE_PATH := "res://scenes/Player.tscn"

## 적 색 — 아트 실측으로 확정(2026-08-02).
##
## 🔑 처음엔 넓은 면을 **전부 같은 빨강 하나**로 칠했는데, 렌더로 보니
## 봇이 **납작한 빨간 덩어리**가 됐다. 플레이어의 **명도 구조를 그대로 옮기고
## 색상(hue)만 파랑 → 빨강**으로 바꿔야 사람으로 보인다.
##
## 트림이 금색이 아니라 **뼈색**인 이유: 빨강 위의 금색은 따뜻한 색끼리라 묻힌다.
## 뼈색은 확 뜨고, **「금색=아군 / 흰색=적」이라는 두 번째 구분 신호**가 공짜로 생긴다.
const ENEMY_ROBE := Color(0.88, 0.22, 0.20)     ## 로브·양팔 — 팀색 자리(가장 넓은 면)
const ENEMY_DARK := Color(0.26, 0.06, 0.10)     ## 모자·망토·꼬리
const ENEMY_PANTS := Color(0.31, 0.14, 0.16)    ## 바지
const ENEMY_TRIM := Color(0.95, 0.93, 0.86)     ## 러프·모자띠·부츠단

## 어디에 몇 마리를 놓을까. 러그 바깥쪽으로 흩어 둔다.
## 처음엔 **한 마리**로 시작한다. 2마리가 동시에 쏘면 6.6초 만에 죽는다(실측).
## 익숙해지면 여기에 좌표를 더하면 된다.
@export var spawn_points: Array[Vector3] = [
	Vector3(2.0, 0.4, -8.0),
]


func _ready() -> void:
	for p in spawn_points:
		_spawn_bot(p)


func _spawn_bot(pos: Vector3) -> void:
	var scene: PackedScene = load(PLAYER_SCENE_PATH)
	if scene == null:
		return
	var bot := scene.instantiate()
	# 플레이어용 부품은 떼어낸다 — 봇은 카메라도 조준 화살표도 필요 없다.
	for path in ["CamPivot", "Body/AimArrow"]:
		var n := bot.get_node_or_null(path)
		if n != null:
			n.queue_free()

	bot.set_script(load(BOT_PATH))
	bot.name = "Bot"
	add_child(bot)
	bot.global_position = pos
	_tint(bot)
	_add_health_label(bot)


## 머리 위 체력. 얼마나 깎았는지 안 보이면 때리는 맛이 없다.
func _add_health_label(bot: Node) -> void:
	var label := Label3D.new()
	label.name = "HpLabel"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.pixel_size = 0.0042
	# 모자 꼭짓점이 2.13 으로 올라가서 2.3 이면 모자에 걸린다(아트 실측).
	label.position = Vector3(0, 2.55, 0)
	label.modulate = Color(1, 0.72, 0.68)
	bot.add_child(label)

	var update := func(hp: float, mx: float) -> void:
		if is_instance_valid(label):
			label.text = "%d / %d" % [int(ceil(hp)), int(mx)]
	bot.health_changed.connect(update)
	update.call(bot.hp, bot.max_hp)


## 옷 색만 바꿔 적으로 만든다. 실루엣은 같아야 「같은 규칙으로 노는 상대」로 읽힌다.
##
## ⛔ **얼굴·손·발·마법봉은 절대 칠하지 않는다** — 칠하면 사람이 아니라 색종이가 된다.
func _tint(bot: Node) -> void:
	var body := bot.get_node_or_null("Body")
	if body == null:
		return
	for p in ["Torso", "ShoulderL/ArmL", "Wand/ArmR"]:
		_paint(body.get_node_or_null(p), ENEMY_ROBE)
	for p in ["Mantle", "MantleTail", "Neck/CapCone", "Neck/CapBrim"]:
		_paint(body.get_node_or_null(p), ENEMY_DARK)
	for p in ["HipL/LegL", "HipR/LegR"]:
		_paint(body.get_node_or_null(p), ENEMY_PANTS)
	for p in ["Collar", "Neck/HatBand", "HipL/AnkleL/CuffL", "HipR/AnkleR/CuffR"]:
		_paint(body.get_node_or_null(p), ENEMY_TRIM)


func _paint(node: Node, col: Color) -> void:
	var mesh := node as MeshInstance3D
	if mesh == null or mesh.mesh == null:
		return
	var src := mesh.get_active_material(0)
	var m: StandardMaterial3D
	if src is StandardMaterial3D:
		m = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		m = StandardMaterial3D.new()
	m.albedo_color = col
	mesh.material_override = m
