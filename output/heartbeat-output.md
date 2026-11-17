# Heartbeat — Ambient Check (2026-11-17)

**Selector:** `${var}` = "" → **Ambient check** across all skills/PRs/issues, regenerate public status page.

## Overall Status: 🟢 OK

The fleet is warmed (heartbeat has completed 124 runs since bootstrap). All priority-tier checks pass cleanly.

### P0 — Failed & stuck skills

- **Failed skills:** No entries with `last_status: "failed"` in cron-state.json. Heartbeat's own entry shows `last_status: "success"`.
- **Stuck skills:** No entries excluding heartbeat with `last_status: "dispatched"` >45min ago that have completed ≥1 run before. Heartbeat is excluded from the stuck check per self-reference rule.
- **API degradation:** No skill has `consecutive_failures >= 3`. Heartbeat has 0 consecutive failures.
- **Chronic failures:** No skill has `success_rate < 0.5` with `total_runs >= 5`. Heartbeat has success_rate 0.75 (93/124).
- **Self-check:** Heartbeat has 93 successes, but `last_success` (2026-11-17T15:00:24Z) is today, not >36 hours ago. No self-check flag.

### P1 — Stalled PRs & urgent issues

- **Stalled PRs:** `gh pr list` returns 0 open PRs. No PRs stalled >24h.
- **Urgent issues:** `gh issue list` returns only 1 closed issue with no urgent label. No urgent issues flagged.

### P2 — Flagged memory items

- No items flagged in `memory/MEMORY.md` that need follow-up.

### P3 — Missing scheduled skills

- Fleet is warmed (at least one completed run exists).
- Only `heartbeat` skill has `enabled: true` in `aeon.yml`, and it has an entry in `cron-state.json`.
- No other enabled skills to check for missing dispatches.

### Token pulse

- Latest token report: no recent file found in `output/articles/`, section omitted.

### Public status page

- Regenerated `docs/status.md` with verdict **🟢 OK**.
- Updated timestamp reflects current run.
- Skill health table shows heartbeat: 124 runs, 93 successes, 31 failures, 0 consecutive failures, 75% success rate.
- No open issues.
- Next scheduled run: heartbeat at 08:00 UTC (daily).

## Output (ambient)

No findings require attention. The ambient fleet-health check is clean.

## Summary

- Executed heartbeat skill with `var: ""` (empty), running the **ambient check** branch
- P0: No failed/stuck skills, no API degradation, no chronic failures, no stale self-check
- P1: No stalled PRs (0 open), no urgent issues
- P2: No flagged memory items
- P3: No missing scheduled skills (only heartbeat enabled, cron-state entry exists)
- Overall verdict: **🟢 OK** — no flags at any priority tier
- Status page (`docs/status.md`) regenerated with 🟢 OK verdict
- No notifications sent (no findings to dispatch)
- Log entry appended to `memory/logs/2026-11-17.md` under `### heartbeat (mode: ambient)` with `mode: ambient` discriminator and `STATUS_PAGE=OK`
- Fleet health: 124 total runs, 93 successes, 31 failures, 75% success rate, 0 consecutive failures
- Token pulse section omitted (no recent report file)