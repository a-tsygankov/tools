// Generates Mermaid diagrams of PR changes. Two modes:
//
//   overview (default): one sticky comment with 1-3 diagrams of the whole PR
//   per-file:           one sticky comment with a section per changed file
//
// Trigger logic:
//   - pull_request event → overview
//   - issue_comment event with body:
//       /diagrams                  → overview
//       /diagrams per-file         → per-file, all files
//       /diagrams path/a.ts ...    → per-file, only listed paths
//
// Auth:
//   - PR_MERMAID_ANTHROPIC_API_KEY preferred; CLAUDE_CODE_OAUTH_TOKEN is fallback.

import Anthropic from "@anthropic-ai/sdk";
import { execSync } from "node:child_process";

const {
  PR_MERMAID_ANTHROPIC_API_KEY,
  CLAUDE_CODE_OAUTH_TOKEN,
  GITHUB_TOKEN,
  PR_NUMBER,
  REPO,
  BASE_SHA,
  HEAD_SHA,
  TARGET_DIR,
  MODEL = "claude-sonnet-4-6",
  MAX_DIFF_CHARS = "120000",
  MAX_FILE_DIFF_CHARS = "40000",
  MAX_FILES = "15",
  EVENT_NAME,
  COMMENT_BODY = "",
  COMMENT_ID,
} = process.env;

const MARKER_OVERVIEW = "<!-- claude-mermaid-diagrams:overview -->";
const MARKER_PER_FILE = "<!-- claude-mermaid-diagrams:per-file -->";

const maxDiffChars = Number(MAX_DIFF_CHARS);
const maxFileDiffChars = Number(MAX_FILE_DIFF_CHARS);
const maxFiles = Number(MAX_FILES);

// ───────────────────────── 1. Parse trigger / mode ─────────────────────────

function parseCommand(body) {
  // Returns { mode: 'overview' | 'per-file', files: string[] | null }
  const trimmed = body.trim();
  const match = trimmed.match(/^\/diagrams(?:\s+(.*))?$/s);
  if (!match) return null;
  const rest = (match[1] || "").trim();

  if (rest === "" || rest === "overview") {
    return { mode: "overview", files: null };
  }

  const tokens = rest.split(/\s+/);
  if (tokens[0] === "per-file") {
    const files = tokens.slice(1).filter(Boolean);
    return { mode: "per-file", files: files.length ? files : null };
  }

  // Anything else after /diagrams is treated as a path list (implicit per-file)
  return { mode: "per-file", files: tokens };
}

let mode = "overview";
let filterFiles = null;

if (EVENT_NAME === "issue_comment") {
  const parsed = parseCommand(COMMENT_BODY);
  if (!parsed) {
    console.log("Comment did not match /diagrams syntax; exiting.");
    process.exit(0);
  }
  mode = parsed.mode;
  filterFiles = parsed.files;
  await reactToComment("eyes");
}

console.log(`Mode: ${mode}`);
if (filterFiles) console.log(`Files filter: ${filterFiles.join(", ")}`);

// ─────────────────────── 2. Collect diffs via git ──────────────────────────

function run(cmd) {
  return execSync(cmd, { cwd: TARGET_DIR, maxBuffer: 50 * 1024 * 1024 }).toString();
}

function truncate(s, max) {
  return s.length > max ? s.slice(0, max) + "\n\n... [diff truncated]" : s;
}

const changedFiles = run(`git diff --name-only ${BASE_SHA} ${HEAD_SHA}`)
  .split("\n")
  .map((f) => f.trim())
  .filter(Boolean);

if (changedFiles.length === 0) {
  console.log("No changed files.");
  process.exit(0);
}

// ─────────────────────── 3. Build Anthropic client ─────────────────────────

const clientOptions = PR_MERMAID_ANTHROPIC_API_KEY
  ? { apiKey: PR_MERMAID_ANTHROPIC_API_KEY }
  : {
      authToken: CLAUDE_CODE_OAUTH_TOKEN,
      defaultHeaders: { "anthropic-beta": "oauth-2025-04-20" },
    };

const anthropic = new Anthropic(clientOptions);
const authLabel = PR_MERMAID_ANTHROPIC_API_KEY ? "API key" : "Claude subscription";

// ─────────────────────── 4. Prompts ────────────────────────────────────────

const overviewSystemPrompt = `You analyze GitHub pull request diffs and produce Mermaid diagrams that illustrate the changes.

Output format (strict):
- Start with a one-line summary of what the PR changes.
- Then 1 to 3 Mermaid diagrams, each in a \`\`\`mermaid fenced block.
- Choose diagram types that fit the change:
  - flowchart for control/logic flow changes
  - sequenceDiagram for inter-service or call-order changes
  - classDiagram for structural/type/organization changes
  - stateDiagram-v2 for state machine changes
- Prefix each diagram with a short heading (### Before / ### After, or ### Flow, etc.).
- If the change is trivial (formatting, renames, dep bumps), say so in one sentence and skip the diagrams.
- Do NOT reproduce the diff. Do NOT add commentary beyond what's needed to read the diagrams.
- Keep node labels short. Escape special characters that break Mermaid parsing.`;

const perFileSystemPrompt = `You analyze a single file's diff from a GitHub pull request and produce a focused Mermaid diagram for that file.

Output format (strict):
- One or two sentences stating what this file's change does.
- Exactly one Mermaid diagram in a \`\`\`mermaid fenced block, showing the most informative view of THIS FILE's change (flow, structure, state, or sequence — pick what fits).
- If the file change is trivial (whitespace, import reorder, dep bump, rename only), write "_Trivial change; no diagram._" and skip the diagram.
- Keep labels short. Do not reproduce the diff.`;

// ─────────────────────── 5. Generate ───────────────────────────────────────

async function askClaude(systemPrompt, userContent, maxTokens = 2500) {
  const resp = await anthropic.messages.create({
    model: MODEL,
    max_tokens: maxTokens,
    system: systemPrompt,
    messages: [{ role: "user", content: userContent }],
  });
  return resp.content
    .filter((b) => b.type === "text")
    .map((b) => b.text)
    .join("\n\n");
}

let body;
let marker;

if (mode === "overview") {
  marker = MARKER_OVERVIEW;
  const diff = run(`git diff ${BASE_SHA} ${HEAD_SHA}`);
  const text = await askClaude(
    overviewSystemPrompt,
    `Here is the PR diff. Produce Mermaid diagrams of the logical, structural, or flow changes.\n\n\`\`\`diff\n${truncate(diff, maxDiffChars)}\n\`\`\``,
    4000,
  );
  body =
    `${marker}\n` +
    `## 🧭 PR change diagrams — overview\n\n` +
    text +
    `\n\n---\n<sub>Generated by Claude (${MODEL}, via ${authLabel}). ` +
    `Run \`/diagrams per-file\` in a comment for a per-file breakdown. ` +
    `Overview auto-updates on each push.</sub>`;
} else {
  marker = MARKER_PER_FILE;

  // Filter if user specified paths; warn on unknown ones
  let targets = changedFiles;
  const unknown = [];
  if (filterFiles) {
    const set = new Set(changedFiles);
    targets = filterFiles.filter((f) => {
      if (set.has(f)) return true;
      unknown.push(f);
      return false;
    });
  }

  if (targets.length === 0) {
    body =
      `${marker}\n` +
      `## 🧭 PR change diagrams — per-file\n\n` +
      `No matching changed files. Unknown paths: \`${unknown.join("`, `")}\`.\n\n` +
      `Changed files in this PR:\n` +
      changedFiles.map((f) => `- \`${f}\``).join("\n");
  } else {
    const capped = targets.slice(0, maxFiles);
    const skipped = targets.length - capped.length;

    const sections = [];
    for (const file of capped) {
      console.log(`Processing ${file}...`);
      let fileDiff;
      try {
        fileDiff = run(
          `git diff ${BASE_SHA} ${HEAD_SHA} -- "${file.replace(/"/g, '\\"')}"`,
        );
      } catch (e) {
        sections.push(`### \`${file}\`\n\n_Error reading diff: ${e.message}_`);
        continue;
      }
      if (!fileDiff.trim()) {
        sections.push(`### \`${file}\`\n\n_No diff (likely binary or permission-only change)._`);
        continue;
      }
      try {
        const text = await askClaude(
          perFileSystemPrompt,
          `File: \`${file}\`\n\n\`\`\`diff\n${truncate(fileDiff, maxFileDiffChars)}\n\`\`\``,
          1500,
        );
        sections.push(`### \`${file}\`\n\n${text}`);
      } catch (e) {
        sections.push(`### \`${file}\`\n\n_Generation failed: ${e.message}_`);
      }
    }

    const header =
      `## 🧭 PR change diagrams — per-file\n\n` +
      (filterFiles
        ? `Files requested: ${filterFiles.map((f) => `\`${f}\``).join(", ")}\n\n`
        : `Processed ${capped.length} of ${changedFiles.length} changed files.\n\n`) +
      (unknown.length
        ? `> ⚠️ Unknown paths ignored: ${unknown.map((f) => `\`${f}\``).join(", ")}\n\n`
        : "") +
      (skipped > 0
        ? `> ⚠️ ${skipped} file(s) skipped (cap is ${maxFiles}). Use \`/diagrams path1 path2\` to target specific files.\n\n`
        : "");

    body =
      `${marker}\n` +
      header +
      sections.join("\n\n---\n\n") +
      `\n\n---\n<sub>Generated by Claude (${MODEL}, via ${authLabel}). ` +
      `Re-run with \`/diagrams per-file\` or \`/diagrams path/to/file\`.</sub>`;
  }
}

// ─────────────────────── 6. Upsert sticky comment ──────────────────────────

await upsertComment(marker, body);
if (EVENT_NAME === "issue_comment") await reactToComment("rocket");
console.log("Done.");

// ─────────────────────── helpers ───────────────────────────────────────────

function ghHeaders() {
  return {
    Authorization: `Bearer ${GITHUB_TOKEN}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
  };
}

async function upsertComment(markerStr, bodyStr) {
  const existing = await fetch(
    `https://api.github.com/repos/${REPO}/issues/${PR_NUMBER}/comments?per_page=100`,
    { headers: ghHeaders() },
  ).then((r) => r.json());

  const mine = Array.isArray(existing)
    ? existing.find((c) => typeof c.body === "string" && c.body.startsWith(markerStr))
    : null;

  if (mine) {
    const r = await fetch(
      `https://api.github.com/repos/${REPO}/issues/comments/${mine.id}`,
      { method: "PATCH", headers: ghHeaders(), body: JSON.stringify({ body: bodyStr }) },
    );
    if (!r.ok) throw new Error(`PATCH failed: ${r.status} ${await r.text()}`);
    console.log(`Updated comment ${mine.id}`);
  } else {
    const r = await fetch(
      `https://api.github.com/repos/${REPO}/issues/${PR_NUMBER}/comments`,
      { method: "POST", headers: ghHeaders(), body: JSON.stringify({ body: bodyStr }) },
    );
    if (!r.ok) throw new Error(`POST failed: ${r.status} ${await r.text()}`);
    console.log("Created new comment");
  }
}

async function reactToComment(content) {
  if (!COMMENT_ID) return;
  try {
    await fetch(
      `https://api.github.com/repos/${REPO}/issues/comments/${COMMENT_ID}/reactions`,
      { method: "POST", headers: ghHeaders(), body: JSON.stringify({ content }) },
    );
  } catch (e) {
    console.log(`Reaction failed (non-fatal): ${e.message}`);
  }
}
