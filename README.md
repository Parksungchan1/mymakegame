# 스킬 크래프트 배틀 (SkillCraft Battle)

> 유저가 **그림판에서 직접 스킬을 그려** QWER 4칸에 세팅하고, 5:5로 겨루는
> **3D 3인칭 실시간 대전 게임**. 엔진은 Godot 4.

이 저장소에는 게임뿐 아니라, **게임을 만드는 AI 팀(에이전트 6명)** 과
**그 팀이 뭘 했는지 눈으로 보는 화면(개발실)** 까지 통째로 들어 있다.
새 컴퓨터에서 클론 → `setup.ps1` 한 번이면 이어서 작업할 수 있다.

---

## 🚀 새 컴퓨터에서 시작하기 (5분)

### 1. 클론

PowerShell 을 열고:

```powershell
git clone https://github.com/Parksungchan1/mymakegame.git SkillCraftBattle
cd SkillCraftBattle
```

> Git 이 없으면 먼저 설치: `winget install Git.Git` (설치 후 PowerShell 새로 열기)

### 2. 셋업 스크립트 실행

```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

이게 알아서 다 확인하고 없는 건 깔아준다:

| 확인/설치 | 무엇 |
|---|---|
| Git | 커밋·푸시용 |
| Node.js 22+ | 개발실 화면 서버 |
| Claude Code CLI | AI 에이전트 실행 (`npm i -g @anthropic-ai/claude-code`) |
| Godot 4.7.1 | 게임 엔진 — `tools\Godot\` 에 무설치로 자동 다운로드 |
| git 사용자 정보 | 없으면 이 저장소에만 설정 |

### 3. 로그인 (한 번만)

```powershell
claude
```

브라우저가 열리면 계정 로그인. 그다음 `/exit`.

### 4. 켜기

| 하고 싶은 것 | 더블클릭 |
|---|---|
| **개발실 보기 / AI한테 일 시키기** | `개발실 열기.cmd` → http://localhost:3100 |
| **게임 직접 해보기** | `게임 열기.cmd` → Godot 에디터에서 **F5** |
| **AI 와 대화하며 작업** | 이 폴더에서 `claude` |

끝. 여기까지가 새 환경 세팅 전부다.

---

## 📁 폴더 지도

```
SkillCraftBattle/
├─ README.md            ← 지금 이 파일 (새 환경 시작점)
├─ setup.ps1            ← 환경 자동 셋업
├─ STATUS.md            ← 📌 진행 현황판. 새 세션은 여기부터 읽는다
├─ CLAUDE.md            ← AI가 세션마다 자동으로 읽는 프로젝트 규칙
│
├─ docs/게임기획.md      ← 기준 문서. ✅ 결정됨 항목은 사용자만 바꾼다
│
├─ game/                ← Godot 4 게임 본체
│  ├─ project.godot
│  ├─ scenes/           Arena.tscn · Player.tscn
│  └─ scripts/          Player.gd · skill/
│
├─ office/              ← 개발실 (로컬 현황판 + 지시 창구)
│  ├─ server/project-api.mjs   Node 서버, 의존성 0개
│  ├─ ui/index.html            화면 전부 (인라인 CSS·JS)
│  └─ CLAUDE.md                개발실 작업 지침
│
├─ reports/             ← 각 담당이 남기는 진행 메모
└─ .claude/
   ├─ agents/           ← 🤖 AI 에이전트 7명 정의
   ├─ settings.json     ← 자동 저장 훅 3종
   └─ checkpoint.ps1    ← 자동 커밋·푸시 스크립트
```

---

## 🤖 AI 에이전트 7명

`.claude/agents/*.md` 에 정의돼 있다. 클론하면 그대로 따라온다.

| id | 역할 | 하는 일 |
|---|---|---|
| `pm` | PM | STATUS.md 보고 우선순위 정해 분배 |
| `coordinator` | 코디네이터 | reports/*.md 모아 STATUS.md 최신화 |
| `game-designer` | 기획/밸런스 | 게임기획.md 관리, 수치 결정 |
| `designer` | 디자인 | 화면·아트 방향 |
| `developer` | 개발 | Godot/GDScript 구현 |
| `qa` | QA | 검증·버그 |
| `auditor` | 🛡 감시자 | **기획 이탈 감사** — 기획서에 없는 기능, `✅ 결정됨` 무단 변경, 로드맵 건너뜀, 문서-코드 불일치를 `통과`/`반려` 로 판정 |

부르는 법 — `claude` 안에서:

```
developer 에이전트로 Player.gd 의 이동 속도를 300 으로 바꿔줘
```

또는 **개발실 화면의 지시창**에 적고 담당자를 고르면 `claude -p` 가 실제로 실행된다.

---

## 🏢 개발실 (로컬 현황판)

`개발실 열기.cmd` → http://localhost:3100

- **지어낸 값을 띄우지 않는다.** 화면의 모든 문장·숫자는 실제 `git log` ·
  `reports/*.md` · `STATUS.md` 에서 나온다. 데이터가 없으면 "없음" 이라고 쓴다.
- **일을 시킬 수 있다.** 지시창에 할 일을 적고 담당자를 고르면 `claude -p` 가 돌고,
  진행이 `Player.gd 읽음 → 고침 → 완료` 식으로 실시간으로 쌓인다.
- **끝나면 자동 저장.** `[역할] 지시내용` 으로 커밋 → GitHub 푸시 → 담당자가
  대표실로 걸어가 보고.
- 기본 권한은 `acceptEdits`(파일 수정만). `모든 권한 허용` 을 켜면 명령 실행까지.
- 한 번에 하나씩. 동시에 돌리면 같은 파일을 고쳐 충돌한다.

포트를 바꾸려면: `set PORT=3200` 후 `node office/server/project-api.mjs`

---

## 💾 작업이 사라지지 않게 하는 장치

크래시로 작업을 날리지 않으려고 3중으로 걸어놨다.

1. **자동 체크포인트 훅** — `.claude/settings.json` 이 서브에이전트 종료 /
   컨텍스트 정리 직전 / 세션 종료 시 `.claude/checkpoint.ps1` 을 돌려 자동 커밋·푸시.
2. **개발실 지시 자동 커밋** — 지시 작업이 끝나면 `[역할]` 태그를 붙여 서버가 직접 커밋·푸시.
   (이때 `SKILLCRAFT_OFFICE_JOB=1` 이 걸려 훅은 건너뛴다 — 중복 커밋 방지)
3. **STATUS.md** — 컨텍스트가 날아가도 이 한 장이면 다음 세션이 이어서 시작한다.

**그래서 컴퓨터가 꺼져도 GitHub 에 남아 있다.** 새 환경에서 클론하면 그대로 이어진다.

---

## ⚠️ Windows 에서 겪은 함정 (다시 밟지 말 것)

- **한글을 명령줄 인자로 넘기면 깨진다.** Node 가 시스템 코드페이지로 인코딩해서 `???`
  가 된다. → git 커밋 메시지는 **UTF-8 파일 + `-F`**, claude 프롬프트는 **stdin** 으로.
  (커밋 `5ad68cb` 이 이 버그로 깨진 채 남아 있음)
- **훅 설정에 `args` 배열은 안 먹는다.** `"command"` 한 줄에 다 넣어야 실행된다.
- **`.cmd` 파일은 UTF-8 + `chcp 65001`** 이어야 한글이 안 깨진다.

---

## 다음에 할 일

`STATUS.md` 의 **「📌 다음 세션에서 가장 먼저 할 일」** 을 본다. 항상 거기가 최신이다.

---

## 크레딧

개발실 화면은 **갓생맘 🎀** ([@godseng.mom](https://www.instagram.com/godseng.mom/)) 의
AI Office 를 가져와 실제 데이터 현황판으로 개조한 것이다. 하단 크레딧은 지우지 않는다.
