# Long-term Memory

*Last consolidated: 2026-07-20*

## Repository

- `ether-btc/aeon` is an autonomous agent framework running scheduled GitHub Actions through Claude Code.
- Configuration lives in `aeon.yml`; skills are enabled and scheduled there.
- The memory system is repository-backed and rendered on the GitHub Pages site.

## Memory Model

- `memory/MEMORY.md` — short, durable index and operating context.
- `memory/topics/` — detailed subject notes; currently no topic files are populated.
- `memory/logs/` — append-only daily activity records.
- `memory/issues/` — structured issue tracker; see `memory/issues/INDEX.md`.
- `memory/watched-repos.md` — repositories monitored by research and digest skills.
- `memory/filing-registry.json` — upstream PR and issue filing state.
- `memory/cron-state.json` and `memory/skill-health/` — scheduler and output-health state.

## Operating Conventions

- Keep this index concise; move growing detail into topic files rather than adding more sections here.
- Persist generated files and commit them before recording the run in `memory/logs/`.
- Digest output is Markdown with clickable links and stays below 4,000 characters.
- Use `./notify "message"` for outbound notifications so all configured channels are handled consistently.
- Verify current configuration in `aeon.yml` before relying on schedule or enablement details.

## Current Configuration Snapshot

- Enabled: `github-upstream-tracker` every 30 minutes.
- Enabled: `heartbeat` at 08:00, 14:00, and 20:00 UTC.
- All other skill enablement and schedules should be treated as configuration data, not duplicated here.

## Site Synchronization

- Run `scripts/sync-site-data.sh` after memory, log, topic, or article changes that should appear on the site.
- Generated site data is stored in `docs/_data/`.
