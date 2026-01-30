# Add Rails console commands to docs and deploy output

## Goal
Document and surface commands to open Rails console for staging and production, and show them in deploy script output alongside log commands.

## Definition of Done
- README includes staging + production Rails console commands.
- Deploy scripts print console commands after successful setup.
- Commands use the same env files the systemd services load.

## Constraints
- Keep commands consistent with existing deploy layout and env files under `/etc/tradingsniperpanel`.
- Keep README changes concise and aligned with current formatting.

## Steps
1. Add a short README section for Rails console (staging + production) with commands.
2. Add `log` lines in `script/setup_staging.sh` and `script/setup_production.sh` to print the same commands.
3. Sanity check command paths match app dirs and env files.

## Open Questions
- Should we add this to README.es.md as well, or only README.md?
- Preferred app user variable in docs: `$USER` or explicit `APP_USER`?
