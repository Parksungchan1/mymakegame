# 프로젝트 진행 현황판 (STATUS)

> 코디네이터가 관리. 각 reports/*.md를 종합해 최신화. 이 한 장으로 전체 진행 파악.
> 최종 갱신: 2026-07-31

## 📌 다음 세션에서 가장 먼저 할 일
1. **Godot 프로젝트 첫 세팅** → 로드맵 1단계(이동+점프)
   Godot 4.7.1 준비됨: `C:\Users\k\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe`
   프로젝트 위치는 `SkillCraftBattle\game\` 권장

## ✅ 완료
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
- [ ] Godot 프로젝트 첫 세팅 (`SkillCraftBattle\game\`)
- [ ] 개발실 3단계: 화면에서 지시 → Claude Code 헤드리스 실제 실행
- [ ] 새 화면 검증 끝나면 `office/` 의 안 쓰는 원본 코드 정리
      (`app/` `worker/` `db/` `drizzle/` `examples/` `build/` `tests/` `package*.json` 등)
- [ ] 캐릭터 방향키 이동 + 스페이스 점프 (로드맵 1단계)
- [ ] 밸런스: 형태 태그 판정 임계값(종횡비·복잡도 등) 수치 확정 — 3b 착수 전까지

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
- **Windows 주의**: `git commit -m "한글"` 을 Node 의 execFile 로 넘기면 인자가 시스템
  코드페이지로 인코딩돼 `???` 로 깨진다. UTF-8 파일에 써서 `-F` 로 넘겨야 한다.
  (커밋 `5ad68cb` 이 이 버그로 깨진 채 남아 있음)
- 원본 지시서 `바탕화면\SETUP_스킬크래프트배틀.docx`는 역할을 다함. 삭제 가능.
