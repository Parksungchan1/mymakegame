# 프로젝트 진행 현황판 (STATUS)

> 코디네이터가 관리. 각 reports/*.md를 종합해 최신화. 이 한 장으로 전체 진행 파악.
> 최종 갱신: 2026-07-31

## 📌 다음 세션에서 가장 먼저 할 일
0. **새 컴퓨터라면** — `README.md` 를 먼저 본다. `setup.ps1` 한 번이면 환경이 다 깔린다.
1. **개발실을 켜고 거기서 일을 시킨다** — `개발실 열기.cmd` → http://localhost:3100
2. **로드맵 1단계 직접 플레이 확인** — Godot 에디터로 `game/` 열고 F5.
   3D 3인칭 이동/점프 감각을 직접 움직여봐야 안다. 어색하면 지시창으로 조정.
3. **로드맵 2단계(고정 스킬 1개 발사)를 건너뛰지 말 것.** 크래시 세션이 여기를
   건너뛰고 3b(그림판)까지 질러놨다. 순서대로 되돌아와서 2단계부터 한다.

## ✅ 완료
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
  - Godot 4 프로젝트 생성, 방향키 이동 + 스페이스 홉(탑다운 회피용)
  - `--headless` 로 임포트·실행 검증 완료. 오류 없음
  - 현재 값: speed 280 / hop_height 40 (지시창으로 조정한 결과)
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
- [ ] 로드맵 1단계 조작감 다듬기 (직접 플레이 후 판단)
- [ ] 로드맵 2단계: 고정 스킬 1개 발사
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
- Git 설치됨 (`C:\Program Files\Git`), 시스템 PATH 등록됨
- 원격: `origin` → https://github.com/Parksungchan1/mymakegame.git (인증 완료 상태)
- Godot 4.7.1: `Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe` (무설치)
- Node.js: v24.18.1 (`C:\Program Files\nodejs`) / 무설치 v22.22.0 (`C:\Users\k\nodejs-portable`)
- **Windows 주의**: 한글을 Node 에서 명령줄 인자로 넘기면 시스템 코드페이지로 인코딩돼
  `???` 로 깨진다. git 커밋 메시지는 UTF-8 파일 + `-F`, claude 프롬프트는 stdin 으로 넘긴다.
  (커밋 `5ad68cb` 이 이 버그로 깨진 채 남아 있음)
- **체크포인트 훅**: `SKILLCRAFT_OFFICE_JOB=1` 이면 `checkpoint.ps1` 이 커밋을 건너뛴다.
  개발실 지시 작업은 서버가 `[역할]` 태그를 붙여 직접 커밋하기 때문.
- **과금**: API 키 없이 계정 로그인(OAuth) 방식이라 지시 실행은 구독 사용량을 소모한다.
  화면의 `$0.xx` 는 실제 청구액이 아니라 작업 무게를 가늠하는 환산값. 플랜 확인은 `/status`.
- 원본 지시서 `바탕화면\SETUP_스킬크래프트배틀.docx`는 역할을 다함. 삭제 가능.
