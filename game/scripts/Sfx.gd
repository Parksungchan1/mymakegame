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
##
## **정규화한다** — 파형을 tanh 로 눌러 놓으면 최대치가 0.5~0.7 쯤에서 멈춰
## 다른 소리보다 작게 들린다. 어택 비율은 그대로 두고 전체를 끌어올린다.
func _bake(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	# 0.92 까지만 올린다. 1.0 에 붙이면 재생 중 합쳐질 때 깨진다.
	var gain: float = (0.92 / peak) if peak > 0.001 else 1.0

	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0)
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
	var n := int(RATE * 0.13)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var noise_lp := 0.0
	for i in n:
		var t: float = float(i) / float(n)

		# 주파수가 위에서 아래로 **아주 빠르게** 훑는다. 이게 「슉」 을 만든다.
		var freq: float = 120.0 + 900.0 * exp(-t * 18.0)
		phase += TAU * freq / float(RATE)
		var body: float = sin(phase) * exp(-t * 11.0)

		# 맨 앞의 바람 소리. 발사에도 어택이 있어야 「툭」 하고 나간다.
		var raw: float = randf() * 2.0 - 1.0
		noise_lp = lerpf(noise_lp, raw, 0.5)
		var air: float = noise_lp * exp(-t * 22.0) * 0.45

		out[i] = _saturate((body + air) * 1.25) * 0.85
	return _bake(out)


## 명중 — 「퍽」.
##
## 🔑 1차는 순수 사인파라 **물렁했다**(사용자: "뭔가 타격감있는 소리는 아닌거 같아").
## 타격음을 만드는 건 세 가지다:
##   ① **트랜지언트** — 맨 앞 5ms 에 몰린 날카로운 잡음. 「탁」 이 여기서 난다
##   ② **급강하 저역** — 220Hz 에서 45Hz 로 **아주 빠르게** 떨어지는 바디. 「퍽」 이 여기서 난다
##   ③ **왜곡(saturation)** — 사인을 tanh 로 밀면 배음이 생겨 스피커에서 꽉 찬 소리가 된다
## 그리고 **짧아야 한다.** 길면 「웅」 하고 울리지 「퍽」 이 아니다.
func _bake_hit() -> AudioStreamWAV:
	var n := int(RATE * 0.16)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var noise_lp := 0.0
	for i in n:
		var t: float = float(i) / float(n)

		# ② 급강하 저역 — 지수로 떨어져야 「퍽」 이 된다. 선형이면 「뿅」 이다.
		var freq: float = 45.0 + 175.0 * exp(-t * 14.0)
		phase += TAU * freq / float(RATE)
		var body: float = sin(phase) * exp(-t * 9.0)

		# ① 트랜지언트 — 맨 앞에만 있는 잡음. 한 번 걸러 「탁」 에 가깝게.
		var raw: float = randf() * 2.0 - 1.0
		noise_lp = lerpf(noise_lp, raw, 0.55)
		var click: float = noise_lp * exp(-t * 60.0) * 0.9

		# ③ 왜곡 — tanh 로 밀어 배음을 만든다. 이게 「꽉 찬」 소리를 만든다.
		out[i] = _saturate((body * 1.15 + click) * 1.4)
	return _bake(out)


## 처치 — 「쿠웅」. 명중보다 **더 낮고 더 길고 더 두껍게**.
## 명중과 같은 방식이되 주파수를 반으로 내리고 배음을 하나 더 얹는다.
func _bake_kill() -> AudioStreamWAV:
	var n := int(RATE * 0.55)
	var out := PackedFloat32Array()
	out.resize(n)
	var p1 := 0.0
	var p2 := 0.0
	var noise_lp := 0.0
	for i in n:
		var t: float = float(i) / float(n)

		var f1: float = 28.0 + 130.0 * exp(-t * 7.0)
		p1 += TAU * f1 / float(RATE)
		p2 += TAU * (f1 * 1.5) / float(RATE)   # 완전5도 위 — 두께를 만든다

		var body: float = (sin(p1) * 0.9 + sin(p2) * 0.35) * exp(-t * 4.2)

		var raw: float = randf() * 2.0 - 1.0
		noise_lp = lerpf(noise_lp, raw, 0.4)
		var click: float = noise_lp * exp(-t * 34.0) * 0.8

		out[i] = _saturate((body * 1.2 + click) * 1.5)
	return _bake(out)


## tanh 근사 — 값을 부드럽게 눌러 배음을 만든다.
## 그냥 clamp 하면 각져서 지직거리고, 안 누르면 물렁하다.
func _saturate(x: float) -> float:
	return x / (1.0 + absf(x))


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
