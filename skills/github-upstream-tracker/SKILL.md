---
name: GitHub Upstream Tracker
description: Watch your filed PRs across upstream repositories — detect closures, merges, stale items, and needed follow-ups. Reconcile against memory/filing-registry.json every 30 minutes.
var: ""
tags: [dev, github, monitoring]
depends_on: [github-filing-registry]
---

> **${var}** — Optional. Accepts `owner/repo#N` to track a single item. If empty, tracks all entries in the filing registry.

Every PR you file to an upstream repo needs follow-through. This skill detects what happened to your filings, flags items needing attention, and keeps the registry state accurate so nothing slips through the cracks.

## How it fits in the aeon workflow

```
external-feature (files PR) → github-filing-registry (logs it)
       ↑                              ↑
       |                    github-upstream-tracker (syncs state)
       |                              |
       └──────── cron @ 30min ◄────────┘
```

## Steps

1. **Read the registry.**
   ```bash
   REGISTRY="$AEON_ROOT/memory/filing-registry.json"
   ITEMS=$(jq '[.pulls[], .issues[]] | map(select(.is_upstream == true))' "$REGISTRY")
   ```

2. **For each open item**, call GitHub API to get current state:
   ```bash
   # For PRs:
   gh api "repos/$owner/$repo/pulls/$number" --jq '{state, merged, mergeable, reviewDecision, statusCheckRollup}'
   # For issues:
   gh api "repos/$owner/$repo/issues/$number" --jq '{state, labels}'
   ```

3. **Detect state changes.** Compare API result against registry `state` field:
   - `open → closed` — issue closed or PR merged
   - `open → merged` (PR only) — PR was merged
   - Stale: no `last_action` update in >7 days

4. **Update the registry** with detected changes via `filing-registry sync`.

5. **Build the triage report.** Items needing attention:
   - Closed without merge (PR was rejected)
   - Stale >7d with `pending_review` status
   - Filed by you, upstream added a comment but you haven't responded

6. **Send notification** if report is non-empty, otherwise silent.

7. **Log** to `memory/logs/${today}.md` under `### github-upstream-tracker`.

## Triage categories

| Category | Trigger | Next action |
|----------|---------|-------------|
| `REJECTED` | PR closed without merge | Review feedback, decide whether to re-file |
| `MERGED` | PR merged | Archive entry, log as resolved |
| `STALE` | No action >7d | Ping maintainer or close |
| `NEEDS_REVIEW` | Review requested by upstream | Respond to review |
| `COMMENT_ADDED` | Upstream commented | Read comments, respond or acknowledge |

## Notification template

```
*GitHub Upstream Tracker — N filings checked · M need action*

▶ FOLLOW UP
  • owner/repo#123 — PR closed without merge, 3d ago — re-file or close
  • owner/repo#456 — stale 8d, pending review — ping maintainer
▶ ARCHIVED
  • owner/repo#789 — PR merged ✓ (2026-05-03)
```

## Run frequency

Scheduled via aeon.yml cron:
- Every 30 minutes for active tracking
- Daily digest at 09:00 for high-level review

## Constraints

- Only tracks items where `is_upstream == true`
- Never files new issues — only reconciles existing entries
- If GitHub API returns 404 for a tracked item, mark it `closed` and log `TRACKED_ITEM_GONE`
- Rate limit: batch API calls with `gh api graphql` where possible; fall back to per-item calls only when necessary
