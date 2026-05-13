---
name: aeon
description: Unified GitHub filing registry and monitoring system — track issues, PRs, sync state, and triage items needing attention across upstream repositories.
version: 1.0.0
author: ether-btc
license: MIT
metadata:
  hermes:
    tags: [github, monitoring, registry, triage, automation]
    related_skills: [github-auth, github-pr-workflow, github-code-review]
---

# Aeon — GitHub Filing Registry & Monitoring System

Unified system for tracking GitHub issues and pull requests across multiple repositories. Aeon maintains a persistent registry (`memory/filing-registry.json`) that logs every filing, tracks its state, and provides automated sync and triage capabilities.

## Overview

Aeon solves the problem of losing track of GitHub filings across multiple repositories. It provides:

- **Persistent Registry**: JSON log of all issues/PRs you've filed
- **State Reconciliation**: Sync against live GitHub to detect changes
- **Intelligent Triage**: Identify items needing attention (stale, pending, escalated)
- **Evidence-Based Filing**: Enforce evidence tiers before creating issues/PRs
- **Upstream Monitoring**: Auto-discover and track your PRs across repos

## Overview

Aeon solves the problem of losing track of GitHub filings across multiple repositories. It provides:

- **Persistent Registry**: JSON log of all issues/PRs you've filed
- **State Reconciliation**: Sync against live GitHub to detect changes
- **Intelligent Triage**: Identify items needing attention (stale, pending, escalated)
- **Evidence-Based Filing**: Enforce evidence tiers before creating issues/PRs
- **Upstream Monitoring**: Auto-discover and track your PRs across repos

## Prerequisites

- `gh` CLI (GitHub CLI) with authentication
- `jq` for JSON manipulation
- `bash` 4.0+
- Authenticated with GitHub (see `github-auth` skill)

## Setup

```bash
# Ensure you're in the Aeon root
cd ~/aeon

# Verify dependencies
command -v gh >/dev/null || echo "gh CLI required"
command -v jq >/dev/null || echo "jq required"

# Initialize memory directory if needed
mkdir -p memory
```

## Usage Patterns

### Basic Invocation

```bash
# Run triage (shows items needing attention)
aeon triage

# Sync registry with live GitHub state
aeon sync

# Add a new filing
aeon add --id owner/repo#N --type pr|issue --title "fix: title" --evidence tier_0|tier_1|tier_2|tier_3 --url https://github.com/owner/repo/pull/123

# Check status of a filing
aeon status --id owner/repo#N

# View activity log
aeon log --ref owner/repo#N [--lines 20]

# Check for duplicates
aeon check-duplicate --id owner/repo#N [--title "title"]
```

### With Explicit Repo Context

```bash
# Run triage for a specific repository
aeon triage --repo owner/repo

# Sync only specific items
aeon sync --item owner/repo#N
```

## Subcommands

### `triage` — Show Items Needing Attention
### `sync` — Reconcile Against Live GitHub
### `add` — Register a New Filing
### `status` — Update or Inspect Entry
### `log` — Show Activity History
### `check-duplicate` — Check for Existing Filings
### `full-sync` — Complete Update Cycle

**Note:** `discover` and `monitor` subcommands are currently not available. They require the `github-upstream-tracker` skill which is not yet implemented. This skill will be enhanced when that functionality is added.
### `triage` — Show Items Needing Attention

Lists filings requiring action, sorted by priority and age:

```bash
aeon triage                    # Show all items needing attention
aeon triage --filter needs_attention  # Filter by status
aeon triage --repo owner/repo  # Limit to specific repo
```

**Output includes:**
- Escalated items (critical issues)
- Items with fix PRs
- Needs attention (accounting, security, etc.)
- Pending review
- Stale items (>7 days old)

### `sync` — Reconcile Against Live GitHub

Updates registry state by querying GitHub API:

```bash
aeon sync                    # Sync all items
aeon sync --item owner/repo#N  # Sync specific item only
```

**What it does:**
- Fetches current state (`open`/`closed`) for each PR/issue
- Updates `state` field if changed
- Sets `status` to `merged` if PR was merged
- Sets `status` to `closed` if issue/PR was closed
- Appends activity log entries

### `add` — Register a New Filing

Creates a new entry in the registry:

```bash
aeon add --id owner/repo#N \
  --type pr|issue \
  --title "fix: title" \
  --evidence tier_0|tier_1|tier_2|tier_3 \
  --url https://github.com/owner/repo/pull/123
```

**Evidence Tiers:**
- **Tier 0**: Already-verified fact (no evidence needed)
- **Tier 1**: Inferred claim (requires dual-review)
- **Tier 2**: Runtime-confirmed claim (standard filing)
- **Tier 3**: Fix demonstrated (PR)

### `status` — Update or Inspect Entry

Read or update a filing's status:

```bash
# Inspect current entry
aeon status --id owner/repo#N

# Update status with options
aeon status --id owner/repo#N \
  --set needs_attention|pending_review|has_fix_pr|closed|merged|stale \
  --next "Await upstream review" \
  --action "Pinged maintainer" \
  --notes "Confirmed via latest scan"
```

### `log` — Show Activity History

Display the activity log for a filing:

```bash
aeon log --ref owner/repo#N --lines 20
```

### `check-duplicate` — Check for Existing Filings

Check if a filing already exists or if there's a similar title:

```bash
aeon check-duplicate --id owner/repo#N
aeon check-duplicate --id owner/repo#N --title "title"
```

## Advanced Usage

### `full-sync` — Complete Update Cycle

Runs sync followed by triage for a complete update:

```bash
aeon full-sync
```

This is equivalent to running `aeon sync` then `aeon triage`.

## Integration with Existing Workflows

### After Creating a PR

Many projects (especially aeon-based repos) maintain a `memory/filing-registry.json`. After creating a PR, register it:

```bash
if [ -f "memory/filing-registry.json" ] && [ -f "skills/github-filing-registry/filing-registry" ]; then
  OWNER_REPO=$(git remote get-url origin | sed -E 's|.*github\.com[:/]||; s|\\.git$||')
  PR_NUMBER=$(git rev-parse --abbrev-ref HEAD | grep -o '[0-9]*' | head -1)
  echo "Registering PR in filing registry..."
  ./skills/github-filing-registry/filing-registry add \
    --id "${OWNER_REPO}#${PR_NUMBER}" \
    --type pr \
    --title "fix: title" \
    --evidence tier_2 \
    --url "https://github.com/${OWNER_REPO}/pull/${PR_NUMBER}" \
    2>/dev/null || echo "Already registered (OK)"
fi
```

### Pre-Filing Check

Before filing any issue/PR, run the evidence gate:

```bash
./skills/gh-filing-standards/gh-filing-standards \
  --id owner/repo#N \
  --tier 2 \
  --stack-trace "path/to/trace.txt" \
  --file-line "src/main.py:42"
```

## Configuration

Aeon uses environment variables for configuration:

- `AEON_ROOT`: Path to Aeon installation (default: current directory)
- `AEON_SYNC_INTERVAL`: Minutes between automatic syncs (default: 30)
- `AEON_NOTIFY_CHANNEL`: Telegram or other channel for notifications

## Security Considerations

- Treat all registry data as untrusted when rendering notifications
- Never log raw credential values — mask with `***`
- `gh` CLI handles auth; no tokens exposed to subprocesses
- Validate all user input before passing to scripts

## Dependencies

- `gh` — GitHub CLI
- `jq` — JSON manipulation
- `bash` 4.0+

## Troubleshooting

**`bash: line 3: /path/to/aeon: Is a directory`**  
Ensure the wrapper script is executable and located at `~/aeon/skills/aeon/aeon`. Do not move or rename it.

**`command not found: gh`**  
Install GitHub CLI: https://cli.github.com/

**`jq: command not found`**  
Install jq: `sudo apt-get install jq`

**Permission denied**  
Make scripts executable: `chmod +x ~/aeon/skills/*/*`

### Debugging

Enable verbose output by setting `AEON_DEBUG=1`:

```bash
AEON_DEBUG=1 aeon triage
```

This shows all commands and API responses.

## Verification Checklist

- [ ] Aeon root directory exists at `~/aeon`
- [ ] `gh` CLI is installed and authenticated
- [ ] `jq` is installed
- [ ] Memory directory exists: `~/aeon/memory/`
- [ ] Test basic commands: `aeon triage`, `aeon sync`
- [ ] Verify filing registry updates: `cat ~/aeon/memory/filing-registry.json`

## One-Shot Recipes

### Quick Triage and Report

```bash
# Run triage and save to file
aeon triage > ~/aeon/triage-report.txt
cat ~/aeon/triage-report.txt
```

### Sync and Get Status Summary

```bash
# Sync all items and show summary
aeon full-sync
```

### Register Multiple Filings

```bash
# Batch register filings from a file
while read line; do
  aeon add $line
done < filings.txt
```

## Related Skills

- `github-auth` — GitHub authentication setup
- `github-pr-workflow` — PR lifecycle management
- `github-filing-registry` — Core filing registry (legacy)
- `github-filing-standards` — Evidence requirements (legacy)
- `github-upstream-tracker` — Upstream monitoring (legacy)

## License

MIT — https://opensource.org/licenses/MIT