# Changelog

All notable changes to `pr-mermaid-diagrams`.

## [1.0.0] — Unreleased

Initial release.

### Features
- Reusable GitHub workflow at `.github/workflows/pr-mermaid-diagrams.yml`
- Overview mode: auto-generated diagrams on every PR push
- Per-file mode: on-demand via `/diagrams per-file` comment
- Targeted mode: `/diagrams path/a.ts path/b.java` for specific files
- Dual authentication: `ANTHROPIC_API_KEY` preferred, `CLAUDE_CODE_OAUTH_TOKEN` as fallback
- Sticky-comment upsert (overview and per-file tracked independently)
- 👀 / 🚀 reactions on trigger comments
- Configurable model, diff caps, and per-file cap
