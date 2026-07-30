# 프로젝트 진행 현황판 (STATUS)

> 코디네이터가 관리. 각 reports/*.md를 종합해 최신화. 이 한 장으로 전체 진행 파악.
> 최종 갱신: 2026-07-31

## 📌 다음 세션에서 가장 먼저 할 일
1. **GitHub 저장소 주소 받기** → `git remote add origin <주소>` → `git push -u origin main`
   (아직 원격 저장소 연결 전이라 백업은 로컬에만 있음)
2. **결정: 그림 = 판정 vs 겉모습** — 이게 정해져야 스킬 에디터 설계 시작 가능. 추천 A안(겉모습)

## ✅ 완료
- 프로젝트 셋업 (2026-07-31)
  - 위치: `C:\Users\k\SkillCraftBattle`
  - 에이전트 6종: pm / coordinator / designer / game-designer / developer / qa
  - Git 자동저장 훅 3종 (SubagentStop / PreCompact / SessionEnd) + `.claude/checkpoint.ps1`
  - 기획서 `docs/게임기획.md`, 규칙 `CLAUDE.md`, `.gitignore`
- Git 초기화 + main 브랜치 + 첫 커밋 `init: 프로젝트 셋업 + 에이전트 + 자동 체크포인트`

## 🔧 진행 중
- (없음)

## ⏭ 다음 할 일
- [ ] GitHub 저장소 생성 + 첫 push (Private 권장, README/gitignore/license 체크 해제)
- [ ] 결정: 그림 = 판정 vs 겉모습 (docs/게임기획.md) — 추천 A안(겉모습)
- [ ] Godot 4 설치 및 프로젝트 첫 세팅
- [ ] 캐릭터 방향키 이동 + 스페이스 점프 (로드맵 1단계)

## ⛔ 막힌 것 / 결정 대기
- **GitHub 저장소 주소 미확보** → 원격 백업 불가, 자동 체크포인트 훅의 push도 실패함(커밋은 정상)
- **그림 판정 방식 미결정** → 스킬 에디터 설계 착수 전 필요

## 🗒 셋업 시 지시서와 다르게 처리한 것 (기록용)
1. **프로젝트 위치**: 지시서는 "SETUP 파일이 있는 폴더(=바탕화면)"를 루트로 쓰라고 했으나, 바탕화면에 신분증·통장 사본 파일이 있어 GitHub에 유출될 위험이 있었음. 사용자 확인 후 `C:\Users\k\SkillCraftBattle`로 분리.
2. **`.claude/settings.json` 훅 형식**: 지시서 원본은 `"command": "powershell.exe"` + 별도 `"args"` 배열이었으나, Claude Code 훅은 `args` 필드를 인식하지 않아 스크립트가 실행되지 않음. 한 줄 명령으로 병합함:
   `"command": "powershell.exe -ExecutionPolicy Bypass -File .claude/checkpoint.ps1"`
3. **Git 사용자 정보**: 커밋에 필요해 이 저장소에만(local) `wfs070809 / wfs070809@gmail.com` 설정. 변경 원하면 `git config user.name "새이름"`.

## 🔎 환경 메모
- Git 설치됨 (`C:\Program Files\Git`), 시스템 PATH 등록됨
- Godot 4: 아직 설치 안 됨 → https://godotengine.org/download/windows/
- 원본 지시서 `바탕화면\SETUP_스킬크래프트배틀.docx`는 역할을 다함. 삭제 가능.
