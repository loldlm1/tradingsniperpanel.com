# Skills Playbooks

Purpose:
- Provide short, repeatable role playbooks to make feature work consistent and reliable.

Skill selector policy:
- Default: use `fullstack.md` for most feature requests.
- Backend-heavy (APIs, data modeling, jobs, performance): use `backend-rails-pg.md`.
- UI/Cruip-heavy (layouts, marketing, dashboard UX): use `frontend-cruip.md`.
- Bugfix/regression or repro-heavy: use `bugfix-qa.md`.
- Mixed work: start with `fullstack.md`, then apply the relevant specialist checklist(s) for the affected layers.

How to use:
- Read `AGENTS.md` and `docs/*` first.
- Keep controllers thin, prefer services/POROs, and use I18n for all copy.
- Keep skills concise; do not duplicate long docs here.
- MCP prerequisites (when enabled): `DATABASE_URL`, `CONTEXT7_API_KEY`. Check `~/.codex/config.toml` for current MCP status.

Skills:
- `agents/skills/fullstack.md` - End-to-end delivery checklist for most features.
- `agents/skills/backend-rails-pg.md` - Rails/PG specialist checklist for APIs, jobs, and data.
- `agents/skills/frontend-cruip.md` - Cruip/Mosaic/Neon specialist checklist for UI work.
- `agents/skills/bugfix-qa.md` - Repro-first bugfix and regression testing checklist.
