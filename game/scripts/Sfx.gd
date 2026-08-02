extends Node
## 효과음 (autoload: Sfx) — **오디오 파일 없이** 파형을 계산해서 굽는다.
##
## 2026-08-02. 사용자 지적: "다른게임이랑 다르게 너무 단조롭고 뭔가 날라가는 임펙트나 이런게 없어"
## 타격감의 절반은 소리다. 그런데 이 프로젝트엔 오디오 파일이 **하나도 없다.**
##
## 아트 판단: `AudioStreamGenerator` 실시간 합성은 버퍼 언더런(크래클) 위험이 있고
## 폴리포니·3D를 손으로 짜야 한다. 대신 **`AudioStreamWAV.data` 에 PCM 을 계산해 넣고 굽는다** —
## 시작 때 한 번만 돌고, 런타임 비용 0, `pitch_scale`·3D·버스가 전부 공짜로 따라온다.
##
## 소리의 주인공은 **저역**이다. 「퍽」 은 고음이 아니라 낮은 쪽에서 나온다.

const RATE := 22050

var _bank: Dictionary = {}
## 동시에 여러 소리가 나야 하므로 재생기를 돌려 쓴다.
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
const POOL_SIZE := 12


func _ready() -> void:
	_bank["fire"] = _bake_fire()
	_bank["hit"] = _bake_hit()
	_bank["kill"] = _bake_kill()
	_bank["dash"] = _bake_dash()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


## 소리 하나 재생. pitch 로 스킬 크기를 실을 수 있다(크면 낮게).
func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _bank.get(name)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.4, 2.2)
	p.volume_db = volume_db
	p.play()


# ─────────────────────────────────────────────────────────────
# 파형 굽기
# ─────────────────────────────────────────────────────────────

## 16비트 모노 PCM 을 담은 AudioStreamWAV 를 만든다.
## `samples` 는 -1.0 ~ 1.0 범위의 float 배열.
func _bake(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav


## 발사 — 짧게 「츄웅」. 주파수가 위에서 아래로 훑고 지나간다.
## 위상을 매 샘플 **누적**해야 한다. `sin(t * f)` 로 쓰면 f 가 변할 때 위상이 튀어 딱딱 소리가 난다.
func _bake_fire() -> AudioStreamWAV:
	var n := int(RATE * 0.16)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var freq: float = lerpf(880.0, 180.0, t * t)
		phase += TAU * freq / float(RATE)
		var env: float = pow(1.0 - t, 2.4)
		# 사인에 약간의 잡음을 섞어 「마법」 느낌을 준다
		var noise: float = (randf() * 2.0 - 1.0) * 0.18 * env
		out[i] = (sin(phase) * 0.8 + noise) * env
	return _bake(out)


## 명중 — 「퍽」. 낮은 사인 + 잡음 버스트. 저역이 주인공이다.
func _bake_hit() -> AudioStreamWAV:
	var n := int(RATE * 0.20)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var freq: float = lerpf(220.0, 70.0, sqrt(t))
		phase += TAU * freq / float(RATE)
		var body: float = sin(phase) * pow(1.0 - t, 1.8)
		# 앞머리에만 얹는 잡음이 「탁」 하는 어택을 만든다
		var crack: float = (randf() * 2.0 - 1.0) * pow(maxf(1.0 - t * 6.0, 0.0), 2.0) * 0.7
		out[i] = clampf(body * 0.9 + crack, -1.0, 1.0)
	return _bake(out)


## 처치 — 더 낮고 더 길게 「쿠웅」. 배음을 얹어 묵직하게.
func _bake_kill() -> AudioStreamWAV:
	var n := int(RATE * 0.45)
	var out := PackedFloat32Array()
	out.resize(n)
	var p1 := 0.0
	var p2 := 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var f1: float = lerpf(160.0, 42.0, sqrt(t))
		p1 += TAU * f1 / float(RATE)
		p2 += TAU * (f1 * 1.5) / float(RATE)
		var env: float = pow(1.0 - t, 1.5)
		var crack: float = (randf() * 2.0 - 1.0) * pow(maxf(1.0 - t * 9.0, 0.0), 2.0) * 0.55
		out[i] = clampf((sin(p1) * 0.85 + sin(p2) * 0.25 + crack) * env, -1.0, 1.0)
	return _bake(out)


## 대쉬 — 짧은 「휙」. 잡음을 빠르게 열었다 닫는다.
func _bake_dash() -> AudioStreamWAV:
	var n := int(RATE * 0.13)
	var out := PackedFloat32Array()
	out.resize(n)
	var last := 0.0
	for i in n:
		var t: float = float(i) / float(n)
		# 잡음을 한 번 걸러 「쉬익」 에 가깝게 만든다
		var raw: float = randf() * 2.0 - 1.0
		last = lerpf(last, raw, 0.35)
		var env: float = sin(PI * t) * pow(1.0 - t, 0.6)
		out[i] = last * env * 0.55
	return _bake(out)
