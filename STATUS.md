# 프로젝트 진행 현황판 (STATUS)

> 코디네이터가 관리. 각 reports/*.md를 종합해 최신화. 이 한 장으로 전체 진행 파악.
> 최종 갱신: 2026-07-31

## 📌 다음 세션에서 가장 먼저 할 일
0. **새 컴퓨터라면** — `README.md` 를 먼저 본다. `setup.ps1` 한 번이면 환경이 다 깔린다.
1. **1·2단계를 직접 플레이해서 확인한다** — `게임 열기.cmd` → **F5**.
   여기서만 알 수 있는 게 두 가지다. 코드로는 판단이 안 된다.
   - **이동/점프 감각** (멧챠 카멜레온풍인가? `move_speed 6.0` / `jump_height 1.2`)
   - **Q 발사 손맛** — 특히 **쿨타임 4.94초가 너무 긴지**. 예산 공식이 뱉은 값
     그대로라 개발이 임의로 줄이지 않았다. 길면 기획 담당이 `Balance.gd` 를 조정한다.
2. 어색한 게 있으면 **개발실 지시창**으로 고친다 — `개발실 열기.cmd` → http://localhost:3100
3. 손맛이 잡히면 **로드맵 3a(수치 슬라이더만)** 로 넘어간다.
   `SkillEditor.gd` 는 이미 3b(그림판)까지 만들어져 있지만, **3a 가 돌아가고 재미가
   확인된 뒤에 3b 를 붙인다**는 기획서 87~88행 순서를 지킨다.

## ✅ 완료
- **🔫 로드맵 2단계: 고정 스킬 1개 발사** (2026-07-31) — 크래시 세션이 건너뛴 자리를 되돌아와 채움
  - `Projectile.gd`(새 파일) — 투사체. 속도·사거리·판정 반경·데미지를 스스로 정하지 않고
    `Balance.derive()` 결과를 받아 쓴다. 히트박스는 **둥긂(구체) 하나만** — 나머지 3종은 3단계에서
  - `Dummy.gd`(새 파일) — 허수아비 3개. 맞으면 체력이 줄고 머리 위 숫자가 바뀐다. 봇이 아니다
  - `Player.gd` — Q → 발동시간(0.31초) → 발사 → 쿨타임(4.94초). 셋 다 Balance 가 정한 값
  - `Player.tscn` — 마법봉 추가(기획서 12행). 투사체는 봉 끝에서 나간다
  - **3단계 코드를 일부러 안 썼다.** 수치는 `Player.gd` 에 직접 박음 — 2단계가 3단계에
    기대면 로드맵을 건너뛴 것과 같다. 3단계에서 `SkillDB.get_slot("Q")` 로 갈아끼우면 된다
  - 🐞 **버그 수정: 캐릭터가 뒤를 보고 달렸다.** `_face()` 가 몸의 +Z 를 진행 방향에 맞췄는데
    Godot 의 앞은 -Z 고 얼굴 메시도 -Z 에 붙어 있었다. 발사 방향이 걸려서 같이 고침
  - 🐞 **Godot 함정**: `Projectile` 에 `monitorable = false` 를 주면 브로드페이즈가 그 Area 를
    정적으로 취급해 **StaticBody3D 와 아예 짝을 안 만든다** → 영영 안 맞는다. 상세는 `reports/developer.md`
  - 검증: 헤드리스로 명중(체력 100→78) · 투사체 정리 · Q 입력→발사 · 쿨타임 중 재발사 차단 전부 확인
  - 감시자 판정 **통과** (허수아비는 검증용 표적으로 사유 남기고 통과) — `reports/auditor.md`
- **🩹 새 환경 Node 탐지 오탐 수정** (2026-07-31)
  - 증상: Node 24 가 멀쩡히 깔려 있는데 `env-check.ps1` 이 "셋업 안 끝났다 — Node.js 22+ (지금 v0)"
    를 매 세션 띄움. 그대로 두면 새 세션마다 CLAUDE.md 절차에 따라 셋업을 다시 물어보게 된다
  - 원인: `C:\Windows\System32\node` 라는 **확장자 없는 0바이트 파일**. PowerShell 은 이걸
    먼저 실행해 버전이 빈 값으로 나온다. (cmd 는 PATHEXT 때문에 건너뛰어서 `개발실 열기.cmd` 는 멀쩡했음)
  - 조치: `env-check.ps1` · `setup.ps1` 이 `node` 대신 **`node.exe`** 로 찾도록 수정
- **🚦 새 세션 자동화 연결** (2026-07-31) — 새 클로드가 환경 셋업부터 알아서
  - 구멍이 있었다: `CLAUDE.md` 는 세션마다 자동으로 읽히는데 `setup.ps1`·`README.md`
    얘기가 없어서, 새 환경의 Claude 가 "셋업이 필요하다"는 걸 몰랐음
  - `.claude/env-check.ps1` + `SessionStart` 훅 — Node22+ / Claude Code CLI / Godot /
    `game/.godot` 임포트를 점검해, 빠진 게 있으면 **Claude 컨텍스트에 직접** 경고를 넣는다
  - `CLAUDE.md` 「세션 시작 절차」 — 환경점검 → `STATUS.md` → 작업 순서 못 박음
  - `CLAUDE.md` 「담당 배정은 알아서 한다」 — 요청 성격별 담당 표, 연쇄 위임 순서
    (`game-designer`→`developer`→`auditor`→`coordinator`), 동시 실행 규칙
  - **자동/수동 경계 명시** — 담당 배정·환경점검·저장·개발실 보고는 자동.
    단 **에이전트가 스스로 일을 시작하진 않는다.** 첫 방아쇠는 사용자나 개발실 지시창
  - 검증: 새 클론에서 `⚠ 셋업 안 끝났다` 정상 감지, 현재 환경에서 `이상 없음` 정상
- **📦 새 환경 원클릭 셋업** (2026-07-31) — 컴퓨터가 꺼져도 다른 데서 바로 이어간다
  - `README.md` — 저장소 첫 화면. 클론 → 셋업 → 켜기 5분 가이드, 폴더 지도,
    에이전트 7명 표, 작업 안 날리는 3중 장치, Windows 함정 정리
  - `setup.ps1` — 6단계 자동 점검/설치: Git · Node 22+ · Claude Code CLI ·
    Godot 4.7.1(`tools\Godot\` 에 무설치 자동 다운로드) · git 사용자 정보 ·
    `--headless --import` 검증까지. **이 컴퓨터에서 끝까지 실행해 검증 완료**
  - `개발실 열기.cmd` (루트) · `게임 열기.cmd` — 더블클릭 실행. Godot 은
    `tools\Godot` → 예전 Downloads 경로 → PATH 순으로 찾는다
  - `.gitignore` 에 `/tools/` 추가 (Godot 80MB 는 저장소에 안 올림)
  - 검증: 개발실 서버 HTTP 200 · `/api/project` 200 확인
- **✅ 결정: 카메라 고정 각도** (2026-07-31, 사용자 확정)
  - 화면이 도는 일 없음. 마우스룩·마우스 캡처 전부 제거
  - `Player.gd`: `CamYaw`(마우스로 회전) → `CamPivot`(고정각). 노출값
    `cam_yaw_deg` 0° / `cam_pitch_deg` -32° / `cam_distance` 7m
  - 방향키는 고정된 화면 기준으로 매핑 → ↑는 언제나 화면 위쪽
  - `SkillEditor.gd`: 창을 닫을 때 마우스를 다시 잡던 코드 제거
  - `docs/게임기획.md` 에 `✅ 결정됨` 으로 기록 + 「넣지 않는 것」 표에 마우스룩 추가
- **🛡 감시자(auditor) 에이전트 도입** (2026-07-31) — 기획 이탈 방지
  - `.claude/agents/auditor.md` — 다른 담당의 결과물이 기획서와 맞는지만 검사하는 감사관
  - 검사 4종: ①기획서에 없는 기능 추가 ②`✅ 결정됨` 무단 변경 ③로드맵 순서 건너뜀
    ④문서-코드 불일치. 판정은 `통과` / `반려` 둘 중 하나
  - 직접 고치지 않고 담당에게 넘긴다. 기준 문서도 못 고친다(사용자만 가능)
  - `CLAUDE.md`에 「기획 이탈 방지」 절 추가 — 작업 묶음마다 감시자를 거치도록 규칙화
- **✅ 결정: 3D 3인칭 확정 + 배그 요소 제거** (2026-07-31, 사용자 확정)
  - **프로토타입부터 3D 3인칭.** 2D 탑다운 안은 폐기
  - 움직임은 **멧챠 카멜레온풍**, 이동은 **방향키(화살표)** 전용, 점프 스페이스
  - 크래시 세션이 넣었던 **배그식 조작 전부 제거**: 우클릭 조준(ADS), 어깨너머 줌,
    조준 중 감속, 스프린트 → `Player.gd` 재작성 + `project.godot`에서 `aim`/`sprint` 입력 삭제
  - 기획서의 "배그처럼"은 **자기장(안전구역 축소) 한 곳에만** 해당함을 문서에 명시
  - 문서 6곳 정정: `게임기획.md` `CLAUDE.md` `agents/{pm,developer,coordinator}.md` `STATUS.md`
  - Godot `--headless --import` 검증 통과(오류 없음)
- **개발실에서 직접 일 시키기** (2026-07-31) — 3단계 완료
  - 화면의 지시창에 할 일을 적고 담당자를 고르면 `claude -p` 가 실제로 실행됨
  - **진행이 실시간으로 보임** — `Player.gd 읽음 → 고침 → 완료` 식으로 단계가 쌓임
  - 끝나면 `[역할] 지시내용` 으로 자동 커밋·푸시 → 담당자 판정 → 대표실 보고
  - 검증: `hop_height 34→40` 지시가 18초에 완료, 21초에 GitHub 저장까지 확인
  - 기본 권한 `acceptEdits`(파일 수정만). `모든 권한 허용` 체크 시 명령 실행까지
  - 글자 크기 전반 상향 (본문 14→16px 등)
- **로드맵 1단계 착수** (2026-07-31) — `game/`
  - Godot 4 프로젝트 생성, 방향키 이동 + 스페이스 점프
  - `--headless` 로 임포트·실행 검증 완료. 오류 없음
  - 현재 값: `move_speed 6.0` m/s · `jump_height 1.2` m
    (2D 때의 `speed 280 / hop_height 40` 은 px 단위라 3D 전환 때 폐기됨)
- **개발실 현황판 구축** (2026-07-31) — `office/`
  - 갓생맘(@godseng.mom) AI Office 를 가져와 개조. 원본은 미리 써둔 대사를 재생하는
    연출이었고 LLM 호출이 0건이라, 실제 데이터를 읽는 현황판으로 방향을 바꿈
  - `office/server/project-api.mjs` — git log · reports/*.md · STATUS.md 를 읽는
    Node 서버(의존성 0개). 저장→커밋→GitHub 푸시 API 포함
  - `office/ui/index.html` — 사무실 화면. 새 커밋이 감지되면 담당자가 대표실로
    걸어가 실제 커밋 메시지로 보고
  - 커밋 메시지의 `[역할]` 태그로 담당자 자동 판정 (`[기획]`→game-designer 등)
  - 실행: `office\개발실 열기.cmd` 더블클릭 → http://localhost:3100
  - 걷어낸 것: 출근·퇴근 시계, 하루 13단계 시나리오, 잡담 대사, 가짜 직원 32명,
    Notion·Discord·Instagram·Gmail 연동
- **개발 환경 준비 완료** (2026-07-31)
  - Godot 4.7.1 (무설치 exe, Downloads 폴더)
  - Node.js v24.18.1 (`C:\Program Files\nodejs`) + 무설치 v22.22.0 (`C:\Users\k\nodejs-portable`)
- **GitHub 원격 연결 + 첫 push** (2026-07-31)
  - 저장소: https://github.com/Parksungchan1/mymakegame (main 브랜치 추적 중)
  - 이제 자동 체크포인트 훅의 push도 정상 동작함
- **결정: 그림의 역할 = 하이브리드** (2026-07-31)
  - 그림은 겉모습 + 히트박스 "형태 태그"까지. 세기는 수치 슬라이더 전담.
  - 대원칙: 총 유효 판정 면적은 `범위` 값으로 정규화 → 그림으로 세지게 만들 수 없음(악용 차단)
  - 형태 태그 4종: 길쭉함 / 둥긂(기본) / 뾰족함 / 흩어짐 — 상세는 `docs/게임기획.md`
  - 로드맵 3단계를 3a(수치 슬라이더만) / 3b(그림판+태그 추출)로 분리
- 프로젝트 셋업 (2026-07-31)
  - 위치: `C:\Users\k\SkillCraftBattle`
  - 에이전트 6종: pm / coordinator / designer / game-designer / developer / qa
  - Git 자동저장 훅 3종 (SubagentStop / PreCompact / SessionEnd) + `.claude/checkpoint.ps1`
  - 기획서 `docs/게임기획.md`, 규칙 `CLAUDE.md`, `.gitignore`
- Git 초기화 + main 브랜치 + 첫 커밋 `init: 프로젝트 셋업 + 에이전트 + 자동 체크포인트`

## 🔧 진행 중
- (없음)

## ⏭ 다음 할 일
- [ ] **직접 플레이 후 판단** — 이동/점프 감각, 그리고 Q 쿨타임 4.94초가 적절한지
- [ ] 밸런스: 위 플레이 결과에 따라 `Balance.COOLDOWN_MIN/MAX` 조정 여부 결정
- [ ] 로드맵 3a: 스킬 에디터에서 **수치 슬라이더만** 먼저 돌려보기 (그림판 3b 는 그 다음)
- [ ] 2단계 후속: 나머지 히트박스 3종(길쭉함·뾰족함·흩어짐) — 3단계에서 에디터와 함께
- [ ] 새 화면 검증 끝나면 `office/` 의 안 쓰는 원본 코드 정리
      (`app/` `worker/` `db/` `drizzle/` `examples/` `build/` `tests/` `package*.json` 등)
- [ ] 밸런스: 형태 태그 판정 임계값(종횡비·복잡도 등) 수치 확정 — 3b 착수 전까지
- [ ] 개발실: 작업 도중 취소 버튼 (지금은 15분 타임아웃뿐)

## ⛔ 막힌 것 / 결정 대기
- (없음)

## 🗒 셋업 시 지시서와 다르게 처리한 것 (기록용)
1. **프로젝트 위치**: 지시서는 "SETUP 파일이 있는 폴더(=바탕화면)"를 루트로 쓰라고 했으나, 바탕화면에 신분증·통장 사본 파일이 있어 GitHub에 유출될 위험이 있었음. 사용자 확인 후 `C:\Users\k\SkillCraftBattle`로 분리.
2. **`.claude/settings.json` 훅 형식**: 지시서 원본은 `"command": "powershell.exe"` + 별도 `"args"` 배열이었으나, Claude Code 훅은 `args` 필드를 인식하지 않아 스크립트가 실행되지 않음. 한 줄 명령으로 병합함:
   `"command": "powershell.exe -ExecutionPolicy Bypass -File .claude/checkpoint.ps1"`
3. **Git 사용자 정보**: 커밋에 필요해 이 저장소에만(local) `wfs070809 / wfs070809@gmail.com` 설정. 변경 원하면 `git config user.name "새이름"`.

## 🔎 환경 메모
- Git 설치됨, 시스템 PATH 등록됨
- 원격: `origin` → https://github.com/Parksungchan1/mymakegame.git (인증 완료 상태)
- Godot 4.7.1: `tools\Godot\Godot.exe` (setup.ps1 이 받아둔 무설치본. 저장소에는 안 올림)
- Node.js: v24.18.1

### 컴퓨터 2대에서 작업 중 (2026-07-31)
| | 경로 | 비고 |
|---|---|---|
| 1호기 | `C:\Users\k\SkillCraftBattle` | 처음 만든 곳 |
| 2호기 | `C:\Users\parks\SkillCraftBattle` | 클론 + `setup.ps1` 로 5분 만에 이어받음 |

- **2호기 주의**: `C:\Windows\System32\node` 에 확장자 없는 0바이트 파일이 있다.
  PowerShell 이 진짜 `node.exe` 대신 이걸 먼저 실행한다(cmd 는 영향 없음).
  점검 스크립트는 `node.exe` 로 찾도록 고쳐서 지금은 문제없지만,
  PowerShell 에서 `node` 를 직접 부르는 코드를 새로 쓸 거면 `node.exe` 로 쓴다.
  관리자 권한으로 그 빈 파일을 지우면 근본 해결된다: `Remove-Item C:\Windows\System32\node -Force`
- **Windows 주의**: 한글을 Node 에서 명령줄 인자로 넘기면 시스템 코드페이지로 인코딩돼
  `???` 로 깨진다. git 커밋 메시지는 UTF-8 파일 + `-F`, claude 프롬프트는 stdin 으로 넘긴다.
  (커밋 `5ad68cb` 이 이 버그로 깨진 채 남아 있음)
- **체크포인트 훅**: `SKILLCRAFT_OFFICE_JOB=1` 이면 `checkpoint.ps1` 이 커밋을 건너뛴다.
  개발실 지시 작업은 서버가 `[역할]` 태그를 붙여 직접 커밋하기 때문.
- **과금**: API 키 없이 계정 로그인(OAuth) 방식이라 지시 실행은 구독 사용량을 소모한다.
  화면의 `$0.xx` 는 실제 청구액이 아니라 작업 무게를 가늠하는 환산값. 플랜 확인은 `/status`.
- 원본 지시서 `바탕화면\SETUP_스킬크래프트배틀.docx`는 역할을 다함. 삭제 가능.
