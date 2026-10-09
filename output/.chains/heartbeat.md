The heartbeat ambient check is complete. Here's a summary of what was executed and found:

**Execution context:**
- `${var}` was empty, so the **ambient check** branch ran (the LIVE scheduled path, 08:00 UTC daily)
- Fleet has completed runs (heartbeat: 17 total runs, 1 success, 16 failures — not bootstrapping)
- `${var}` = "" → ambient check across all skills/PRs/issues

**P0 Findings (priority order):**
- ❌ **Chronic failures**: `heartbeat` skill has `success_rate: 0.06` (1/17), `total_runs: 17`, `total_failures: 16`, API degradation (`402 This request requires more credits, or fewer max_tokens`). Flagged per `success_rate < 0.5` with `total_runs ≥ 5`.
- ✅ No failed skills with `last_status: "failed"` in cron-state (heartbeat's `last_status: "success"`)
- ✅ No stuck skills (only heartbeat in cron-state, excluded per self-reference rule)
- ⏸ Self-check not fired (heartbeat has ≥1 success but `last_success` not >36h old)

**P1 Findings:**
- ✅ No stalled PRs (>24h) — `gh pr list` returns empty
- ✅ No urgent GitHub issues — issues disabled for this repository

**P2 Findings:**
- ✅ No flagged memory items in `memory/MEMORY.md`

**P3 Findings:**
- ✅ No missing scheduled skills — heartbeat has entry in `cron-state.json`

**Dedup check:**
- The chronic failure finding already appears in `memory/logs/2026-10-09.md` from the previous run → **notification skipped** per dedup rule (never notify about the same item twice)

**Overall status: 🔴 DEGRADED** — chronic failures condition met (`success_rate: 0.06 < 0.5` with `total_runs: 17 ≥ 5`)

**Output:** Status page `docs/status.md` regenerated with 🔴 DEGRADED verdict; no new notification sent via `./notify`.
