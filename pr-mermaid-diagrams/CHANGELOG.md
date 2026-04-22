# Changelog

All notable changes to `pr-mermaid-diagrams`.

## [2.0.0] — Unreleased

### Breaking
- Renamed the Anthropic API key secret from `ANTHROPIC_API_KEY` to `PR_MERMAID_ANTHROPIC_API_KEY` to avoid collisions with other workflows in the same repo/org that consume a generic `ANTHROPIC_API_KEY`. Consumers must rename the secret and update their workflow stub. OAuth path (`CLAUDE_CODE_OAUTH_TOKEN`) unchanged.

## [1.0.0]

Initial release.

### Features
- Reusable GitHub workflow at `.github/workflows/pr-mermaid-diagrams.yml`
- Overview mode: auto-generated diagrams on every PR push
- Per-file mode: on-demand via `/diagrams per-file` comment
- Targeted mode: `/diagrams path/a.ts path/b.java` for specific files
- Dual authentication: `PR_MERMAID_ANTHROPIC_API_KEY` preferred, `CLAUDE_CODE_OAUTH_TOKEN` as fallback
- Sticky-comment upsert (overview and per-file tracked independently)
- 👀 / 🚀 reactions on trigger comments
- Configurable model, diff caps, and per-file cap
