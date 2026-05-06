---
name: GitHub Filing Standards
description: Evidence requirements and pre-filing verification gates for autonomous GitHub issue and PR submissions — prevents hallucinated bug reports from being filed.
var: ""
tags: [dev, github, quality-gates]
depends_on: [github-filing-registry]
---

> **${var}** — Optional. Accepts `owner/repo#N --tier 1|2|3` for a single check. If empty, this skill runs the pre-filing checklist against an implied target.

Every GitHub issue or PR you file must pass the evidence gate before submission. Filing an unverified claim wastes maintainer time and damages credibility. This skill enforces evidence tiers so the autonomous agent only files things it can stand behind.

## Core Principle

**Every GitHub filing must have verifiable evidence before submission.** Filing on a "theoretical possibility" is worse than filing nothing.

## Evidence Tiers

### Tier 0 — Already-Verified Fact
No evidence needed. The claim is confirmed by prior work in this session.
- Example: "Issue #42 is still open per our last scan"
- Action: Reference prior work in the filing body

### Tier 1 — Inferred Claim *(requires dual-review)*
The agent found a pattern, static analysis signal, or theoretical issue. No runtime proof.
- **Evidence requirement:** Two independent code paths confirming the same issue
- **Filing format:** Title must be prefixed `[UNVERIFIED]` until Tier 2 confirmed
- **Before filing:** A second autonomous check must confirm the finding independently
- **This skill gate:** Requires `--dual-confirm` flag or the second checker's confirmation attached

### Tier 2 — Runtime-Confirmed Claim *(standard filing)*
The issue has been triggered, reproduced, or has a stack trace.
- **Evidence requirement:** Stack trace OR reproducible test case OR exact file:line reference
- **Filing format:** Standard issue — no prefix needed
- **This skill gate:** Requires `--stack-trace`, `--file-line`, or `--test-case` flag

### Tier 3 — Fix Demonstrated *(PR)*
A PR that fixes a confirmed issue.
- **Evidence requirement:** Fix is implemented, tested, and does not break existing tests
- **This skill gate:** Requires `--fix-url` linking to the issue being fixed

## Pre-Flight Checklist

Before any `gh issue create` or `gh pr create`, verify ALL of:

```
PRE-FLIGHT GATE
  - [ ] ID (owner/repo#N) is valid and reachable via gh api
  - [ ] For bug reports: stack trace attached OR reproducible test case
  - [ ] For security claims: proof-of-concept OR CVSS justification
  - [ ] For feature requests: use case justification present
  - [ ] Title matches the evidence tier (Tier 1 = [UNVERIFIED] prefix)
  - [ ] Body does NOT claim certainty beyond the evidence tier
  - [ ] Duplicate check: ./filing-registry check-duplicate owner/repo#N --title "..."
```

## Subcommands

### check — Run the full pre-flight gate

```bash
./gh-filing-standards check owner/repo#N \
  --tier 0|1|2|3 \
  --title "session/learn.rs:40 — panic on unwrap of None" \
  [--stack-trace "thread 'main' panicked at..."] \
  [--file-line src/session/learn.rs:40] \
  [--test-case "cargo test session::learn::test_collapse"] \
  [--dual-confirm "Confirmed by independent scan"]
```

Exits 0 if gate passes, exits 1 with a reason if it fails.

### verify-file — Confirm a file:line reference exists

```bash
./gh-filing-standards verify-file owner/repo \
  src/session/learn.rs 40 "unwrap()"
```

Fetches the file via GitHub API and confirms the line contains the expected snippet.

### format-issue — Format the issue body with evidence block

```bash
./gh-filing-standards format-issue \
  --title "session/learn.rs:40 — panic on unwrap of None" \
  --tier 2 \
  --evidence "Stack trace attached. Triggered by session::learn::collapse(true)." \
  --cited owner/repo#99
```

Outputs a properly formatted issue body with evidence section, reproduction steps, and context.

## Steps (when running as a skill)

1. **Parse the target.** Read `${var}` as `owner/repo#N` or just `owner/repo`.

2. **Run duplicate check.**
   ```bash
   cd "$AEON_ROOT"
   ./skills/github-filing-registry/filing-registry check-duplicate "$TARGET" \
     --title "$(echo "$title" | sed 's/"/\\"/g')"
   ```
   If duplicate found — log and skip filing.

3. **Fetch target state** to confirm it exists and is still relevant.
   ```bash
   gh issue view "$NUMBER" -R "$OWNER/$REPO" --json number,title,state,labels 2>/dev/null
   gh pr view "$NUMBER" -R "$OWNER/$REPO" --json number,title,state 2>/dev/null
   ```

4. **Apply evidence tier check.** If tier 1:
   - Check that `--dual-confirm` or equivalent evidence is present
   - If missing, output `GATE_FAIL: tier_1_requires_dual_confirmation`

5. **Format and emit the filing body** using `format-issue` subcommand output.

6. **Register the filing** in the registry.
   ```bash
   ./filing-registry add "$TARGET" --type issue --title "$title" \
     --evidence "tier_$N" --url "$url"
   ```

## Evidence block template

```
## Evidence

**Tier:** Tier N — [tier description]

**What:** [1 sentence — what is broken or missing]

**Where:** `owner/repo@file:line` or `stack trace`

**How to reproduce:**
[if applicable — exact steps]

**Prior work:** [if tier 0 — reference prior session work]
```

## Filing format rules

- Bug reports: `{file}:{line} — {concise description}`
  - GOOD: `session/learn.rs:40 — panic on unwrap of None`
  - BAD: `Bug in session module`
- Feature requests: `[feature]: {concise description}`
- Security: `[security]: {concise description}`
- Tier 1 MUST have `[UNVERIFIED]` prefix on title until dual-confirmed

## Notification

- Gate fail: `./notify "gh-filing-standards: GATE_FAIL — $REASON — $TARGET — $title"`
- Gate pass: silent (the filing skill that called this will notify)
- `GITHUB_FILING_STANDARDS_SKIP=1` env var bypasses gate (for automated testing)

## Environment Variables

- `GITHUB_FILING_STANDARDS_SKIP` — set to skip gate (testing only)

## Constraints

- NEVER bypass the tier 1 dual-confirmation requirement
- NEVER file without running duplicate check first
- NEVER use Tier 2 evidence requirements for Tier 1 filings
- If `gh api` returns 404 for the target, gate fails with `TARGET_NOT_FOUND`
