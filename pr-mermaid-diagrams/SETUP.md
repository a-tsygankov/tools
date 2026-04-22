# PR Mermaid Diagrams — Setup Guide

Auto-generate Mermaid diagrams of pull-request changes. A sticky comment appears on each PR within ~30 seconds and updates on every push. Trigger a detailed per-file view on demand with a `/diagrams` comment.

Powered by Claude. Works with either an **Anthropic API key** (recommended, costs a few cents per PR) or your **Claude Pro/Max subscription** via OAuth (free, but the token expires periodically).

Hosted at [`a-tsygankov/tools`](https://github.com/a-tsygankov/tools).

---

## Prerequisites

- A GitHub repository where you can add workflows and secrets
- **One** of the following:
  - An Anthropic API key from [console.anthropic.com](https://console.anthropic.com), **or**
  - An active Claude Pro or Max subscription and Claude Code installed locally (`npm i -g @anthropic-ai/claude-code`)

---

## Step 1 — Add a secret

**Settings → Secrets and variables → Actions → New repository secret**.

### Option A: Anthropic API key (recommended)

- **Name:** `ANTHROPIC_API_KEY`
- **Value:** your `sk-ant-...` key

Cost with Sonnet is typically well under $0.01 per PR (overview mode). Per-file mode on a 10-file PR might run $0.05–0.15. Tokens never expire.

### Option B: Claude Pro/Max OAuth token (free on subscription)

```bash
claude setup-token
```

Copy the printed token and add:

- **Name:** `CLAUDE_CODE_OAUTH_TOKEN`
- **Value:** the token

> ⚠️ **Known limitation:** OAuth tokens for GitHub Actions currently expire quickly (often ~1 day) and must be regenerated with `claude setup-token` and updated in secrets. Track [anthropics/claude-code-action#727](https://github.com/anthropics/claude-code-action/issues/727). For production use, prefer the API key.

### Sharing across many repos

Set the secret **once** as an **organization secret** (Org settings → Secrets and variables → Actions → New organization secret) and scope it to *All* or *Selected* repositories.

---

## Step 2 — Add the workflow stub

Create `.github/workflows/pr-diagrams.yml`:

```yaml
name: PR Diagrams
on:
  pull_request:
    types: [opened, synchronize, reopened]
  issue_comment:
    types: [created]

jobs:
  diagrams:
    uses: a-tsygankov/tools/.github/workflows/pr-mermaid-diagrams.yml@v1
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    permissions:
      pull-requests: write
      contents: read
      issues: read
```

Pin `@v1` for stability or `@main` for rolling updates.

> The `issue_comment` trigger is what makes `/diagrams` commands work. GitHub uses the same event for PR comments and issue comments; the workflow filters to PR contexts internally.

---

## Usage

### Automatic — overview mode

Every PR gets an auto-generated sticky comment with 1–3 Mermaid diagrams showing the main logic, structure, or flow changes. Updates on each push.

### On demand — per-file mode

Comment on any PR:

| Command | Effect |
|---|---|
| `/diagrams` | Re-run overview |
| `/diagrams per-file` | Diagram per changed file (capped at 15) |
| `/diagrams src/a.ts src/b.java` | Per-file mode, just those paths |

The trigger comment gets an 👀 reaction when processing starts, 🚀 when done. Overview and per-file are separate sticky comments — running one doesn't overwrite the other.

**When per-file is worth it:**
- Large refactors where the overview flattens too much nuance
- Reviewing PRs that touch many unrelated files
- Drilling into one specific file: `/diagrams src/BTMetadataRequestUtils.java`

**When overview is enough:**
- Focused PRs (1–3 files, single concern)
- Quick turnaround needed
- Keeping cost/noise down

---

## Customization

```yaml
jobs:
  diagrams:
    uses: a-tsygankov/tools/.github/workflows/pr-mermaid-diagrams.yml@v1
    with:
      model: claude-opus-4-7          # default: claude-sonnet-4-6
      max_diff_chars: 200000          # total diff cap, overview mode
      max_file_diff_chars: 60000      # per-file diff cap
      max_files: 25                   # file cap for per-file mode
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

Use Opus when diagram quality matters more than speed or cost. Sonnet is fine for most PRs.

---

## Behavior

- Two independent sticky comments per PR:
  - `<!-- claude-mermaid-diagrams:overview -->`
  - `<!-- claude-mermaid-diagrams:per-file -->`
- Overview updates on every push. Per-file only runs when explicitly requested.
- If the diff is trivial (formatting, renames, dep bumps), Claude says so and skips diagrams.
- PR diffs beyond the char caps are truncated.
- Per-file mode calls Claude once per file — 15 files = 15 API calls.

---

## Troubleshooting

**No comment appears after opening a PR.** Check Actions tab. Workflow named "PR Diagrams".

**`/diagrams` comment does nothing.** Confirm `.github/workflows/pr-diagrams.yml` includes `issue_comment` trigger and `issues: read` permission. Command must start at the beginning of the comment (no quoting, no leading whitespace).

**"Neither ANTHROPIC_API_KEY nor CLAUDE_CODE_OAUTH_TOKEN is set"** — add one as a repo or org secret.

**OAuth fails with 401.** Token expired. Run `claude setup-token` again, or switch to API key.

**Mermaid doesn't render.** Copy the block into [mermaid.live](https://mermaid.live) to see the parser error. Usually a character needing escape. Bump to Opus if it persists.

**PRs from forks don't work.** GitHub restricts secrets on fork PRs for security. Expected and desirable. Require contributors to push branches to the main repo, or weigh `pull_request_target` (carries injection risk).

**I want to remove it.** Delete `.github/workflows/pr-diagrams.yml`. Existing comments stay; new PRs get none.

---

## Security notes

- Permissions are tight: `pull-requests: write` (post/update), `contents: read` (diff), `issues: read` (resolve comment→PR).
- Diff contents are sent to Anthropic. On sensitive code, review Anthropic's [data-usage policy](https://www.anthropic.com/legal/privacy) or skip those repos.
- Never commit the API key or OAuth token.
- The `issue_comment` trigger fires on every PR comment. The workflow exits in the first step if the comment isn't `/diagrams`, but each comment still costs one free-tier runner minute.
