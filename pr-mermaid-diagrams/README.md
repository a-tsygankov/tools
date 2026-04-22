# pr-mermaid-diagrams

Auto-generates Mermaid diagrams of pull-request changes as sticky PR comments. The reusable workflow lives at [`../.github/workflows/pr-mermaid-diagrams.yml`](../.github/workflows/pr-mermaid-diagrams.yml).

- **Overview mode** — automatic on every PR push; 1–3 high-level diagrams
- **Per-file mode** — on-demand via `/diagrams per-file` comment
- **Targeted mode** — `/diagrams path/a.ts path/b.java` for specific files

## Layout

```
pr-mermaid-diagrams/
├── README.md          you are here
├── SETUP.md           drop-in setup guide for consumer repos
├── CHANGELOG.md
├── package.json       pins @anthropic-ai/sdk
└── scripts/
    └── generate-pr-diagrams.mjs
```

## Quick start for a new consumer repo

1. Add `ANTHROPIC_API_KEY` (or `CLAUDE_CODE_OAUTH_TOKEN`) to repo/org secrets
2. Drop this into `.github/workflows/pr-diagrams.yml` in the consumer repo:

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

See [`SETUP.md`](./SETUP.md) for the full guide.

## Local development

The generator is plain Node 20 ESM. To iterate without pushing to GitHub:

```bash
cd pr-mermaid-diagrams
npm install
# Dry-run by setting env vars pointing at a real PR diff
ANTHROPIC_API_KEY=sk-... \
GITHUB_TOKEN=ghp_... \
PR_NUMBER=42 \
REPO=a-tsygankov/fc26-team-picker \
BASE_SHA=<sha> HEAD_SHA=<sha> \
TARGET_DIR=/path/to/local/checkout \
EVENT_NAME=pull_request \
node scripts/generate-pr-diagrams.mjs
```

## Versioning

Consumers pin the reusable workflow by git ref:

- `@v1` — latest stable (bumped via tag)
- `@main` — rolling (pick this only for repos where you're willing to eat a broken workflow)
- `@<sha>` — fully pinned

Breaking changes bump the major tag.
