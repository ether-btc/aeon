# Heartbeat — Ambient Check (2026-11-17)

**Selector:** `${var}` = "" → **Ambient check** across all skills/PRs/issues, regenerate public status page.

## Overall Status: 🟢 OK

The fleet is warmed (heartbeat has completed 124 runs since bootstrap). All priority-tier checks pass cleanly with no findings.

### P0 — Failed & stuck skills

- **Failed skills:** No entries with `last_status: "failed"` in cron-state.json. Heartbeat's own entry shows `last_status: "success"`.
- **Stuck skills:** No entries excluding heartbeat with `last_status: "dispatched"` >45min ago that have completed ≥1 run before. Heartbeat is excluded from the stuck check per self-reference rule.
- **API degradation:** No skill has `consecutive_failures >= 3`. Heartbeat has 0 consecutive failures.
- **Chronic failures:** No skill has `success_rate < 0.5` with `total_runs >= 5`. Heartbeat has success_rate 0.75 (93/124).
- **Self-check:** Heartbeat has 93 successes, but `last_success` (2026-11-17T15:00:24Z) is today, not >36 hours ago. No self-check flag triggered.

### P1 — Stalled PRs & urgent issues

- **Stalled PRs:** `gh pr list` returns 0 open PRs. No PRs stalled >24h.
- **Urgent issues:** `gh issue list` returns only 1 closed issue with no urgent label. No urgent issues flagged.

### P2 — Flagged memory items

- No items flagged in `memory/MEMORY.md` that need follow-up.

### P3 — Missing scheduled skills

- Fleet is warmed (at least one completed run exists; per Bootstrap grace rules, P3 only runs on warmed fleets).
- Only `heartbeat` skill has `enabled: true` in `aeon.yml`, and it has an entry in `cron-state.json`.
- No other enabled skills with schedules to check for missing dispatches.

### Token pulse

- Latest token report: no recent file found in `output/articles/`, section omitted per staleness rules (>24h old).

### Public status page

- Regenerated `docs/status.md` with verdict **🟢 OK**.
- Updated timestamp reflects current run time.
- Skill health table shows heartbeat: 124 total runs, 93 successes, 31 failures, 0 consecutive failures, 75% success rate.
- No open issues.
- Next scheduled run: heartbeat at 08:00 UTC (daily, cron: `0 8,14,20 * * *`).

## Output (ambient)

No findings require attention. The ambient fleet-health check is clean. Fleet is healthy and operating normally.

## Summary

- Executed heartbeat skill with `var: ""` (empty), running the **ambient check** branch per the `${var}` grammar
- P0: No failed/stuck skills, no API degradation (consecutive_failures=0), no chronic failures (success_rate=0.75), no stale self-check (last_success within 36h)
- P1: No stalled PRs (gh pr list returned 0 open), no urgent issues (gh issue list returned only closed issues)
- P2: No flagged memory items (MEMORY.md has no follow-up flags)
- P3: No missing scheduled skills (only heartbeat enabled, cron-state entry exists; fleet is warmed so P3 applicable)
- Overall verdict: **🟢 OK** — no flags at any priority tier
- Status page (`docs/status.md`) regenerated with 🟢 OK verdict and current fleet health metrics
- No notifications sent (no findings to dispatch; per skill rules, clean run sends nothing)
- Log entry appended to `memory/logs/2026-11-17.md` under `### heartbeat (mode: ambient)` with `mode: ambient` discriminator and `STATUS_PAGE=OK`
- Fleet health: 124 total runs, 93 successes, 31 failures, 75% success rate, 0 consecutive failures
- Token pulse section omitted (no recent report file available)
- Files modified: `memory/logs/2026-11-17.md` (appended heartbeat log entry)