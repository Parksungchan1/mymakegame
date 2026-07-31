// ============================================================
//  스킬크래프트 개발실 — 설정
// ============================================================
//  원본: 갓생맘 🎀 (@godseng.mom) 의 AI Office.
//  1인 개발자용 "실제로 일하는 에이전트 현황판"으로 고쳐 씀.
//
//  📌 원칙
//   1. 여기 있는 6명은 전부 .claude/agents/ 에 실제로 존재하는 에이전트다.
//      가짜 직원은 만들지 않는다. agentFile 이 실제 파일명이다.
//   2. 화면에 뜨는 상태·말풍선은 전부 실제 데이터(git 커밋 · reports/*.md)에서 온다.
//      아래 fallback 은 그 데이터가 아직 없을 때만 쓴다.
//   3. 부서 id 는 엔진(app/game/world.ts)의 방 배치와 묶여 있어 바꾸지 않는다.
//      12칸 중 6칸만 쓰고 나머지는 빈 자리로 둔다. 없는 팀을 있는 척하지 않는다.
// ============================================================

/** 이 사무실이 감시하는 실제 프로젝트 (office 폴더 기준 상대경로) */
export const PROJECT = {
  /** git 저장소 루트 */
  root: "..",
  /** 각 에이전트가 진행을 남기는 폴더 */
  reportsDir: "reports",
  /** 전체 현황판 */
  statusFile: "STATUS.md",
  /** 원격 저장소 */
  remoteUrl: "https://github.com/Parksungchan1/mymakegame",
  /** 상태를 다시 읽는 주기(초) */
  pollSeconds: 5,
} as const;

/** 회사 기본 정보 */
export const COMPANY = {
  name: "SKILLCRAFT STUDIO",
  logoLetter: "⚔",
  titlePrefix: "스킬크래프트",
  titleAccent: "개발실",
  pageTitle: "SkillCraft Studio — 개발실 현황판",
  description: "실제로 일하는 AI 에이전트 6명의 작업 현황판",
  windowLabel: "skillcraft_studio.exe — 대표실",
  reportName: "SkillCraft Studio",
} as const;

/** 대표(나) */
export const CEO_PROFILE = {
  name: "박대표", // ← 본인 이름으로 바꾸세요
  callsign: "대표님",
  role: "대표 · 최종 의사결정",
  hair: "#42283a",
  shirt: "#ff8fc0",
  accent: "#fff3b0",
  skin: "#ffdcc4",
  thoughts: [
    "결정은 내가 한다.",
    "재미없으면 아무리 잘 만들어도 소용없어.",
  ],
};

/**
 * 부서 12칸 중 실제로 쓰는 6칸.
 * id 는 엔진 고정값이라 바꾸지 않는다. name·icon·short·task·report 만 바꾼다.
 */
export const DEPARTMENTS = [
  {
    id: "strategy1",
    name: "기획",
    short: "design.doc",
    icon: "💡",
    task: "기획서 갱신 · 미결정 항목 정리",
    report: "결정된 것만 기획서에 반영합니다.",
  },
  {
    id: "reels",
    name: "개발",
    short: "godot.client",
    icon: "🎮",
    task: "Godot 구현 · 커밋",
    report: "기능 단위로 쪼개서 커밋합니다.",
  },
  {
    id: "carousel",
    name: "아트",
    short: "art.fx",
    icon: "🎨",
    task: "캐릭터 · 스킬 이펙트 리소스",
    report: "프로토타입 단계는 도형으로 갑니다.",
  },
  {
    id: "qa",
    name: "QA",
    short: "qa.check",
    icon: "🛡️",
    task: "빌드 실행 · 재현 확인",
    report: "재현 안 되는 버그는 올리지 않습니다.",
  },
  {
    id: "ops",
    name: "PM",
    short: "pm.plan",
    icon: "📅",
    task: "우선순위 결정 · 작업 분배",
    report: "로드맵 순서를 지킵니다.",
  },
  {
    id: "secretary",
    name: "코디네이터",
    short: "coordinator.hq",
    icon: "📋",
    task: "reports 종합 · STATUS.md 갱신",
    report: "모든 기록을 한 장으로 모읍니다.",
  },
] as const;

/** 아무도 없는 나머지 6칸. 화면에 "빈 자리"로 표시된다. */
export const EMPTY_DESKS = [
  { id: "research", label: "레퍼런스 조사" },
  { id: "brand", label: "밸런스 수치" },
  { id: "strategy2", label: "시스템 설계" },
  { id: "partner", label: "사운드" },
  { id: "finance", label: "빌드·배포" },
  { id: "review", label: "플레이테스트" },
] as const;

/**
 * 직원 = 실제 에이전트 6명.
 * agentFile = .claude/agents/<agentFile>.md — 이게 있어야 진짜 직원이다.
 * reportFile = reports/<reportFile>.md — 이 파일의 최근 갱신이 이 직원의 상태가 된다.
 * fallback = 실제 데이터가 아직 없을 때만 띄우는 한 줄. 잡담은 쓰지 않는다.
 */
export type StaffEntry = {
  dept: string;
  rank: "lead" | "member";
  name: string;
  role: string;
  colors: [string, string, string];
  thoughts: string[];
  callsign?: string;
  agentFile?: string;
  reportFile?: string;
};

export const STAFF_LIST: StaffEntry[] = [
  {
    dept: "ops", rank: "lead", name: "PM", callsign: "pm",
    role: "우선순위 결정 · 작업 분배",
    agentFile: "pm", reportFile: "pm",
    colors: ["#3b3b49", "#b8f0dd", "#b8f0dd"],
    thoughts: ["아직 배정된 작업이 없습니다."],
  },
  {
    dept: "secretary", rank: "lead", name: "코디네이터", callsign: "coordinator",
    role: "reports 종합 · STATUS.md 갱신",
    agentFile: "coordinator", reportFile: "coordinator",
    colors: ["#7a453c", "#c9b8ff", "#c9b8ff"],
    thoughts: ["종합할 기록이 아직 없습니다."],
  },
  {
    dept: "strategy1", rank: "lead", name: "기획", callsign: "game-designer",
    role: "게임 기획 · 밸런스 설계",
    agentFile: "game-designer", reportFile: "game-designer",
    colors: ["#c26e4b", "#ff8fc0", "#fff3b0"],
    thoughts: ["기획서 미결정 항목 6개 남음."],
  },
  {
    dept: "reels", rank: "lead", name: "개발", callsign: "developer",
    role: "Godot 구현",
    agentFile: "developer", reportFile: "developer",
    colors: ["#2c2638", "#ff8fc0", "#ff8fc0"],
    thoughts: ["Godot 프로젝트 생성 전입니다."],
  },
  {
    dept: "carousel", rank: "lead", name: "아트", callsign: "designer",
    role: "캐릭터 · 이펙트 리소스",
    agentFile: "designer", reportFile: "designer",
    colors: ["#d88d68", "#c9b8ff", "#c9b8ff"],
    thoughts: ["작업 요청 대기 중."],
  },
  {
    dept: "qa", rank: "lead", name: "QA", callsign: "qa",
    role: "검증 · 버그 리포트",
    agentFile: "qa", reportFile: "qa",
    colors: ["#2d4b46", "#b8f0dd", "#b8f0dd"],
    thoughts: ["검증할 빌드가 아직 없습니다."],
  },
];

/** 원본의 외부 연동 기능은 쓰지 않는다. 빈 값으로 둬서 화면에서 사라지게 한다. */
export const PENDING_INTEGRATIONS: Record<string, string> = {};

/** 결과물 보관함 = GitHub 저장소 */
export const STORAGE_LINK = PROJECT.remoteUrl;
