---
name: GitHub Upstream Tracker
description: Watch your filed PRs across upstream repositories — detect closures, merges, stale items, and needed follow-ups. Reconcile against memory/filing-registry.json every 30 minutes. Auto-discovers new filings you made via gh pr create and imports them automatically.
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

### Step 0 — Discover new filings *(auto-import)*

Scan recent GH activity for your PRs that aren't in the registry yet. This catches filings made via `gh pr create` or the GitHub UI directly — no need to manually register them.

```bash
AEON_ROOT="${AEON_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
REGISTRY="$AEON_ROOT/memory/filing-registry.json"
FILING_REGISTRY="$AEON_ROOT/skills/github-filing-registry/filing-registry"

GH_USER=$(gh api user --jq '.login')
CUTOFF=$(date -u -d '60 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-60d +%Y-%m-%d)
echo "Discovering filings for: $GH_USER (window: >$CUTOFF)"

DISCOVER_CMD='gh api graphql -f query="
  {
    search(query: \"author:${GH_USER} type:pr created:\>${CUTOFF}\", type: ISSUE, first: 50) {
      nodes {
        ... on PullRequest {
          number
          repository { nameWithOwner }
          title
          state
          url
        }
      }
    }
  }" --jq ".data.search.nodes | .[] | \"\\(.repository.nameWithOwner)#\\(.number)|\\(.title)|\\(.state)|\\(.url)\""'

# Run discovery and import new filings
IMPORTED=0
while IFS='|' read -r id title state url; do
  [[ -z "$id" || "$id" == "null" ]] && continue

  # Skip if already in registry
  existing=$(cat "$REGISTRY" | jq --arg id "$id" '[.pulls[], .issues[]] | map(select(.id == $id)) | length')
  [[ "$existing" -gt 0 ]] && continue

  echo "Importing: $id — $title"
  "$FILING_REGISTRY" add \
    --id "$id" \
    --type pr \
    --title "$title" \
    --evidence tier_2 \
    --url "$url" \
    2>/dev/null && IMPORTED=$((IMPORTED + 1)) || true

  sleep 1  # GH API rate limit courtesy
done < <(eval "$DISCOVER_CMD" 2>/dev/null)

echo "Discovery: $IMPORTED new filing(s) imported"

# Also discover issues (separate search)
ISSUE_CMD='gh api graphql -f query="
  {
    search(query: \"author:${GH_USER} type:issue created:\>${CUTOFF}\", type: ISSUE, first: 30) {
      nodes {
        ... on Issue {
          number
          repository { nameWithOwner }
          title
          state
          url
        }
      }
    }
  }" --jq ".data.search.nodes | .[] | \"\\(.repository.nameWithOwner)#\\(.number)|\\(.title)|\\(.state)|\\(.url)\""'

while IFS='|' read -r id title state url; do
  [[ -z "$id" || "$id" == "null" || "$url" == *"pull"* ]] && continue
  existing=$(cat "$REGISTRY" | jq --arg id "$id" '[.pulls[], .issues[]] | map(select(.id == $id)) | length')
  [[ "$existing" -gt 0 ]] && continue

  echo "Importing issue: $id — $title"
  "$FILING_REGISTRY" add \
    --id "$id" \
    --type issue \
    --title "$title" \
    --evidence tier_2 \
    --url "$url" \
    2>/dev/null && IMPORTED=$((IMPORTED + 1)) || true
  sleep 1
done < <(eval "$ISSUE_CMD" 2>/dev/null)

echo "Total imported this run: $IMPORTED"

### Step 1 — Read the registry

```bash
REGISTRY="$AEON_ROOT/memory/filing-registry.json"
ITEMS=$(jq '[.pulls[], .issues[]] | map(select(.is_upstream == true))' "$REGISTRY")
```

### Step 2 — Sync each tracked item against GitHub

For each open item, call GitHub API to get current state:
```bash
# For PRs:
gh api "repos/$owner/$repo/pulls/$number" --jq '{state, merged, mergeable, reviewDecision, statusCheckRollup}'
# For issues:
gh api "repos/$owner/$repo/issues/$number" --jq '{state, labels}'
```

Detect state changes. Compare API result against registry `state` field:
- `open → closed` — issue closed or PR merged
- `open → merged` (PR only) — PR was merged
- Stale: no `last_action` update in >7 days

### Step 3 — Update the registry

Use `filing-registry sync` to reconcile detected changes:
```bash
"$FILING_REGISTRY" sync
```

### Step 4 — Build the triage report

Items needing attention:
- Closed without merge (PR was rejected)
- Stale >7d with `pending_review` status
- Filed by you, upstream added a comment but you haven't responded

### Step 5 — Send notification

If report is non-empty → send to configured channel. Otherwise silent.

### Step 6 — Log

Write to `memory/logs/${today}.md` under `### github-upstream-tracker`.

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
▶ NEWLY TRACKED
  • owner/repo#789 — auto-imported from GH search (2026-05-09)
▶ ARCHIVED
  • owner/repo#789 — PR merged ✓ (2026-05-03)
```

## Run frequency

Scheduled via aeon.yml cron:
- Every 30 minutes for active tracking
- Daily digest at 09:00 for high-level review

## Constraints

- Only tracks items where `is_upstream == true`
- If GitHub API returns 404 for a tracked item, mark it `closed` and log `TRACKED_ITEM_GONE`
- Rate limit: batch API calls with `gh api graphql` where possible; fall back to per-item calls only when necessary
- Discovery window: 60 days — balances freshness against API quota
- Discovery step is idempotent — safe to re-run; entries already in registry are skipped