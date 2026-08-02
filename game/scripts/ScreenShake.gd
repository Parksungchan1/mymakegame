extends Node
## 화면 흔들림 — 「쿵」 하는 타격감을 만든다.
##
## 2026-08-01 사용자 요구:
##   "상대를 죽였을 때 좀 더 도파민이 터지게 쿵 하는 살짝에 화면 떨림이 일어나는 걸로 해줘"
##
## 🔑 **카메라 각도를 절대 건드리지 않는다.**
## `cam_yaw_deg 0° / cam_pitch_deg -32°` 는 사용자 확정 사항(`✅ 결정됨`)이고,
## 방향키 매핑이 이 각도를 기준으로 돌아간다. 흔들리면서 각도가 바뀌면 조작이 흔들린다.
## 그래서 `Camera3D` 의 **로컬 오프셋(h_offset / v_offset)만** 흔든다 —
## 이건 화면이 밀리는 효과만 내고 카메라 기저(basis)는 그대로다.
##
## 이 노드는 `Camera3D` 의 **자식**으로 붙는다. 부모를 찾아 흔든다.

## 한 번 흔들 때 기본 세기(미터). 카메라가 7m 거리라 이 정도면 "쿵" 이고 어지럽지 않다.
const KILL_STRENGTH := 0.22
const HIT_STRENGTH := 0.06

## 흔들림이 잦아드는 데 걸리는 시간(초). 짧아야 "쿵" 이지 "덜덜" 이 아니다.
const KILL_TIME := 0.28
const HIT_TIME := 0.12

## 초당 흔드는 횟수. 너무 높으면 지직거리고 낮으면 출렁인다.
const FREQ := 34.0

var _camera: Camera3D
var _left: float = 0.0
var _total: float = 0.0
var _strength: float = 0.0
## 매번 다른 방향으로 흔들리게 하는 시작 위상. 같은 방향으로만 밀리면 티가 난다.
var _seed: float = 0.0


func _ready() -> void:
	_camera = get_parent() as Camera3D
	if _camera == null:
		push_warning("ScreenShake: Camera3D 의 자식으로 붙여야 한다. 지금 부모는 %s" % get_parent())
		set_process(false)


## 적을 쓰러뜨렸을 때. 제일 세게 흔든다.
func kill() -> void:
	_shake(KILL_STRENGTH, KILL_TIME)


## 맞혔을 때. 죽인 것보다 훨씬 약하게 — 매 타격마다 세게 흔들면 눈이 아프다.
func hit() -> void:
	_shake(HIT_STRENGTH, HIT_TIME)


## 직접 세기를 정해 흔든다.
func _shake(strength: float, duration: float) -> void:
	# 이미 흔들리는 중이면 더 센 쪽을 남긴다(약한 게 센 걸 덮어쓰면 김이 빠진다).
	if _left > 0.0 and strength < _strength:
		return
	_strength = strength
	_left = duration
	_total = duration
	_seed = float(Time.get_ticks_msec() % 6283) * 0.001


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(_left - delta, 0.0)

	if _left <= 0.0:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		return

	# 남을수록 세고 끝날수록 잦아든다. 제곱으로 떨어뜨려야 "쿵" 하고 뚝 그친다.
	var t: float = _left / _total
	var falloff: float = t * t
	var phase: float = (_total - _left) * FREQ + _seed
	_camera.h_offset = sin(phase) * _strength * falloff
	_camera.v_offset = cos(phase * 1.37) * _strength * falloff * 0.7
