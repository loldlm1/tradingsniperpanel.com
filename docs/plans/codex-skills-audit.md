# Plan: Codex Skills System + MCP Audit

Goal:
- Audit Codex config + MCP health, ingest project docs, design a robust skills system, and harden local MCP/env setup for reliable usage.

Definition of Done:
- MCP health report includes pass/fail per server with reasons and rerun commands.
- Project context summary covers architecture, conventions, workflows, testing, UI/Cruip rules, and pitfalls.
- New skills files exist under `agents/skills/` with purpose, usage rules, inputs, checklist, verification, tool guidance, and DoD.
- Suggested config.toml edits (if any) are documented clearly without secrets.
- Local `.envrc` includes `DATABASE_URL` (non-committed) and `.envrc.example` documents required vars.
- MCP servers are verified working or disabled/commented to prevent error spam.
- `compact_prompt` updated to preserve critical project invariants and workflow rules.
- `AGENTS.md` references the skills selector path.

Constraints:
- Follow `AGENTS.md` and docs in `docs/`.
- Keep controllers thin; use services/POROs; no inline scripts/styles in views.
- Use I18n for copy (EN/ES), avoid concatenating translated strings.
- Do not store secrets in repo; reference env vars by name only.
- Keep skills concise (mostly checklists/rules), <= ~200–400 lines each.

Steps:
1) Audit Codex config + MCP servers; record health and fixes.
2) Summarize project docs (architecture, workflows, testing, UI/Cruip, pitfalls).
3) Draft skills selector + role playbooks (full-stack, backend, frontend, bugfix).
4) Add files under `agents/skills/` and summarize.
5) Propose small improvements (config hardening, env template gaps).
6) Update `.envrc`/`.envrc.example`, adjust `compact_prompt`, and reference skills in `AGENTS.md`.
7) Re-run MCP smoke tests and disable failing servers if still broken.

Decisions:
- Store role playbooks under `agents/skills/` with a selector README.
- Keep `AGENTS.md` unchanged; selector lives in `agents/skills/README.md`.
- Update `AGENTS.md` to point to `agents/skills/README.md` for playbook selection.
- Temporarily comment out MCP blocks in `~/.codex/config.toml` until smoke tests succeed.

Commands run (PASS/FAIL):
- `cat <<'EOF' > /home/loldlm/rails_projects/tradingsniperpanel.com/docs/plans/codex-skills-audit.md ... EOF` (PASS)
- `sed -n '1,240p' /home/loldlm/.codex/config.toml` (PASS)
- `python - <<'PY' ... tomllib ... PY` (PASS)
- `cat /home/loldlm/rails_projects/tradingsniperpanel.com/.tool-versions` (PASS)
- `sed -n '1,240p' /home/loldlm/rails_projects/tradingsniperpanel.com/AGENTS.md` (PASS)
- `rg -n "mcp" /home/loldlm/rails_projects/tradingsniperpanel.com` (PASS no matches)
- `rg --files /home/loldlm/rails_projects/tradingsniperpanel.com/docs` (PASS)
- `wc -l /home/loldlm/rails_projects/tradingsniperpanel.com/docs/*` (PASS)
- `cat /home/loldlm/rails_projects/tradingsniperpanel.com/docs/database_model_reference.md` (PASS)
- `cat /home/loldlm/rails_projects/tradingsniperpanel.com/docs/cruip_template_guide.md` (PASS)
- `cat /home/loldlm/rails_projects/tradingsniperpanel.com/docs/plans/dashboard-courses-index-redesign.md` (PASS)
- `sed -n '1,240p' /home/loldlm/.codex/skills/.system/skill-creator/SKILL.md` (PASS)
- `for bin in node npm npx python uv uvx; do ...; done` (PASS)
- `for bin in asdf direnv; do ...; done` (PASS)
- `for var in DATABASE_URL CONTEXT7_API_KEY; do ...; done` (PASS)
- `sed -n '1,240p' /home/loldlm/rails_projects/tradingsniperpanel.com/.envrc` (PASS)
- `sed -n '1,240p' /home/loldlm/rails_projects/tradingsniperpanel.com/.envrc.example` (PASS)
- `ls -la /home/loldlm/rails_projects/tradingsniperpanel.com` (PASS)
- `ss -ltn '( sport = :3000 )' | tail -n +2` (PASS)
- `sed -n '1,240p' /home/loldlm/rails_projects/tradingsniperpanel.com/README.md` (PASS)
- `rg -n "test|spec|rspec|lint" /home/loldlm/rails_projects/tradingsniperpanel.com/README.md` (PASS)
- `sed -n '340,460p' /home/loldlm/rails_projects/tradingsniperpanel.com/README.md` (PASS)
- `rg -n "\\.envrc" /home/loldlm/rails_projects/tradingsniperpanel.com/.gitignore` (PASS)
- `direnv exec /home/loldlm/rails_projects/tradingsniperpanel.com bash -lc 'python - <<"PY" ... server-postgres ... PY'` (FAIL timeout)
- `direnv exec /home/loldlm/rails_projects/tradingsniperpanel.com bash -lc 'python - <<"PY" ... server-postgres retry ... PY'` (FAIL timeout)
- `python - <<"PY" ... playwright ... PY` (FAIL timeout)
- `python - <<"PY" ... playwright retry ... PY` (FAIL timeout)
- `python - <<"PY" ... uvx mcp-server-fetch ... PY` (FAIL timeout)
- `python - <<"PY" ... uvx mcp-server-fetch retry ... PY` (FAIL timeout)
- `python - <<"PY" ... open-websearch ... PY` (FAIL stdout closed)
- `npx -y open-websearch@latest --help | head -n 5` (FAIL port in use)
- `python - <<"PY" ... open-websearch MODE=stdio ... PY` (FAIL timeout)
- `direnv exec /home/loldlm/rails_projects/tradingsniperpanel.com bash -lc 'python - <<"PY" ... context7 ... PY'` (FAIL stdout closed)
- `direnv exec /home/loldlm/rails_projects/tradingsniperpanel.com bash -lc 'timeout 5 npx -y @upstash/context7-mcp@2.1.0 --api-key "$CONTEXT7_API_KEY"'` (FAIL npm ENOENT)
- `npx -y @modelcontextprotocol/server-postgres --help | head -n 5` (FAIL invalid URL)
- `mkdir -p /home/loldlm/rails_projects/tradingsniperpanel.com/agents/skills` (PASS)
- `cat <<'EOF' > /home/loldlm/rails_projects/tradingsniperpanel.com/agents/skills/README.md ... EOF` (PASS)
- `cat <<'EOF' > /home/loldlm/rails_projects/tradingsniperpanel.com/agents/skills/fullstack.md ... EOF` (PASS)
- `cat <<'EOF' > /home/loldlm/rails_projects/tradingsniperpanel.com/agents/skills/backend-rails-pg.md ... EOF` (PASS)
- `cat <<'EOF' > /home/loldlm/rails_projects/tradingsniperpanel.com/agents/skills/frontend-cruip.md ... EOF` (PASS)
- `cat <<'EOF' > /home/loldlm/rails_projects/tradingsniperpanel.com/agents/skills/bugfix-qa.md ... EOF` (PASS)
- `sed -n '1,200p' /home/loldlm/rails_projects/tradingsniperpanel.com/docs/plans/codex-skills-audit.md` (PASS)
- `apply_patch (update plan with decisions/commands)` (PASS)
- `apply_patch (update .envrc)` (PASS)
- `apply_patch (update .envrc.example)` (PASS)
- `apply_patch (update ~/.codex/config.toml compact_prompt + MCP config)` (PASS)
- `apply_patch (disable MCP blocks in ~/.codex/config.toml)` (PASS)
- `apply_patch (update AGENTS.md skills section)` (PASS)
- `apply_patch (update agents/skills/README.md MCP prereqs)` (PASS)
- `direnv exec /home/loldlm/rails_projects/tradingsniperpanel.com bash -lc 'pg_isready -h \"$DB_HOST\" -p \"$DB_PORT\"'` (PASS)
- `direnv allow /home/loldlm/rails_projects/tradingsniperpanel.com` (PASS)
- `direnv exec /home/loldlm/rails_projects/tradingsniperpanel.com bash -lc 'python - <<\"PY\" ... postgres mcp ... PY'` (FAIL timeout)
- `npm cache clean --force` (PASS)
- `ls -la /home/loldlm/.npm/_npx | head -n 20` (PASS)
- `sed -n '40,200p' /home/loldlm/.codex/config.toml` (PASS)
- `direnv exec /home/loldlm/rails_projects/tradingsniperpanel.com bash -lc 'timeout 5 npx -y @upstash/context7-mcp@2.1.0 --api-key \"$CONTEXT7_API_KEY\"'` (FAIL npm ENOENT)
- `direnv exec /home/loldlm/rails_projects/tradingsniperpanel.com bash -lc 'NPM_CONFIG_CACHE=/tmp/npm-cache NPX_CACHE=/tmp/npx-cache timeout 5 npx -y @upstash/context7-mcp@2.1.0 --api-key \"$CONTEXT7_API_KEY\"'` (FAIL timeout)
- `direnv exec /home/loldlm/rails_projects/tradingsniperpanel.com bash -lc 'NPM_CONFIG_CACHE=/tmp/npm-cache NPX_CACHE=/tmp/npx-cache timeout 30 npx -y @upstash/context7-mcp@2.1.0 --api-key \"$CONTEXT7_API_KEY\"'` (FAIL timeout)
- `MODE=stdio DEFAULT_SEARCH_ENGINE=duckduckgo ALLOWED_SEARCH_ENGINES=duckduckgo,bing,brave,exa PORT=3100 timeout 5 npx -y open-websearch@latest` (FAIL timeout)
- `direnv exec /home/loldlm/rails_projects/tradingsniperpanel.com bash -lc 'python - <<\"PY\" ... context7 mcp ... PY'` (FAIL timeout)
- `python - <<'PY' ... tomllib parse ~/.codex/config.toml ... PY` (PASS)

Open Questions:
- None.
