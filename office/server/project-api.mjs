// ============================================================
//  프로젝트 현황 API — 의존성 0개, Node 표준 모듈만 사용
// ============================================================
//  사무실 화면에 띄울 "진짜 데이터"를 만든다.
//  지어내는 값은 하나도 없다. 없으면 없다고 보낸다.
//
//  실행:  node server/project-api.mjs
//  확인:  http://localhost:3100/api/project
// ============================================================

import { createServer } from "node:http";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { readFile, readdir, stat } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const run = promisify(execFile);

const HERE = dirname(fileURLToPath(import.meta.url));
/** office/server → office → SkillCraftBattle */
const ROOT = resolve(HERE, "..", "..");
const PORT = Number(process.env.PORT ?? 3100);

/**
 * 커밋 메시지 앞의 [태그] → 담당 에이전트.
 * CLAUDE.md 의 커밋 규칙(`[역할] 무엇을 했는지`)과 맞춰야 한다.
 */
const TAG_TO_AGENT = {
  pm: "pm",
  PM: "pm",
  코디: "coordinator",
  코디네이터: "coordinator",
  기획: "game-designer",
  밸런스: "game-designer",
  개발: "developer",
  구현: "developer",
  아트: "designer",
  디자인: "designer",
  qa: "qa",
  QA: "qa",
  검증: "qa",
};

const AGENTS = ["pm", "coordinator", "game-designer", "developer", "qa", "designer"];

/** git 명령 실행. 실패해도 서버가 죽지 않게 null 을 돌려준다. */
async function git(args) {
  try {
    const { stdout } = await run("git", args, { cwd: ROOT, maxBuffer: 4 * 1024 * 1024 });
    return stdout.trim();
  } catch {
    return null;
  }
}

/** 커밋 메시지에서 [태그]를 뽑아 담당 에이전트를 찾는다. 못 찾으면 null. */
function agentOf(subject) {
  const m = /^\[([^\]]+)\]/.exec(subject);
  if (!m) return null;
  return TAG_TO_AGENT[m[1].trim()] ?? null;
}

async function collectGit() {
  const [branch, remote, lastHash, countRaw, porcelain, unpushedRaw, logRaw] = await Promise.all([
    git(["rev-parse", "--abbrev-ref", "HEAD"]),
    git(["remote", "get-url", "origin"]),
    git(["rev-parse", "--short", "HEAD"]),
    git(["rev-list", "--count", "HEAD"]),
    git(["status", "--porcelain"]),
    git(["rev-list", "--count", "@{u}..HEAD"]),
    // 구분자로 \x1f(필드) \x1e(레코드) 사용 — 커밋 메시지에 절대 안 나오는 문자
    git(["log", "-30", "--date=iso-strict", "--pretty=format:%h\x1f%an\x1f%ad\x1f%s\x1e"]),
  ]);

  const commits = (logRaw ?? "")
    .split("\x1e")
    .map((r) => r.trim())
    .filter(Boolean)
    .map((rec) => {
      const [hash, author, date, subject] = rec.split("\x1f");
      return { hash, author, date, subject, agent: agentOf(subject) };
    });

  const dirty = (porcelain ?? "")
    .split("\n")
    .map((l) => l.trim())
    .filter(Boolean);

  return {
    ok: branch !== null,
    branch,
    remote,
    lastHash,
    total: countRaw === null ? null : Number(countRaw),
    // @{u} 가 없으면(원격 미연결) null
    unpushed: unpushedRaw === null ? null : Number(unpushedRaw),
    dirtyCount: dirty.length,
    dirtyFiles: dirty.slice(0, 20),
    commits,
  };
}

/** reports/<name>.md 를 읽어 마지막으로 의미 있는 줄과 갱신 시각을 뽑는다. */
async function readReport(name) {
  const path = join(ROOT, "reports", `${name}.md`);
  if (!existsSync(path)) return { exists: false, mtime: null, lastLine: null, lines: 0 };
  try {
    const [text, st] = await Promise.all([readFile(path, "utf8"), stat(path)]);
    const lines = text
      .split("\n")
      .map((l) => l.trim())
      .filter((l) => l && !l.startsWith("#"));
    return {
      exists: true,
      mtime: st.mtime.toISOString(),
      lastLine: lines.length ? lines[lines.length - 1] : null,
      lines: lines.length,
    };
  } catch {
    return { exists: false, mtime: null, lastLine: null, lines: 0 };
  }
}

async function collectAgents(gitData) {
  const agentsDir = join(ROOT, ".claude", "agents");
  let defined = [];
  try {
    defined = (await readdir(agentsDir)).filter((f) => f.endsWith(".md")).map((f) => f.slice(0, -3));
  } catch {
    defined = [];
  }

  return Promise.all(
    AGENTS.map(async (id) => {
      const report = await readReport(id);
      const mine = gitData.commits.filter((c) => c.agent === id);
      return {
        id,
        /** .claude/agents/<id>.md 가 실제로 있는가 */
        defined: defined.includes(id),
        report,
        commitCount: mine.length,
        lastCommit: mine[0] ?? null,
        /** 화면에 띄울 한 줄. 실제 데이터가 없으면 null → 프론트에서 fallback 사용 */
        headline: mine[0]?.subject ?? report.lastLine ?? null,
      };
    }),
  );
}

/** STATUS.md 를 `## 제목` 기준으로 잘라 섹션별 항목을 뽑는다. */
async function collectStatus() {
  const path = join(ROOT, "STATUS.md");
  if (!existsSync(path)) return { exists: false, sections: [] };
  try {
    const [text, st] = await Promise.all([readFile(path, "utf8"), stat(path)]);
    const sections = [];
    let current = null;
    for (const raw of text.split("\n")) {
      const line = raw.trimEnd();
      const h = /^##\s+(.*)$/.exec(line);
      if (h) {
        current = { title: h[1].trim(), items: [] };
        sections.push(current);
        continue;
      }
      if (!current) continue;
      const item = /^\s*(?:[-*]|\d+\.)\s+(.*)$/.exec(line);
      if (item) current.items.push(item[1].replace(/^\[[ x]\]\s*/i, "").trim());
    }
    return { exists: true, mtime: st.mtime.toISOString(), sections };
  } catch {
    return { exists: false, sections: [] };
  }
}

async function buildSnapshot() {
  const gitData = await collectGit();
  const [agents, status] = await Promise.all([collectAgents(gitData), collectStatus()]);
  return { root: ROOT, generatedAt: new Date().toISOString(), git: gitData, agents, status };
}

/** 저장 + GitHub 업로드. 실제로 커밋하고 푸시한다. */
async function saveAndPush(message) {
  const steps = [];
  const step = async (label, args) => {
    try {
      const { stdout, stderr } = await run("git", args, { cwd: ROOT, maxBuffer: 4 * 1024 * 1024 });
      steps.push({ label, ok: true, out: (stdout || stderr || "").trim().slice(0, 500) });
      return true;
    } catch (err) {
      steps.push({ label, ok: false, out: String(err.stderr || err.message).trim().slice(0, 500) });
      return false;
    }
  };

  const before = await git(["status", "--porcelain"]);
  const hasChanges = Boolean(before && before.trim());

  if (hasChanges) {
    if (!(await step("변경사항 담기", ["add", "-A"]))) return { ok: false, steps };
    const msg = (message && message.trim()) || "[대표] 사무실에서 저장";
    if (!(await step("커밋", ["commit", "-m", msg]))) return { ok: false, steps };
  } else {
    steps.push({ label: "변경사항 담기", ok: true, out: "바뀐 파일이 없어 커밋을 건너뜀" });
  }

  const pushed = await step("GitHub 푸시", ["push", "origin", "HEAD"]);
  return { ok: pushed, hadChanges: hasChanges, steps };
}

function send(res, code, body) {
  const json = JSON.stringify(body);
  res.writeHead(code, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  });
  res.end(json);
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, "http://localhost");

  if (req.method === "OPTIONS") return send(res, 204, {});

  if (url.pathname === "/api/project" && req.method === "GET") {
    try {
      return send(res, 200, await buildSnapshot());
    } catch (err) {
      return send(res, 500, { error: String(err.message) });
    }
  }

  if (url.pathname === "/api/save" && req.method === "POST") {
    let raw = "";
    for await (const chunk of req) raw += chunk;
    let message = "";
    try {
      message = JSON.parse(raw || "{}").message ?? "";
    } catch {
      /* 본문이 없거나 깨졌으면 기본 메시지를 쓴다 */
    }
    try {
      return send(res, 200, await saveAndPush(message));
    } catch (err) {
      return send(res, 500, { error: String(err.message) });
    }
  }

  // 그 외 요청은 ui/ 폴더의 화면을 돌려준다
  if (req.method === "GET") {
    const name = url.pathname === "/" ? "index.html" : url.pathname.replace(/^\/+/, "");
    const file = resolve(HERE, "..", "ui", name);
    // ui 폴더 밖으로 나가는 경로는 막는다
    if (!file.startsWith(resolve(HERE, "..", "ui"))) return send(res, 403, { error: "forbidden" });
    if (existsSync(file)) {
      const type = file.endsWith(".html") ? "text/html; charset=utf-8"
        : file.endsWith(".css") ? "text/css; charset=utf-8"
        : file.endsWith(".js") ? "text/javascript; charset=utf-8"
        : "application/octet-stream";
      res.writeHead(200, { "Content-Type": type, "Cache-Control": "no-store" });
      res.end(await readFile(file));
      return;
    }
  }

  send(res, 404, { error: "not found" });
});

server.listen(PORT, () => {
  console.log("");
  console.log(`  개발실 열림  →  http://localhost:${PORT}`);
  console.log(`  감시 대상    →  ${ROOT}`);
  console.log("");
  console.log("  이 창을 닫으면 꺼집니다. 다시 열려면 같은 명령을 실행하세요.");
  console.log("");
});
