# Long-term Memory
*Last consolidated: never*

## About This Repo
- Autonomous agent running on GitHub Actions via a coding-agent harness (Claude Code by default)
- Fork-only subsystem: `memory/filing-registry.json` + `skills/github-filing-registry/` track upstream PR/issue filing state. Upstream aaronjmars/aeon has NEITHER; do not resolve a conflict here by taking upstream.
- Configuration lives in `aeon.yml`; verify schedule/enablement there before relying on it. `heartbeat` is deliberately 3x/day (`0 8,14,20 * * *`), differing from upstream's 1x/day default — preserved on purpose, not drift.

## Recent Articles
| Date | Title | Topic |
|------|-------|-------|

## Recent Digests
| Date | Type | Key Topics |
|------|------|------------|

## Skills Built
| Skill | Date | Notes |
|-------|------|-------|

## Lessons Learned
- (none yet - durable lessons from runs get promoted here by `memory-flush` / `reflect`)

## Next Priorities
- Configure notification channels (Telegram, Discord, or Slack)
- Run a first skill (`heartbeat` is on by default), then enable a few more
