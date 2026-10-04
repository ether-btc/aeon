# Long-term Memory

*Reviewed: 2026-08-13*

## Purpose

This file is a concise index of durable Aeon operating context. Put growing or time-sensitive detail in the files it points to, not here.

## Repository

- `ether-btc/aeon` is an autonomous agent framework whose scheduled GitHub Actions run Claude Code skills.
- `aeon.yml` is the source of truth for skill enablement, schedules, variables, and model overrides.
- Generated memory/site artifacts should be committed before the run is recorded in `memory/logs/`.

## Memory Map

- `memory/topics/` — durable subject notes.
- `memory/logs/` — append-only daily activity records.
- `memory/issues/INDEX.md` — issue register; individual issues live beside it.
- `memory/watched-repos.md` — repositories monitored by research and digest skills.
- `memory/filing-registry.json` — upstream PR/issue filing state.
- `memory/cron-state.json` — scheduler state; do not copy its contents here.
- `memory/skill-health/` — per-skill health state.

## Operating Conventions

- Keep this index short; promote detail to a topic file when it outgrows a few lines.
- Verify `aeon.yml` and the relevant state file before relying on schedules or enablement.
- Use `./notify "message"` for outbound notifications so all configured channels are handled consistently.
- Keep digest output Markdown with clickable links and below 4,000 characters.
- Run `scripts/sync-site-data.sh` after memory, log, topic, or article changes intended for the site.
