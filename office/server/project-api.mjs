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
import { execFile, spawn } from "node:child_process";
import { homedir } from "node:os";
import { promisify } from "node:util";
import { readFile, readdir, stat, writeFile, unlink } from "node:fs/promises";
import { existsSync } from "node:fs";
import { tmpdir } from "node:os";
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
  개발실: "pm",
  도구: "pm",
};

const AGENTS = ["pm", "coordinator", "game-designer", "developer", "qa", "designer"];

/** 담당자 → 커밋 메시지에 붙일 태그. TAG_TO_AGENT 로 되읽을 수 있어야 한다. */
const AGENT_TO_TAG = {
  pm: "PM",
  coordinator: "코디",
  "game-designer": "기획",
  developer: "개발",
  designer: "아트",
  qa: "QA",
};

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
    // Windows 에서 git commit -m "한글" 로 넘기면 Node 가 시스템 코드페이지로
    // 인자를 인코딩해 한글이 ??? 로 깨진다. UTF-8 파일에 써서 -F 로 넘긴다.
    const msgFile = join(tmpdir(), `skillcraft-commit-${process.pid}-${Date.now()}.txt`);
    await writeFile(msgFile, msg, "utf8");
    const committed = await step("커밋", ["commit", "-F", msgFile]);
    await unlink(msgFile).catch(() => {});
    if (!committed) return { ok: false, steps };
  } else {
    steps.push({ label: "변경사항 담기", ok: true, out: "바뀐 파일이 없어 커밋을 건너뜀" });
  }

  const pushed = await step("GitHub 푸시", ["push", "origin", "HEAD"]);
  return { ok: pushed, hadChanges: hasChanges, steps };
}

// ============================================================
//  지시 → Claude Code 실제 실행
// ============================================================

/** claude 실행 파일 위치를 한 번만 찾아둔다. */
function findClaude() {
  const candidates = [
    process.env.CLAUDE_BIN,
    join(homedir(), ".local", "bin", "claude.exe"),
    join(homedir(), ".local", "bin", "claude"),
    process.env.APPDATA && join(process.env.APPDATA, "npm", "claude.cmd"),
  ].filter(Boolean);
  for (const c of candidates) if (existsSync(c)) return c;
  return null;
}

const CLAUDE_BIN = findClaude();

/** 지시 목록. 서버가 살아 있는 동안만 기억한다. */
const jobs = [];
let jobSeq = 0;
/** 동시에 여러 개가 같은 파일을 고치면 충돌하므로 한 번에 하나씩 처리한다. */
let queue = Promise.resolve();

/** 파일 경로에서 이름만 뽑는다. */
function baseName(p) {
  return String(p ?? "").split(/[\\/]/).pop() || String(p ?? "");
}

function cut(s, n) {
  const t = String(s ?? "").replace(/\s+/g, " ").trim();
  return t.length > n ? t.slice(0, n - 1) + "…" : t;
}

/**
 * stream-json 이벤트 한 줄 → 사람이 읽을 한 줄.
 * 보여줄 게 없는 이벤트는 null 을 돌려 무시한다.
 */
function describeEvent(ev) {
  if (ev.type === "system" && ev.subtype === "init") return "시작함";

  if (ev.type === "assistant" && ev.message?.content) {
    const parts = [];
    for (const c of ev.message.content) {
      if (c.type === "text" && c.text?.trim()) {
        parts.push(cut(c.text, 160));
      } else if (c.type === "tool_use") {
        const i = c.input ?? {};
        const name = c.name;
        if (name === "Read") parts.push(`${baseName(i.file_path)} 읽음`);
        else if (name === "Edit") parts.push(`${baseName(i.file_path)} 고침`);
        else if (name === "Write") parts.push(`${baseName(i.file_path)} 새로 씀`);
        else if (name === "Bash") parts.push(`실행: ${cut(i.command, 90)}`);
        else if (name === "Glob" || name === "Grep") parts.push(`찾는 중: ${cut(i.pattern, 60)}`);
        else if (name === "TodoWrite") parts.push("할 일 목록 정리");
        else if (name === "Task") parts.push(`서브에이전트 호출: ${cut(i.description, 60)}`);
        else parts.push(name);
      }
    }
    return parts.length ? parts.join(" · ") : null;
  }

  // 도구 실행이 실패한 경우만 알린다 (성공 결과까지 쏟으면 화면이 지저분해진다)
  if (ev.type === "user" && ev.message?.content) {
    for (const c of ev.message.content) {
      if (c.type === "tool_result" && c.is_error) {
        const t = Array.isArray(c.content)
          ? c.content.map((x) => x.text ?? "").join(" ")
          : c.content;
        return "⚠ " + cut(t, 120);
      }
    }
  }
  return null;
}

/** 지시 하나를 실제로 실행한다. */
function runJob(job) {
  return new Promise((resolve) => {
    if (!CLAUDE_BIN) {
      job.status = "실패";
      job.error = "claude 실행 파일을 찾지 못했습니다. 환경변수 CLAUDE_BIN 에 경로를 지정하세요.";
      job.endedAt = new Date().toISOString();
      return resolve();
    }

    // stream-json = 줄 단위 JSON 이 작업 도중 실시간으로 나온다.
    // (-p 와 함께 쓰려면 --verbose 가 필요하다)
    const args = ["-p", "--output-format", "stream-json", "--verbose"];
    if (job.agent && job.agent !== "auto") args.push("--agent", job.agent);
    // acceptEdits = 파일 수정은 허용, 그 외 위험한 작업은 막는다.
    // full = 전부 허용. 커밋·명령 실행까지 맡길 때만 쓴다.
    args.push("--permission-mode", job.full ? "bypassPermissions" : "acceptEdits");

    job.status = "작업 중";
    job.startedAt = new Date().toISOString();
    job.steps = [];
    job.current = null;

    const child = spawn(CLAUDE_BIN, args, {
      cwd: ROOT,
      windowsHide: true,
      // 체크포인트 훅이 태그 없는 커밋을 만들지 않도록 표시한다.
      // 커밋은 아래 autoCommitJob() 이 [역할] 태그를 붙여 직접 한다.
      env: { ...process.env, SKILLCRAFT_OFFICE_JOB: "1" },
    });
    job.pid = child.pid;

    let err = "";
    /** 줄이 잘려서 오거나 여러 줄이 한 번에 오므로 개행 기준으로 직접 자른다 */
    let buf = "";
    let finalEvent = null;

    const pushStep = (text) => {
      if (!text) return;
      job.steps.push({ at: new Date().toISOString(), text });
      if (job.steps.length > 60) job.steps.shift();
      job.current = text;
    };

    const handleLine = (line) => {
      const s = line.trim();
      if (!s) return;
      let ev;
      try {
        ev = JSON.parse(s);
      } catch {
        return; // JSON 이 아닌 줄은 버린다. 서버가 죽으면 안 된다.
      }
      if (ev.type === "result") finalEvent = ev;
      pushStep(describeEvent(ev));
    };

    child.stdout.on("data", (d) => {
      buf += d.toString("utf8");
      let nl;
      while ((nl = buf.indexOf("\n")) !== -1) {
        handleLine(buf.slice(0, nl));
        buf = buf.slice(nl + 1);
      }
    });
    child.stderr.on("data", (d) => { err += d.toString("utf8"); });

    // 한글이 깨지지 않도록 인자가 아닌 stdin 으로 넘긴다
    child.stdin.setDefaultEncoding("utf8");
    child.stdin.end(job.text, "utf8");

    const timer = setTimeout(() => {
      job.timedOut = true;
      child.kill();
    }, 15 * 60 * 1000);

    child.on("error", (e) => {
      clearTimeout(timer);
      job.status = "실패";
      job.error = String(e.message);
      job.endedAt = new Date().toISOString();
      resolve();
    });

    child.on("close", (code) => {
      clearTimeout(timer);
      if (buf.trim()) handleLine(buf); // 마지막 줄에 개행이 없을 수 있다
      job.endedAt = new Date().toISOString();
      job.exitCode = code;
      job.current = null;

      if (job.timedOut) {
        job.status = "실패";
        job.error = "15분을 넘겨 중단했습니다.";
        return resolve();
      }

      if (finalEvent) {
        job.result = finalEvent.result ?? null;
        job.costUsd = finalEvent.total_cost_usd ?? null;
        job.turns = finalEvent.num_turns ?? null;
        job.denials = (finalEvent.permission_denials ?? []).length;
        job.status = finalEvent.is_error ? "실패" : "완료";
        if (finalEvent.is_error) job.error = finalEvent.result ?? "알 수 없는 오류";
      } else {
        // result 이벤트가 없으면 비정상 종료다
        job.status = "실패";
        job.error = (err.trim() || `claude 가 결과 없이 종료했습니다 (코드 ${code})`).slice(0, 1000);
      }
      resolve();
    });
  });
}

/**
 * 지시가 끝나면 그 결과를 [역할] 태그를 붙여 저장하고 GitHub 에 올린다.
 * 태그가 있어야 화면이 담당자를 찾아 대표실 보고를 띄운다.
 */
async function autoCommitJob(job) {
  if (job.status !== "완료") return;
  const tag = AGENT_TO_TAG[job.agent] ?? "개발실";
  const summary = cut(job.text.split("\n")[0], 72);
  const r = await saveAndPush(`[${tag}] ${summary}`);
  job.saved = r.ok;
  job.savedChanges = r.hadChanges;
  job.saveError = r.ok ? null : (r.steps.find((s) => !s.ok)?.out ?? "저장 실패");
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

  if (url.pathname === "/api/jobs" && req.method === "GET") {
    return send(res, 200, {
      claudeFound: Boolean(CLAUDE_BIN),
      jobs: jobs.slice(-25).reverse(),
    });
  }

  if (url.pathname === "/api/order" && req.method === "POST") {
    let raw = "";
    for await (const chunk of req) raw += chunk;
    let body = {};
    try {
      body = JSON.parse(raw || "{}");
    } catch {
      return send(res, 400, { error: "본문을 읽지 못했습니다." });
    }
    const text = String(body.text ?? "").trim();
    if (!text) return send(res, 400, { error: "지시 내용이 비어 있습니다." });

    const job = {
      id: ++jobSeq,
      agent: String(body.agent ?? "auto"),
      text,
      full: Boolean(body.full),
      status: "대기",
      queuedAt: new Date().toISOString(),
      startedAt: null,
      endedAt: null,
      result: null,
      error: null,
    };
    jobs.push(job);

    // 앞의 지시가 끝난 뒤에 실행한다 (파일 충돌 방지)
    queue = queue
      .then(() => runJob(job))
      .then(() => autoCommitJob(job))
      .catch(() => {});

    return send(res, 200, { id: job.id, queued: jobs.filter((j) => j.status === "대기").length });
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
