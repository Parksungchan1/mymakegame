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

## 담당자 6명

`.claude/agents/<id>.md` 에 실제로 존재하는 에이전트만 올린다. 없는 사람은 만들지 않는다.

`pm` · `coordinator` · `game-designer` · `developer` · `designer` · `qa`

커밋 메시지 앞의 `[역할]` 태그로 담당자를 찾는다 (`server/project-api.mjs` 의 `TAG_TO_AGENT`).
새 태그를 쓰기 시작하면 그 표에 추가해야 화면에 담당자가 뜬다.

## 아직 안 한 것

- 화면에서 지시 → Claude Code 헤드리스(`claude -p`) 실제 실행 (3단계)
- 원본 React/Cloudflare 코드(`app/` `worker/` `db/` `drizzle/` `examples/` `build/` `tests/` 및
  `package.json` 등) 정리 — 현재 안 쓰지만 남겨둠. 새 화면이 충분히 검증되면 지운다.
