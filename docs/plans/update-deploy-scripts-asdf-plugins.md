# Plan: Update deploy scripts for .tool-versions plugins

## Goal
Ensure staging/production setup scripts install asdf plugins listed in `.tool-versions`, add required system packages for Python builds, and update README so new Ubuntu installs succeed without manual fixes.

## Definition of Done
- `script/setup_common.sh` installs all asdf plugins found in `.tool-versions` and keeps nodejs keyring handling.
- `script/setup_production.sh` and `script/setup_staging.sh` call plugin setup after repo clone so `.tool-versions` is available.
- System package list includes Python build dependencies.
- `README.md` reflects the new package list and asdf plugins (`python`, `uv`).

## Constraints
- Keep scripts idempotent and safe for re-runs.
- Avoid large logs; update plan with commands run (PASS/FAIL only).

## Steps
1) Update setup scripts order to clone repo before plugin installation.
2) Enhance `ensure_asdf_plugins` to read `.tool-versions` and add missing plugins.
3) Add Python build deps to `ensure_packages` and README.
4) Update README plugin install instructions.

## Open Questions
- None (requirements confirmed).

## Progress
- Decision: Read asdf plugins from `.tool-versions`, default to `ruby`/`nodejs` when missing.
- Decision: Move repo clone before plugin setup so `.tool-versions` is available.
- Decision: Add Python build deps (bz2/sqlite/lzma/db/expat/tk + ncursesw).
- Commands (PASS): `rg --files -g '*setup_staging.sh'`, `sed -n '1,200p' script/setup_staging.sh`, `sed -n '1,520p' script/setup_common.sh`, `sed -n '1,140p' script/setup_production.sh`, `apply_patch` (setup_common/setup_production/setup_staging/README).
