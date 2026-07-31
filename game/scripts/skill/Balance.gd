extends Node
## 밸런스 엔진 (autoload: Balance) — 순수 계산만 한다. 씬/노드를 건드리지 않는다.
##
## 담당: 기획/밸런스(game-designer). 이 파일의 **숫자**는 기획 담당이 조정한다.
## 함수 이름과 반환 키(=인터페이스)는 개발/에디터가 의존하므로 함부로 바꾸지 않는다.
##
## 대원칙 (docs/게임기획.md — **2026-07-31 사용자 승인으로 개정**):
##   그림은 모양을 바꾸고, 수치는 세기를 바꾼다.
##   어떤 그림을 그려도 **유효 명중 폭**(진행 방향에 수직인 단면 폭)이 `범위` 값으로 정규화된다.
##   → 한 명을 상대로 한 기대 데미지가 태그와 무관하게 같아진다.
##   종전 기준이던 「총 판정 면적 정규화」는 폐기됐다. 면적을 고정하면 기대 데미지가
##   1/√N(다탄) · 1/날씬함(캡슐) 으로 깎여 둥긂이 영구 1위가 되기 때문이다.
##   (QA 2차 실측: 면적 정규화 상태의 격차 2.21배. 근거와 승인 경위는 기획서 참조)

## 그림판 격자 크기
const GRID: int = 32

## 스킬 하나에 쓸 수 있는 총 예산
const BUDGET: float = 100.0
## 범위 1pt 당 예산 소모 계수
const RANGE_COEF: float = 0.6

## ── 예산 초과 처리 (2026-07-31, 기획 담당 결정) ────────────────────────
## 예산을 넘겨도 **만들 수는 있다.** 대신 초과분 1%마다 쿨타임·발동시간이 더 늘어난다.
## 저장이나 발사를 막지 않는 이유:
##   · 기획서 8행이 데미지 1~100 을 명시했는데, 막으면 데미지 100 이 사실상 존재할 수 없다
##     (데미지 100 + 최소 범위 1 = 100.6pt 라 무조건 초과다)
##   · 기획서 9행 형평성 원칙이 "셀수록 쿨 길게" 이므로, 초과분에 쿨을 더 붙이는 것은
##     새 규칙을 만드는 게 아니라 기존 원칙을 끝까지 적용하는 것이다
##   · 거부당하는 것보다 대가를 치르는 쪽이 만드는 재미가 산다
## 계수 3.0 의 근거 — 데미지×범위 1~100 전 조합(10,000개)을 훑어
## "유효 지속딜 = (데미지÷쿨) × 판정 반경" 을 비교했다:
##   페널티 0(현행) → 초과 최강 21.72 vs 합법 최강 11.24  ← 초과가 2배 이득. 형평성 붕괴
##   페널티 1.0     → 13.57 vs 11.24  ← 아직 이득
##   페널티 2.0     → 11.09 vs 11.24  ← 여기서 뒤집힌다
##   페널티 3.0     → 11.07 vs 11.24  ← 채택(여유 마진)
## 즉 3.0 이면 **예산을 넘겨서 이득 보는 조합이 하나도 없다.**
const OVER_COOLDOWN_PENALTY: float = 3.0
const OVER_CAST_PENALTY: float = 1.5

## 형태 태그
const TAG_LONG := "길쭉함"
const TAG_ROUND := "둥긂"
const TAG_SHARP := "뾰족함"
const TAG_SCATTER := "흩어짐"

## 태그 판정 임계값 — 기획 담당 조정 지점
const T_ASPECT_LONG: float = 2.5      ## 종횡비 이 이상이면 길쭉함
const T_COMPLEXITY_SHARP: float = 2.5 ## 둘레²/(4π·면적). 1.0=완전한 원
## 뾰족함은 복잡도만으로 판정하지 않는다. 채움률이 이보다 낮아야 한다.
## 이유: 복잡도는 둘레를 제곱해서 손떨림에 2차로 반응한다. 손으로 그린 원은
## 테두리가 한 칸만 울퉁불퉁해도 복잡도가 1.9 → 5.2 로 뛴다(검산 완료).
## 그러면 "원을 그렸는데 부채꼴이 나가는" 일이 벌어진다 — 예측 불가능해 재미가 죽는다.
## 채움률은 같은 손떨림에서 0.67 → 0.61 밖에 안 움직여 훨씬 안정적이다.
## 별·번개·십자는 채움률이 0.24~0.48 이라 이 문턱으로 원과 깨끗하게 갈린다.
const T_FILL_SHARP: float = 0.50      ## 채움률이 이 미만이어야 뾰족함
const T_MIN_BLOB_PIXELS: int = 4      ## 이보다 작은 덩어리는 노이즈로 무시

## 쿨타임 범위(초) — 예산을 다 쓰면 MAX, 아끼면 MIN
const COOLDOWN_MIN: float = 0.6
const COOLDOWN_MAX: float = 9.0
## 쿨타임 곡선의 지수. 1.0 이면 예산에 정비례(=선형).
## 선형이면 "데미지가 클수록 지속 딜(데미지÷쿨)이 계속 좋아진다" — 약한 스킬이 손해다.
## 지수를 1보다 크게 두면 비싼 스킬의 쿨이 더 가파르게 늘어 지속 딜이 평평해진다.
## 검산(범위 20 고정, 데미지 10~88 의 지속 딜 최대/최소 비):
##   지수 1.0 → 2.39배 · 1.3 → 1.75배 · **1.6 → 1.52배** · 2.0 → 1.43배
## 2.0 은 중간 데미지가 오히려 최강이 되는 역전이 생겨 1.6 을 쓴다.
const COOLDOWN_CURVE: float = 1.6

## 발동(캐스팅) 시간 범위(초) — 범위가 클수록 느려서 피하기 쉽다
const CAST_MIN: float = 0.12
const CAST_MAX: float = 1.10

## 투사체 속도 범위(m/s) — 범위가 작을수록 빠르다
const SPEED_MIN: float = 12.0
const SPEED_MAX: float = 28.0

## 【2026-07-31 개정】 **기준 원(둥긂)의 판정 면적 범위(m²).**
## 종전에는 "모든 태그가 나눠 갖는 총 면적"이었다. 이제는 **유효 명중 폭을 뽑아내는
## 기준값**이다 — 폭 = 2·√(이 면적 ÷ π), 즉 이 면적을 가진 원의 지름이다.
## 값을 그대로 둔 이유: 둥긂의 히트박스가 종전과 **한 자리도 안 바뀐다.**
## 둥긂은 종전 기준에서 가장 센 태그였으므로, 나머지 셋을 둥긂까지 끌어올리는 개정은
## **세기의 상한을 움직이지 않는다.** 그래서 예산 초과 페널티 계수 3.0 검산(10,000 조합),
## 쿨타임 곡선 1.6 검산이 재계산 없이 그대로 유효하다(재실행해 동일 결과 확인:
## 합법 최강 11.24 D48/R33 · 초과 최강 11.07 D69/R52).
const AREA_MIN: float = 0.8
const AREA_MAX: float = 12.0

## 유효 명중 폭(m)의 상·하한. AREA_MIN/MAX 에서 유도된 값이라 따로 조정하지 않는다.
## GDScript const 에는 함수 호출을 못 넣어 계산 결과를 적어 둔다. 계산의 권위는
## `effective_width_for()` 에 있다. WIDTH_MIN = 2√(0.8/π) · WIDTH_MAX = 2√(12/π).
const WIDTH_MIN: float = 1.00925
const WIDTH_MAX: float = 3.90882

## 사거리 범위(m). **전방 실효 도달 거리**다(= derive 의 `reach`).
## 캡슐(길쭉함)은 판정이 원점 앞으로 길이만큼 뻗어 있으므로 비행 거리를 그만큼 줄여
## 도달점을 여기에 맞춘다. 그래야 "길쭉하게 그리면 사거리가 는다"가 안 생긴다.
const DISTANCE_MIN: float = 8.0
const DISTANCE_MAX: float = 34.0

# ─────────────────────────────────────────────────────────────
# 퍼짐각 2개 — 2026-07-31 (3차 감사 위반 1 해소) 기획 담당 확정
#
# 【먼저 알아야 할 것】 퍼짐각은 **형평성 값이 아니라 정체성 값**이다.
#   [증명] 표적이 좌우 어디에 있을지 모를 때의 기대 데미지는
#     Σ(탄 i 의 명중 폭) × (데미지÷N) = N × 2(r_탄+r_표적) × D/N = 2D(r_탄+r_표적)
#   — 탄을 어느 각도로 벌리든 **합이 같다.** 퍼짐각은 기대 데미지를 1도 못 바꾼다.
#   퍼짐각이 정하는 유일한 것은 **전탄이 다 맞는 거리**다:
#     전탄 유지 거리 = (탄 반경 + 표적 반경) ÷ tan(퍼짐각 ÷ 2)
#   그 거리를 넘으면 바깥 탄부터 빗나가 데미지가 계단식으로 떨어진다.
#   → 그래서 퍼짐각은 기획서 76·78행의 **태그 체감**(견제형 / 근거리 난사형)으로 정한다.
#
# 【2026-07-31 정정 — QA 3차 N11: 위 식에 `1/cos θ` 가 빠져 있었다】
#   비스듬히 나는 탄은 좌우 스캔축에 대해 밴드가 `2r ÷ cos θ` 로 **넓어진다**
#   (θ = 그 탄이 조준축과 이루는 각). 정확한 식은
#     기대 데미지 = D × (평균 1/cos θ_i) × (유효 명중 폭 + 표적 지름)
#   이고, 종전 식은 `평균 1/cos θ_i = 1` 로 놓은 근사였다.
#   → **퍼짐각이 넓을수록 아주 조금 유리하다.** 실제 크기(계산 = QA 실측):
#     흩어짐 24°·5발  → 평균 1/cos = 1.0111  → **+1.1%** (QA 실측 +1.1%)
#     뾰족함 32°·3발  → 평균 1/cos = 1.0269  → **+2.7%** (QA 실측 +2.7%)
#     뾰족함 46°·5발  → 평균 1/cos = 1.0428  → **+4.3%** (현행 최댓값)
#   **보정하지 않는다.** 보정하려면 탄 반경을 cos 항만큼 줄여야 하는데, 그러면
#   `effective_width(box) == effective_width_for(total_area)`(오차 0)라는 검증 가능한
#   불변식이 깨진다. 4.3% 는 그 불변식을 흐리면서까지 살 값이 아니다.
#   **대신 규칙으로 남긴다 — `CONE_ANGLE_MAX` 를 46° 위로 더 열려면 이 항을 먼저 보정하라.**
#   (60° 면 +7.5%, 90° 면 +18% 로 커진다. 46° 는 「무시 가능」의 상한선이다)
#
# 검산 기준: 표적 반경 0.4m(QA 가 쓴 사람 크기 표적), 범위 50(총면적 6.40㎡ / 사거리 21.0m).
# ─────────────────────────────────────────────────────────────

## 무작위 표적을 상대로 한 기대 데미지·전탄 유지 거리를 계산할 때 쓰는 기준 표적 반경(m).
## QA 가 실측에 쓴 "사람 크기 표적(반경 0.4 캡슐)"과 같은 값이다. 전투 코드는 안 쓴다.
const TARGET_RADIUS_REF: float = 0.4

## 산탄(흩어짐)이 퍼지는 각도(도). 좁을수록 모여 나간다.
##
## 【14.0 → 24.0 (2026-07-31, 폭 정규화 개정에 맞춘 재계산)】
## 각도 자체의 기준은 안 바뀌었다. 기획서가 정한 흩어짐의 정체성은
##   「견제형 = 사거리의 40% 까지 전탄 · 80% 까지 3발 · 그 뒤 1발 (2단 완만 낙폭)」
## 이고, 그 %를 유지하려면 탄 반경이 커진 만큼 각도를 넓혀야 한다.
## 폭 정규화로 탄 반경이 범위 50 에서 0.638m → **1.427m** 로 커졌기 때문이다.
##   5발 전탄 유지 = (1.427+0.4) ÷ tan(12.0°) = 8.60m → 사거리 21.0m 의 **40.9%**
##   3발    유지 = (1.427+0.4) ÷ tan(6.0°)  = 17.39m → **82.8%**
## 종전 목표치(40.3% / 80.9%)와 1%p 안에서 일치한다. 14.0 을 그대로 두면
## 유지 거리가 14.9m(70.9%) 로 뛰어 「견제형」이 「전 거리 풀데미지」가 돼 버린다.
## 범위별 드리프트: 범위 1 → 53.5%, 18 → 50.0%, 50 → 40.9%, 100 → 32.6%.
## (큰 스킬일수록 더 붙어야 한다 = 기획서 9행 「범위 크고 세면 피하기 쉽다」와 같은 방향)
const SCATTER_SPREAD_DEG: float = 24.0

## 【2026-07-31 신설 — QA 3차 N7 해소】 흩어짐 퍼짐각을 **탄 수에 묶는다.**
##
## 문제: 퍼짐각이 24° 로 고정이면 **탄이 많을수록 정조준 데미지가 크다.**
## 탄이 촘촘해져 조준선 근처에 더 많이 남기 때문이다. 기대 데미지는 같은데
## 조준 데미지만 커지므로 **「덩어리를 많이 그리는 것」이 순수 지배 전략**이 됐다
## (QA 3차 실측). 창작이 아니라 정답 맞히기가 된다.
##
## 해법: 탄이 적으면 **좁게 모아** 쏜다. 유저 직관과도 맞는다 —
## 덩어리를 두어 개 그리면 뭉쳐 날아가고, 잔뜩 그리면 넓게 흩뿌린다.
## 각도는 「0~사거리 구간의 정조준 데미지 평균」이 5발과 같아지는 값으로 잡았다.
##
## [검산] 범위 50 · 데미지 60 · 표적 0.4m, 0.05m 간격 평균:
##   3발 18° → 41.96 · 5발 24° → 41.67 · 7발 27° → 41.55  (격차 **1.193배 → 1.010배**)
## [검산] 태그 정체성은 유지된다 — 흩어짐 각도 상한 27° < 뾰족함 각도 하한 32°,
##   흩어짐 전탄 유지 하한 35.9% > 뾰족함 상한 30.3%. 두 태그는 여전히 안 겹친다.
## 5발 24.0° 는 종전 그대로다 = 기획서가 정한 흩어짐의 정체성 기준점(40.9%)이 안 움직인다.
const SCATTER_ANGLE_3: float = 18.0
const SCATTER_ANGLE_5: float = 24.0
const SCATTER_ANGLE_7: float = 27.0


## 산탄(흩어짐)이 나누는 탄 수. damage_per_hit 의 흩어짐 ÷5 와 맞물린다.
## 폭 정규화 이후 이 값은 **기대 데미지를 안 바꾼다**(N 이 상쇄된다) — 진짜 모양 값이다.
const SCATTER_PELLETS: int = 5

## 부채꼴(뾰족함)이 **조준상 퍼지는** 각도(도).
##
## 【22.0 → 32.0 (2026-07-31, 폭 정규화 개정에 맞춘 재계산)】
## 기준은 그대로다 — 기획서 78행 「근거리 난사형」 = **전탄 유지 거리가 사거리의 30%,
## 그 뒤는 가운데 탄 1발만 남는 절벽**. 그리고 「부채꼴」이려면 흩어짐보다 넓어야 한다.
## 폭 정규화로 탄 반경이 범위 50 에서 0.818m → **1.427m** 가 됐으므로,
## 같은 30% 를 유지하려면 각도를 넓혀야 한다:
##   전탄 유지 = (1.427+0.4) ÷ tan(16.0°) = 6.37m → 사거리 21.0m 의 **30.3%**
##   흩어짐 5발(40.9%)보다 짧다 → 「근거리」 성립. 32° > 24° → 「부채꼴」 성립.
## 22.0 을 그대로 두면 유지 거리가 9.40m(44.8%) 로 늘어 흩어짐과 구분이 흐려진다.
## 범위별 드리프트: 범위 1 → 39.6%, 18 → 37.0%, 50 → 30.3%, 100 → 24.1%.
## 기대 데미지는 각도와 **무관**하다(아래 증명). 형평성은 여전히 안 건드린다.
const CONE_SPREAD_DEG: float = 32.0

## 부채꼴(뾰족함)을 실제로 쏠 때 나누는 탄 수.
## damage_per_hit 의 뾰족함 ÷3 과 맞물린다. 둘을 따로 바꾸면 총 데미지가 어긋난다.
## 폭 정규화 이후 탄 수는 기대 데미지를 안 바꾼다(N 상쇄) — 세기 값이 아니라 모양 값이다.
const CONE_PELLETS: int = 3

## 길쭉함(캡슐)의 날씬함 = **길이 ÷ 폭**.
##
## 【의미가 바뀌었다 — 2026-07-31 폭 정규화 개정】
## 종전: 길이 = 이 값 × √면적, 폭 = 면적 ÷ 길이 (→ 길이÷폭 = 이 값의 제곱)
## 개정: 폭은 유효 명중 폭으로 **고정**되고, 길이 = 이 값 × 폭 이다.
##   1.8 을 고른 이유는 **개정 전후로 캡슐 길이가 거의 안 변하게** 하려는 것이다.
##   종전 길이 = 2.0·√A, 개정 폭 = 2√(A/π) 이므로 종전 길이 = 1.772 × 개정 폭.
##   실제로 범위 50 에서 5.06m → 5.14m, 범위 100 에서 6.93m → 7.04m 로 거의 같다.
##   (QA 2차가 실측한 길이를 그대로 유지한다 = 재측정 부담이 최소다)
## 폭이 커졌으므로(1.26m → 2.85m) 겉모습은 「가는 창」에서 「긴 알약」으로 바뀐다.
## 이건 개정의 필연적 대가다 — 모든 태그의 명중 폭이 같아야 하므로 창만 얇을 수 없다.
const LONG_LEN_RATIO: float = 1.8

## 【신설 — 「얇은 선 하나로 맵 관통」을 막는 새 안전장치】
## 종전에는 면적 상한이 길이를 묶었다(길이 = 2.0·√면적). 폭을 정규화하면 그 족쇄가
## 풀리므로, **길이에 직접 상한을 건다.** 세 겹이다:
##   (1) 절대 상한 LONG_LENGTH_MAX_ABS — 어떤 범위·어떤 그림에서도 이 길이를 못 넘는다
##   (2) 사거리 비례 상한 LONG_LENGTH_MAX_FRAC — 캡슐이 사거리를 잡아먹지 못하게 한다
##   (3) `hitbox_for` 가 비행 거리에서 캡슐 길이를 빼서 **전방 도달점을 사거리에 고정**한다
##       (→ derive 의 `reach`. 길게 그려도 더 멀리 못 간다 = 관통의 본질인 사거리 연장 차단)
## 검산: 범위 100 에서 길이 7.04m(상한 8.0m 미만), 사거리 대비 20.7%(상한 30% 미만).
## 미세 파라미터를 최대(비율 3.0)로 열어도 상한에 걸려 2.05:1 · 8.0m 를 못 넘는다.
const LONG_LENGTH_MAX_ABS: float = 8.0
const LONG_LENGTH_MAX_FRAC: float = 0.30

## 캡슐 폭의 하한(m). 폭 정규화 이후 폭은 항상 WIDTH_MIN(1.009m) 이상이라
## 이 하한은 실제로 걸리지 않는다. 0 나눗셈 방어용으로만 남긴다.
const LONG_WIDTH_MIN: float = 0.22


# ─────────────────────────────────────────────────────────────
# 그림 미세 파라미터용 상수 — **2026-07-31 사용자 승인으로 일부 배선이 해금됐다.**
#
# 【왜 예전에 금지였나】 면적 정규화에서는
#   총면적 A 를 N 발로 쪼개면 탄 반경 √(A/Nπ), 한 발 데미지 D/N
#   → 기대 데미지 = N × 2√(A/Nπ) × D/N = 2D√(A/Nπ) ∝ **1/√N**
# 이라 탄 수가 곧 세기였다. 「많이 그릴수록 약해진다 = 잘 그릴수록 손해」였다.
#
# 【왜 이제 풀리나】 폭 정규화에서는 탄 반경이 N 과 무관하게 W/2 로 **고정**된다.
#   기대 데미지 = Σ (2r + 2R) × (D/N) = N × (W + 2R) × D/N = **D × (W + 2R)**
#   → N 이 상쇄된다. 퍼짐각도 안 들어간다. (QA 2차 실측으로 검증됨, 오차 ≤3.4%)
# 따라서 **탄 수와 퍼짐각은 진짜 모양 파라미터**가 됐다. 그림이 전투에 닿되 세기는 안 바꾼다.
#
# 해금 판정 (기획 담당, 2026-07-31):
#   ✅ 흩어짐 탄 수      — N 상쇄. 배선 가능
#   ✅ 뾰족함 탄 수      — N 상쇄. 배선 가능
#   ✅ 뾰족함 퍼짐각     — 원래부터 기대 데미지와 무관. 배선 가능
#   ⛔ 길쭉함 날씬함     — **아직 보류.** 정지 표적 기준으로는 무해하지만, 캡슐 길이는
#      투사체가 한 지점에 머무는 시간(길이 ÷ 속도)을 늘려 **움직이는 표적**에 대한
#      관용을 키운다. 범위 50 기준 길이 5.14m · 속도 20m/s → 0.26초 체류, 표적이
#      6m/s 로 움직이면 실효 폭이 약 1.5m 늘어난다. 닫힌 식이 못 잡는 2차 효과라
#      **4단계(봇 대전) 실측 전에는 그림에서 뽑지 않는다.** 최악값은 위 길이 상한이 묶고 있다.
#   ⛔ 둥긂 관통        — 새 메커니즘. 사용자 확인 대기(변동 없음)
# ─────────────────────────────────────────────────────────────

## 길쭉함: 종횡비(또는 회전 불변 신장도)가 T_ASPECT_LONG → 이 값으로 갈수록
## LONG_LEN_RATIO 가 MIN → MAX 로 움직인다. **배선 보류 중**(위 판정 참조).
## MIN 은 현행값과 같게, MAX 는 길이 상한이 확실히 먼저 걸리는 값으로 잡았다
## (범위 50 에서 3.0 은 8.56m 를 요구하지만 사거리 30% 상한 6.30m 에서 잘린다).
const T_ASPECT_LONG_FULL: float = 8.0
const LONG_LEN_RATIO_MIN: float = 1.8   ## 현행과 같은 캡슐 (길이:폭 = 1.8:1)
const LONG_LEN_RATIO_MAX: float = 3.0   ## 상한에 걸려 실제로는 2.0~2.3:1 에서 잘린다

## 뾰족함: 복잡도가 T_COMPLEXITY_SHARP → 이 값으로 갈수록 **퍼짐각**이 넓어지고
## 탄이 잘게 나뉜다. **배선 해금**(위 판정 참조).
##
## 【22.0 → 32.0 (2026-07-31, 4차 감사 위반 3 해소)】 하한이 흩어짐을 침범했다.
## 뾰족함과 흩어짐은 폭 정규화 이후 **탄 반경이 서로 같다**(둘 다 W/2). 그래서
##   전탄 유지 거리 = (W/2 + 표적반경) ÷ tan(퍼짐각 ÷ 2)
## 에서 두 태그를 가르는 것은 **오직 퍼짐각**이고, 「부채꼴이 산탄보다 넓다」와
## 「뾰족함이 산탄보다 짧게 유지된다」는 **같은 한 줄의 부등식**이다:
##   퍼짐각 > SCATTER_SPREAD_DEG(24.0)  ⟺  유지 거리가 흩어짐보다 짧다
## 탄 반경이 약분되므로 이 부등식은 **범위 1~100 어디서나 같이 성립**한다(검산 확인).
## 하한 22.0 은 이 부등식을 깼다 — 복잡도 2.50~2.9 구간에서 22~24° 가 나와
## 「부채꼴인데 산탄보다 좁고, 근거리인데 산탄보다 멀리까지 전탄 유지」가 됐다.
## 기획 담당이 CONE_SPREAD_DEG 11.0 을 폐기할 때 든 두 사유와 **글자 그대로 같다.**
##
## 그래서 하한을 기본값과 같은 32.0 으로 올린다. 판단 근거:
##   · 32.0 은 기획서가 정한 뾰족함의 정체성 값이다(전탄 유지 = 사거리의 30%).
##     **미세 파라미터는 정체성을 진하게만 할 수 있고 묽게 할 수는 없다** — 하한을
##     정체성 값에 붙이는 것이 그 규칙의 가장 단순한 구현이다.
##   · 24.0 바로 위(예: 26°)로 잡으면 흩어짐과의 여유가 2° · 3%p 뿐이라, 앞으로
##     SCATTER_SPREAD_DEG 를 1° 만 건드려도 정체성이 다시 뒤집힌다.
##   · 32° 하한에서도 미세 파라미터의 폭은 남는다(32°~46°, 유지 30.3%~20.5%).
## 검산(범위 50 · 표적 0.4m · 흩어짐 8.60m = 40.9%):
##   c=2.50 → 32.0° 유지 6.37m(30.3%) · c=6.0 → 37.2° 5.42m(25.8%) · c=12 → 46.0° 4.30m(20.5%)
##   전 구간에서 각도 > 24.0° 이고 유지 % < 40.9% 다.
const T_COMPLEXITY_SHARP_FULL: float = 12.0
const CONE_ANGLE_MIN: float = 32.0
const CONE_ANGLE_MAX: float = 46.0
## 탄 수는 **홀수만** 쓴다(아래 「홀수 탄 원칙」 참조). 3발 또는 5발.
const CONE_PELLETS_MIN: int = 3
const CONE_PELLETS_MAX: int = 5

## 흩어짐: 그림의 덩어리 수가 탄 수가 된다(이 범위로 자르고 **홀수로 올린다**).
## 덩어리 2→탄 3 · 3→3 · 4→5 · 5→5 · 6 이상→7. 홀수 덩어리는 그대로 맞아떨어진다.
## 【2→3 / 6→7 (2026-07-31, 4차 감사 위반 3)】 짝수 탄을 금지하느라 하한이 3 으로,
## 그 대가로 상한이 7 로 올라갔다(6 을 그렸는데 5 로 줄면 「많이 그릴수록 손해」가 된다).
## 탄 7발은 판정 부피가 기준의 7배다(범위 50 에서 44.8㎡) — 난전 위력은 4단계 재검증 항목.
const SCATTER_PELLETS_MIN: int = 3
const SCATTER_PELLETS_MAX: int = 7

## ── 홀수 탄 원칙 (2026-07-31, 4차 감사 위반 3 — 기획 담당 결정) ──────────
## **여러 발로 나가는 태그의 탄 수는 언제나 홀수다.**
##
## `Player._spawn_spread()` 는 탄을 -퍼짐/2 ~ +퍼짐/2 에 고르게 편다. 짝수면
## **정중앙 탄이 존재하지 않는다.** 그래서 전탄 유지 거리를 넘는 순간, 완벽하게
## 조준한 표적이 받는 데미지가 **0** 이 된다 — 탄이 전부 좌우로 비켜 간다.
## [검산] 탄 2발·24°·범위 50: 8.60m 까지 60, 그 뒤 **0**. 살짝 빗맞히면 30.
##   = **잘 조준할수록 손해**. 게임 규칙으로 낼 수 없는 값이다.
## 짝수 4발도 최대 범위(100)에서 안쪽 두 발의 벌어짐이 33.7m 라 사거리 34.0m 끝자락에
## 같은 구멍이 생긴다. 그래서 「2발만 금지」가 아니라 **홀수만 허용**으로 못박는다.
##
## 다른 선택지를 버린 이유:
##   (나) 짝수일 때 가운데 한 발을 더 둔다 → 결국 홀수가 된다. 같은 결과를 두 곳에서
##        계산하게 되고, 제작창의 「탄 N발」과 그림의 덩어리 수가 또 어긋난다.
##   (다) 퍼짐 배치를 바꾼다 → 짝수에 중앙 탄을 넣으려면 좌우 비대칭이 된다.
##        「부채꼴」이 한쪽으로 기울어 보인다. `Player` 코드도 고쳐야 한다.
##   (라) 문서를 고친다 → 「정조준 0 데미지」를 사실로 인정하는 것이라 기각.
## **(가) 를 고른 결과 `Player._spawn_spread()` 는 한 글자도 안 고쳐도 된다.**
## 홀수면 i=(N-1)/2 에서 t=0.5 → 각도 0 인 중앙 탄이 자동으로 생긴다(검산 확인).
## 제작창의 「그 뒤로는 일부만 맞는다」 문구도 이제 언제나 참이다(최소 1발은 맞는다).
## 【폐기됨 — 쓰지 마라】 퍼짐각을 탄 수에 따라 √(N ÷ 이 값) 배로 넓히려던 보정이다.
## 근거였던 "탄들의 각지름 합이 N 과 함께 커진다"는 한 발 데미지 D/N 을 곱하지 않은
## 계산이었다. 그리고 폭 정규화 이후에는 **기대 데미지가 애초에 N 과 무관**하므로
## 보정할 것이 없다. 넣으면 조준 명중 데미지만 깎여 순손해가 된다.
## 상수는 과거 문서와의 대조를 위해 남겨 두지만 **어디서도 호출하지 않는다.**
const SCATTER_SPREAD_REF_PELLETS: float = 5.0

## 둥긂: 채움률이 이 값 미만(= 속이 빈 그림)이면 관통형이 된다.
## 관통은 공짜가 아니다 — 총 데미지를 관통 수로 나눈다. 한 명만 맞히면 손해,
## 일직선에 두 명이 겹쳤을 때만 본전이다(제로섬).
const T_FILL_PIERCE: float = 0.35
const PIERCE_MAX: int = 2


# ─────────────────────────────────────────────────────────────
# 1. 그림(마스크) → 지표 4개
# ─────────────────────────────────────────────────────────────

## mask: GRID*GRID 길이, 0=빈칸 / 1=칠함.
## 반환: {filled, fill_ratio, aspect, complexity, blobs}
func analyze_mask(mask: PackedByteArray) -> Dictionary:
	var out := {
		"filled": 0,
		"fill_ratio": 0.0,
		"aspect": 1.0,
		"complexity": 1.0,
		"blobs": 0,
	}
	if mask.size() < GRID * GRID:
		return out

	var min_x := GRID
	var min_y := GRID
	var max_x := -1
	var max_y := -1
	var filled := 0
	for y in GRID:
		for x in GRID:
			if mask[y * GRID + x] == 0:
				continue
			filled += 1
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if filled == 0:
		return out

	var bw := float(max_x - min_x + 1)
	var bh := float(max_y - min_y + 1)
	out["filled"] = filled
	out["fill_ratio"] = float(filled) / (bw * bh)
	out["aspect"] = bw / bh
	out["complexity"] = _complexity(mask, filled)
	out["blobs"] = _count_blobs(mask)
	return out


## 둘레²/(4π·면적). 완전한 원이면 1.0, 뾰족·가늘수록 커진다.
func _complexity(mask: PackedByteArray, filled: int) -> float:
	var perimeter := 0
	for y in GRID:
		for x in GRID:
			if mask[y * GRID + x] == 0:
				continue
			# 4방향 중 비어 있거나 격자 밖인 면이 곧 둘레
			if x == 0 or mask[y * GRID + x - 1] == 0:
				perimeter += 1
			if x == GRID - 1 or mask[y * GRID + x + 1] == 0:
				perimeter += 1
			if y == 0 or mask[(y - 1) * GRID + x] == 0:
				perimeter += 1
			if y == GRID - 1 or mask[(y + 1) * GRID + x] == 0:
				perimeter += 1
	if filled <= 0:
		return 1.0
	return float(perimeter * perimeter) / (4.0 * PI * float(filled))


## 연결 판정에 쓰는 **8방향**. 타입을 붙여야 아래 for 문에서 d 가 Vector2i 로 추론된다.
##
## 【4방향 → 8방향 (2026-07-31, 기획 [D-2] 구현 · QA/개발이 잡은 「별이 흩어짐으로 튄다」 해결)】
## 4방향으로 세면 **대각선으로 이어진 선이 끊어진 것으로 잡힌다.** 픽셀 격자에서
## 대각선 획은 계단 모양이라 위·아래·좌·우로는 안 닿고 모서리로만 닿기 때문이다.
## 그래서 한붓그리기로 그린 별·번개가 「덩어리 여러 개」가 되어 흩어짐으로 튀었다.
## [검산] 스포크 별 192 조합(갈래 4·5·6·8 × 회전 0~75° × 반지름 4종 × 굵기 2종):
##   4방향 → **46 조합이 흩어짐으로 오판**(6갈래만이 아니라 4·5·8갈래에도 있었다)
##   8방향 → **0 조합.** 전부 뾰족함으로 바로잡힌다.
## 사람 눈에 「이어져 보이면 한 덩어리」가 맞다 — 8방향이 유저의 직관과 같은 쪽이다.
## [검산] 기본 스킬 4개 태그는 안 바뀐다: 원 r6 둥긂 · 막대 길쭉함 ·
##   점 3개 흩어짐(덩어리 3 그대로) · 원 r13 둥긂.
## 둘레(_complexity)는 4방향 그대로 둔다 — 둘레는 「면과 면이 맞닿는 길이」라
## 대각선 이웃을 세면 값이 부풀어 복잡도 문턱(2.5)이 통째로 흔들린다.
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


## 8방향 연결 요소 개수. 아주 작은 점은 노이즈로 세지 않는다.
func _count_blobs(mask: PackedByteArray) -> int:
	var seen := PackedByteArray()
	seen.resize(GRID * GRID)
	var blobs := 0
	for start in GRID * GRID:
		if mask[start] == 0 or seen[start] == 1:
			continue
		var size := 0
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			size += 1
			var x := i % GRID
			@warning_ignore("integer_division")
			var y := i / GRID
			for d in NEIGHBORS:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= GRID or ny >= GRID:
					continue
				var ni := ny * GRID + nx
				if mask[ni] == 1 and seen[ni] == 0:
					seen[ni] = 1
					stack.append(ni)
		if size >= T_MIN_BLOB_PIXELS:
			blobs += 1
	return blobs


# ─────────────────────────────────────────────────────────────
# 2. 지표 → 형태 태그 1개
# ─────────────────────────────────────────────────────────────

func tag_from_metrics(m: Dictionary) -> String:
	if int(m.get("filled", 0)) == 0:
		return TAG_ROUND
	if int(m.get("blobs", 0)) >= 2:
		return TAG_SCATTER
	var aspect := float(m.get("aspect", 1.0))
	if aspect >= T_ASPECT_LONG or aspect <= 1.0 / T_ASPECT_LONG:
		return TAG_LONG
	# 뾰족함은 **복잡도 + 채움률 두 조건을 모두** 만족해야 한다.
	# 복잡도 하나로만 보면 손으로 그린 원이 전부 뾰족함으로 넘어간다(T_FILL_SHARP 주석 참고).
	if float(m.get("complexity", 1.0)) >= T_COMPLEXITY_SHARP \
			and float(m.get("fill_ratio", 1.0)) < T_FILL_SHARP:
		return TAG_SHARP
	return TAG_ROUND


## 그림 하나 → 태그 (편의 함수)
func tag_from_mask(mask: PackedByteArray) -> String:
	return tag_from_metrics(analyze_mask(mask))


# ─────────────────────────────────────────────────────────────
# 3. 수치 + 태그 → 실제 전투 파라미터
# ─────────────────────────────────────────────────────────────

## 예산 소모량. damage 1~100, range_pt 1~100.
func cost_of(damage: float, range_pt: float) -> float:
	return damage + range_pt * RANGE_COEF


## 이 데미지에서 예산을 넘기지 않는 최대 범위값
func max_range_for(damage: float) -> float:
	return clampf((BUDGET - damage) / RANGE_COEF, 1.0, 100.0)


## 총 면적으로부터 **유효 명중 폭**(m)을 뽑는다. 이 폭이 형평성의 기준값이다.
## 폭 = 그 면적을 가진 원의 지름. 그래야 둥긂의 히트박스가 개정 전후로 안 바뀐다.
func effective_width_for(total_area: float) -> float:
	return 2.0 * sqrt(maxf(total_area, 0.0) / PI)


## 【2026-07-31 신설 — 홀수 탄 원칙】 탄 수를 홀수로 올린다.
## 짝수 탄은 정중앙 탄이 없어서, 전탄 유지 거리를 넘긴 **완벽 조준**이 한 발도 못 맞힌다
## (= 잘 조준할수록 손해). 상수 블록의 「홀수 탄 원칙」 주석에 근거가 있다.
## 다탄 태그의 탄 수는 반드시 이 함수를 거친다.
func to_odd_pellets(pellets: int) -> int:
	if pellets <= 1:
		return 1
	return pellets if pellets % 2 == 1 else pellets + 1


## 핵심 함수. 에디터·플레이어 양쪽이 이걸 쓴다.
## 반환 키: cost, over_budget, leftover, cooldown, cast_time, speed,
##          distance, total_area, tag, hitbox{...}
##          over_ratio, over_cooldown_mult, over_cast_mult  ← 2026-07-31 추가
##          effective_width, hitbox_area, reach              ← 2026-07-31 (2) 추가
##
## ⚠ `distance` 의 뜻이 바뀌었다 — **투사체가 실제로 비행하는 거리**다.
##   길쭉함(캡슐)은 판정이 원점 앞으로 길이만큼 뻗어 있으므로, 그만큼 덜 날아가야
##   전방 도달점이 `범위` 값이 정한 사거리와 같아진다. 그 도달점이 새 키 `reach` 다.
##   `distance` 를 Player 의 max_distance 로 쓰는 것은 그대로 맞다(그래야 도달점이 맞는다).
##   **제작창이 「사거리」로 보여줄 값은 이제 `distance` 가 아니라 `reach` 다.**
##   【2026-07-31 정정 · QA N9】 종전 주석은 「나머지 세 태그는 reach == distance」라고
##   적었는데 **그게 버그였다.** 구·부채꼴·산탄도 판정이 반경만큼 앞으로 뻗어 있어
##   실제 도달점이 `reach + 반경` 이었다(범위 100 에서 35.95m, 표시 34.0m).
##   이제 네 태그 모두 `forward_lead > 0` 이라 `distance < reach` 이고,
##   **전방 도달점이 네 태그 전부 `reach` 로 일치한다.**
##
## m: 그림 지표(analyze_mask 결과). 넘기면 태그별 미세 파라미터가 적용된다.
##   안 넘기면 지금까지와 완전히 같게 동작한다 — 기존 호출부는 안 깨진다.
func derive(damage: float, range_pt: float, tag: String, m: Dictionary = {}) -> Dictionary:
	# NaN 가드 — clampf 는 NaN 을 못 거른다. NaN 이 한 번 들어가면 쿨타임이 영원히
	# 안 풀려 그 스킬이 죽는다(QA S9). 입구에서 기본값으로 되돌린다.
	if is_nan(damage) or is_inf(damage):
		damage = 1.0
	if is_nan(range_pt) or is_inf(range_pt):
		range_pt = 1.0
	damage = clampf(damage, 1.0, 100.0)
	range_pt = clampf(range_pt, 1.0, 100.0)

	var cost := cost_of(damage, range_pt)
	var leftover: float = maxf(BUDGET - cost, 0.0)
	var budget_ratio := cost / BUDGET
	var spent_ratio: float = clampf(budget_ratio, 0.0, 1.0)
	# 예산을 넘긴 만큼(0.6 = 60% 초과). 넘기지 않았으면 0.
	var over_ratio: float = maxf(budget_ratio - 1.0, 0.0)
	var over_cooldown_mult: float = 1.0 + over_ratio * OVER_COOLDOWN_PENALTY
	var over_cast_mult: float = 1.0 + over_ratio * OVER_CAST_PENALTY
	var range_ratio := range_pt / 100.0

	# 예산을 많이 쓸수록 쿨타임이 길다. 곡선이라 비쌀수록 더 가파르게 는다.
	# 예산을 넘겼으면 그 위에 초과 페널티가 곱해진다 — 상한 없이 계속 길어진다.
	var cooldown: float = lerpf(COOLDOWN_MIN, COOLDOWN_MAX, pow(spent_ratio, COOLDOWN_CURVE)) \
			* over_cooldown_mult
	# 범위가 클수록 발동이 느려 피하기 쉽다. 데미지도 조금 거든다.
	var cast_time: float = lerpf(CAST_MIN, CAST_MAX,
			range_ratio * 0.75 + (damage / 100.0) * 0.25) * over_cast_mult
	# 범위가 작을수록 빠르게 날아간다
	var speed: float = lerpf(SPEED_MAX, SPEED_MIN, range_ratio)
	# 전방 실효 도달 거리 — 그림이 아니라 오직 범위 값이 정한다
	var reach: float = lerpf(DISTANCE_MIN, DISTANCE_MAX, range_ratio)
	# 기준 원(둥긂)의 판정 면적 → 유효 명중 폭. 역시 오직 범위 값이 정한다
	var total_area: float = lerpf(AREA_MIN, AREA_MAX, range_ratio)

	var box: Dictionary = hitbox_for(tag, total_area, reach, m)
	# 캡슐은 판정이 원점 앞으로 뻗어 있다. 그 길이만큼 덜 날아가야 도달점이 reach 와 맞는다.
	var lead: float = float(box.get("forward_lead", 0.0))
	var distance: float = maxf(reach - lead, 0.5)

	return {
		"cost": cost,
		"over_budget": cost > BUDGET,
		"leftover": leftover,
		"cooldown": cooldown,
		"cast_time": cast_time,
		"speed": speed,
		"distance": distance,
		"total_area": total_area,
		"tag": tag,
		"hitbox": box,
		"over_ratio": over_ratio,
		"over_cooldown_mult": over_cooldown_mult,
		"over_cast_mult": over_cast_mult,
		"effective_width": effective_width(box),
		"hitbox_area": hitbox_area(box),
		"reach": reach,
	}


## 흩어짐 탄 수 → 퍼짐각(도). 탄 수는 홀수 3·5·7 만 나온다(홀수 탄 원칙).
func scatter_spread_for(pellets: int) -> float:
	if pellets <= 3:
		return SCATTER_ANGLE_3
	if pellets <= 5:
		return SCATTER_ANGLE_5
	return SCATTER_ANGLE_7


## 태그가 **유효 명중 폭**을 어떤 모양으로 배치할지 결정한다.
## 【2026-07-31 개정 · 사용자 승인】 어떤 태그든 `effective_width(box)` 가
## `effective_width_for(total_area)` 와 같아지도록 맞춘다. 종전에는 판정 면적의 합을
## 맞췄는데, 그러면 기대 데미지가 1/√N · 1/날씬함 으로 깎여 둥긂이 영구 1위였다.
##
## 그 대가로 **총 판정 면적은 이제 태그마다 다르다.** 탄 하나하나가 둥긂과 같은 크기가
## 되므로 다탄 태그의 면적 합이 N 배가 된다(범위 50: 둥긂 6.4㎡ · 흩어짐 32.0㎡).
## 한 명 상대 기대 데미지는 같지만 **여러 명이 겹친 난전에서는 갈린다** — 5v5 재검증 항목.
##
## distance: 사거리(m). 캡슐 길이 상한(사거리 비례)에 쓴다. 0 이면 절대 상한만 건다.
## m: 그림 지표(analyze_mask 결과). 비어 있으면 태그 기본값으로 동작한다.
##
## 반환 키: kind, radius, length, width, angle_deg, pellets, pellet_radius
##          forward_lead ← 2026-07-31 (2) 추가. 판정이 원점보다 앞으로 뻗은 길이(m).
func hitbox_for(tag: String, total_area: float, distance: float = 0.0,
		m: Dictionary = {}) -> Dictionary:
	var w: float = effective_width_for(total_area)
	var box := {
		"kind": "sphere",
		"radius": w * 0.5,
		"length": 0.0,
		"width": 0.0,
		"angle_deg": 0.0,
		"pellets": 1,
		"pellet_radius": w * 0.5,
		# 🐞 QA N9 (2026-07-31) — 종전 기본값은 0.0 이었다. 구도 판정이 원점보다
		# **반경만큼 앞으로** 뻗어 있는데 그걸 안 빼서, 캡슐만 사거리에 맞고
		# 나머지 세 태그가 표시보다 +6~7% 멀리 닿았다(범위 100: 표시 34.0 ↔ 실측 35.95).
		# 캡슐만 보정하던 N2 조치의 **부호만 뒤집힌 재발**이었다. 여기서 근본을 맞춘다.
		"forward_lead": w * 0.5,
	}
	match tag:
		TAG_LONG:
			# 캡슐: 폭 = 유효 명중 폭(고정). 길이만 모양 값이다.
			# 길이는 3중 상한으로 묶는다 — 이것이 「얇은 선으로 맵 관통」의 새 차단 근거다.
			var width: float = maxf(w, LONG_WIDTH_MIN)
			var ratio: float = LONG_LEN_RATIO
			# ⛔ 신장도 → ratio 배선은 아직 보류다(위 미세 파라미터 블록 참조).
			#    풀 때는 여기서 LONG_LEN_RATIO_MIN/MAX 를 lerp 하면 된다.
			var length: float = ratio * width
			var cap: float = LONG_LENGTH_MAX_ABS
			if distance > 0.0:
				cap = minf(cap, distance * LONG_LENGTH_MAX_FRAC)
			length = clampf(length, width, maxf(cap, width))
			box["kind"] = "capsule"
			box["width"] = width
			box["radius"] = width * 0.5
			box["length"] = length
			# Projectile 이 캡슐을 원점 **앞쪽**에 통째로 놓는다(등 뒤 명중을 막으려고).
			# 그래서 전방 도달점이 비행거리 + 길이가 된다 → derive 가 이만큼 빼 준다.
			box["forward_lead"] = length
		TAG_SHARP:
			# 부채꼴: 탄 한 발 한 발이 둥긂과 **같은 크기**다(그래야 기대 데미지가 같다).
			# 각도는 실제로 나가는 퍼짐각과 같은 숫자다 — 문서·표시·전투를 하나로 묶는다.
			var angle: float = CONE_SPREAD_DEG
			var pellets: int = CONE_PELLETS
			if m.has("complexity"):
				var span: float = maxf(T_COMPLEXITY_SHARP_FULL - T_COMPLEXITY_SHARP, 0.0001)
				var t: float = clampf((float(m["complexity"]) - T_COMPLEXITY_SHARP) / span, 0.0, 1.0)
				angle = lerpf(CONE_ANGLE_MIN, CONE_ANGLE_MAX, t)
				# 홀수 탄 원칙 — 2 씩 건너뛴다(3 → 5). 가운데 탄이 항상 있어야 한다.
				@warning_ignore("integer_division")
				var steps: int = (CONE_PELLETS_MAX - CONE_PELLETS_MIN) / 2
				pellets = CONE_PELLETS_MIN + 2 * int(round(t * float(steps)))
			pellets = to_odd_pellets(clampi(pellets, 1, CONE_PELLETS_MAX))
			box["kind"] = "cone"
			box["angle_deg"] = angle
			box["pellets"] = pellets
			box["pellet_radius"] = w * 0.5
			# 부채꼴의 겉보기 반경(표시용). 탄들이 실제로 덮는 면적을 부채꼴로 환산한 값.
			box["radius"] = sqrt(float(pellets) * total_area * (360.0 / angle) / PI)
		TAG_SCATTER:
			# 산탄: 탄 하나하나가 둥긂과 같은 크기. 탄 수는 기대 데미지를 안 바꾼다.
			var pellets: int = SCATTER_PELLETS
			if m.has("blobs"):
				# 홀수 탄 원칙 — 덩어리 수를 홀수로 올린다(2→3 · 4→5 · 6 이상→7).
				pellets = to_odd_pellets(
					clampi(int(m["blobs"]), SCATTER_PELLETS_MIN, SCATTER_PELLETS_MAX))
			box["kind"] = "scatter"
			box["pellets"] = pellets
			box["pellet_radius"] = w * 0.5
			box["radius"] = w * 0.5
			# 🐞 QA N1 — 여기가 비어 있어서 제작창이 「전탄 명중: 사거리 전체」라고
			# 거짓말했다(full_hit_distance 가 0° → INF). 실제 퍼짐각을 채워 넣는다.
			# 🐞 QA N7 — 퍼짐각을 탄 수에 묶는다. 고정 24° 면 탄이 많을수록 정조준
			#    데미지가 커져 「덩어리를 많이 그리는 것」이 지배 전략이 됐다.
			box["angle_deg"] = scatter_spread_for(pellets)
		_:
			box["kind"] = "sphere"
			box["radius"] = w * 0.5
	return box


## 【2026-07-31 신설】 이 히트박스의 **유효 명중 폭**(m) — 형평성을 재는 자.
##
## 좌우 어디에 있을지 모르는 표적 하나를 상대로 한 기대 데미지는
##   기대 데미지 = damage × (이 폭 + 표적 지름)
## 이다. 탄이 여러 발이어도 (한 발 데미지 = damage/N) 라서 N 이 상쇄되고
## 퍼짐각과도 무관하다 — 즉 **이 한 값이 태그의 실전 세기를 전부 설명한다.**
## 【2026-07-31 개정】 이제 이 값이 **정규화 대상**이다. `hitbox_for` 가 만든 네 태그의
## 히트박스는 전부 이 함수에 넣으면 `effective_width_for(total_area)` 와 같은 값이 나온다.
## 그게 「어떤 그림을 그려도 한 명 상대 기대 데미지가 같다」의 정확한 뜻이다.
## QA 는 이 값을 기준으로 태그별 기대 데미지를 재측정할 것.
func effective_width(box: Dictionary) -> float:
	match String(box.get("kind", "sphere")):
		"capsule":
			return float(box.get("width", 0.0))
		"cone", "scatter":
			return 2.0 * float(box.get("pellet_radius", 0.0))
		_:
			return 2.0 * float(box.get("radius", 0.0))


## 【2026-07-31 신설】 이 히트박스가 **실제로** 차지하는 판정 면적의 합(m²).
## 폭 정규화 이후 이 값은 태그마다 다르다 — 형평성의 자가 아니라 **대가를 보여주는 값**이다.
## 제작창이 「판정 면적」으로 `total_area`(= 둥긂 기준값)를 그대로 띄우면 다탄 태그에서
## 거짓말이 된다. 이 함수를 쓸 것.
func hitbox_area(box: Dictionary) -> float:
	match String(box.get("kind", "sphere")):
		"capsule":
			var r: float = float(box.get("radius", 0.0))
			var l: float = float(box.get("length", 0.0))
			# 캡슐 = 가운데 직사각형 + 양끝 반원
			return maxf(l - 2.0 * r, 0.0) * (2.0 * r) + PI * r * r
		"cone", "scatter":
			var pr: float = float(box.get("pellet_radius", 0.0))
			return float(box.get("pellets", 1)) * PI * pr * pr
		_:
			var rr: float = float(box.get("radius", 0.0))
			return PI * rr * rr


## 【2026-07-31 신설】 **전탄 명중 유지 거리**(m).
## 이 거리 안에서는 완벽 조준 시 모든 탄이 표적에 들어가 명목 데미지가 그대로 나온다.
## 넘어가면 바깥 탄부터 빗나가 계단식으로 떨어진다.
##   유지 거리 = (탄 반경 + 표적 반경) / tan(퍼짐각 / 2)
## 퍼짐각이 0 이거나 단발이면 사거리 제한이 없다는 뜻으로 INF 를 돌려준다.
## 제작창이 「사거리」와 함께 이 값을 보여줘야 유저가 예측할 수 있다(기획서 87행).
func full_hit_distance(pellet_radius: float, spread_deg: float,
		target_radius: float = TARGET_RADIUS_REF) -> float:
	if spread_deg <= 0.0:
		return INF
	var half := tan(deg_to_rad(spread_deg * 0.5))
	if half <= 0.0:
		return INF
	return (pellet_radius + target_radius) / half


## 한 발이 실제로 넣는 데미지. 다단히트 태그는 나눠 들어간다.
##
## pellets 를 넘기면 그 수로 나눈다(0 = 태그 기본값). 그림에서 탄 수를 뽑는
## 미세 파라미터가 붙으면 **반드시** hitbox["pellets"] 와 같은 값을 넘겨야 한다.
## 안 그러면 총 데미지가 damage 와 어긋나 형평성이 깨진다.
func damage_per_hit(damage: float, tag: String, pellets: int = 0) -> float:
	if pellets > 0:
		return damage / float(pellets)
	match tag:
		TAG_SCATTER:
			return damage / float(SCATTER_PELLETS)
		TAG_SHARP:
			return damage / float(CONE_PELLETS)
		_:
			return damage
