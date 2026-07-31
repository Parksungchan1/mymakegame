# 개발실 현황판 — 작업 지침

`SkillCraftBattle` 프로젝트에서 **에이전트 6명이 실제로 무슨 일을 했는지** 보여주는 화면이다.
갓생맘 🎀 (@godseng.mom) 의 AI Office 를 가져와 고쳐 쓰고 있다. 화면 하단 크레딧은 지우지 않는다.

## 이 폴더의 핵심 원칙

**지어낸 값을 화면에 띄우지 않는다.**
표시되는 상태·문장·숫자는 전부 실제 git 커밋과 `reports/*.md`, `STATUS.md` 에서 나온다.
데이터가 없으면 "없음"이라고 쓴다. 그럴듯한 문장으로 채우지 않는다.

원본 AI Office 는 미리 써둔 대사를 랜덤 재생하는 연출이었다. 그 부분은 전부 걷어냈다.
되살리지 말 것: 출근·퇴근 시간, 하루 13단계 시나리오, 잡담 대사, 가짜 직원, Notion·Discord·Instagram·Gmail 연동.

## 지금 쓰는 파일

| 파일 | 역할 |
|---|---|
| `server/project-api.mjs` | Node 서버. git·reports·STATUS 를 읽어 JSON 으로 주고, 화면도 서빙한다. 의존성 0개 |
| `ui/index.html` | 화면 전부. CSS·JS 인라인, 외부 리소스 없음 |
| `company.config.ts` | 담당자 6명 정의 (참고용 — 현재 화면은 `ui/index.html` 안의 `LOOK`/`SEATS` 를 씀) |
| `개발실 열기.cmd` | 더블클릭 실행 |

## 실행

```
node server/project-api.mjs
```
→ http://localhost:3100

Node 22 이상 필요. 포트를 바꾸려면 `set PORT=3200` 후 실행.

## 화면에서 일 시키기

지시하기 칸에 할 일을 적고 담당자를 고르면 `claude -p` 가 실제로 돌아간다.

- **진행이 실시간으로 보인다.** `stream-json` 으로 도구 사용을 받아
  `Player.gd 읽음` / `Player.gd 고침` / `실행: git status` 같은 한 줄로 바꿔 쌓는다.
- **끝나면 자동으로 저장된다.** `[역할] 지시내용` 형태로 커밋하고 GitHub 에 푸시한다.
  태그가 붙으므로 담당자가 판정되고, 화면에서 대표실로 걸어가 보고한다.
- **한 번에 하나씩** 실행한다. 동시에 돌리면 같은 파일을 고쳐 충돌한다.
- 기본 권한은 `acceptEdits` (파일 수정만). `모든 권한 허용` 을 켜면 `bypassPermissions`
  로 명령 실행까지 맡긴다. 필요할 때만 켠다.
- 15분을 넘기면 중단한다.

### 알아둘 것 — 체크포인트 훅 충돌

`.claude/checkpoint.ps1` 은 `SessionEnd` 등에서 자동 커밋한다.
지시로 띄운 `claude -p` 가 끝날 때도 이 훅이 돌아서 **태그 없는
`checkpoint: auto-save` 커밋이 중복으로 생기던 문제**가 있었다.

→ 개발실이 지시를 띄울 때 `SKILLCRAFT_OFFICE_JOB=1` 환경변수를 넣고,
`checkpoint.ps1` 이 그 값을 보면 바로 빠져나가게 했다.
지시 작업의 커밋은 개발실 서버(`autoCommitJob`)가 태그를 붙여 직접 한다.

### 프롬프트는 반드시 stdin 으로

Windows 에서 한글을 명령줄 인자로 넘기면 Node 가 시스템 코드페이지로 인코딩해
`???` 로 깨진다. 프롬프트는 `child.stdin` 으로, git 커밋 메시지는 UTF-8 파일 + `-F` 로 넘긴다.
이건 이미 두 번 겪은 문제다. 인자로 바꾸지 말 것.

## 담당자 7명

`.claude/agents/<id>.md` 에 실제로 존재하는 에이전트만 올린다. 없는 사람은 만들지 않는다.

`pm` · `coordinator` · `game-designer` · `developer` · `designer` · `qa` · `auditor`

`auditor`(감시자)는 나중에 합류해서 한동안 개발실이 모르고 있었다. `[감시]` 태그를 단 커밋이
담당자 없이 뜨던 이유다. 새 에이전트를 추가하면 **여기 · `TAG_TO_AGENT` · `AGENT_TO_TAG` ·
`ui/index.html` 의 `SEATS`/`LOOK`/`ORDER`/담당자 select** 다섯 군데를 같이 고쳐야 한다.

커밋 메시지 앞의 `[역할]` 태그로 담당자를 찾는다 (`server/project-api.mjs` 의 `TAG_TO_AGENT`).
새 태그를 쓰기 시작하면 그 표에 추가해야 화면에 담당자가 뜬다.

## 아직 안 한 것

- 원본 React/Cloudflare 코드(`app/` `worker/` `db/` `drizzle/` `examples/` `build/` `tests/` 및
  `package.json` 등) 정리 — 현재 안 쓰지만 남겨둠. 새 화면이 충분히 검증되면 지운다.
- 작업 도중 취소 버튼 (지금은 15분 타임아웃뿐)
