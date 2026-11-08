#!/usr/bin/env bash
# Offline tests for skills/github-filing-registry/filing-registry sync P2 behavior.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
FR="$ROOT/skills/github-filing-registry/filing-registry"

fail=0
pass() { echo "ok   - $1"; }
bad()  { echo "FAIL - $1"; fail=1; }
assert_eq() {
  local got="$1" want="$2" name="$3"
  if [[ "$got" == "$want" ]]; then pass "$name"; else bad "$name (got: $got, want: $want)"; fi
}
assert_rc() {
  local want="$1"; shift
  set +e
  "$@"
  local got=$?
  set -e
  if [[ "$got" -eq "$want" ]]; then pass "$* -> rc $want"; else bad "$* -> rc $got, want $want"; fi
}
assert_contains() {
  local hay="$1" needle="$2" name="$3"
  if printf '%s' "$hay" | grep -Fq -- "$needle"; then pass "$name"; else bad "$name (missing: $needle)"; fi
}
assert_not_contains() {
  local hay="$1" needle="$2" name="$3"
  if printf '%s' "$hay" | grep -Fq -- "$needle"; then bad "$name (unexpected: $needle)"; else pass "$name"; fi
}

mk_stub_gh() {
  local bindir="$1"
  mkdir -p "$bindir"
  cat > "$bindir/gh" <<'GHSTUB'
#!/usr/bin/env bash
set -euo pipefail
mode="${GH_STUB_MODE:-ok}"
if [[ "${1:-}" == "api" ]]; then
  endpoint="${2:-}"
  if [[ "$endpoint" =~ /pulls/([0-9]+)$ ]]; then
    num="${BASH_REMATCH[1]}"
    if [[ "$mode" == "fail" ]]; then
      exit 1
    elif [[ "$mode" == "closed_unmerged" ]]; then
      printf '{"state":"closed","merged_at":null,"number":%s}\n' "$num"
      exit 0
    elif [[ "$mode" == "merged" ]]; then
      printf '{"state":"closed","merged_at":"2026-01-01T00:00:00Z","number":%s}\n' "$num"
      exit 0
    else
      printf '{"state":"open","merged_at":null,"number":%s}\n' "$num"
      exit 0
    fi
  elif [[ "$endpoint" =~ /issues/([0-9]+)$ ]]; then
    num="${BASH_REMATCH[1]}"
    if [[ "$mode" == "fail" ]]; then
      exit 1
    elif [[ "$mode" == "closed" ]]; then
      printf '{"state":"closed","number":%s}\n' "$num"
      exit 0
    else
      printf '{"state":"open","number":%s}\n' "$num"
      exit 0
    fi
  fi
  if [[ "$mode" == "fail" ]]; then exit 1; fi
  echo '{}'
  exit 0
fi
echo "unexpected gh call: $*" >&2
exit 99
GHSTUB
  chmod +x "$bindir/gh"
}

mk_registry() {
  local path="$1"
  cat > "$path" <<'JSON'
{
  "version": "1.0",
  "last_synced": "2020-01-01T00:00:00Z",
  "account": "test",
  "pulls": [
    {
      "id": "acme/demo#1",
      "repo": "acme/demo",
      "number": 1,
      "type": "pr",
      "title": "Demo PR",
      "state": "open",
      "status": "pending_review",
      "next_action": "Await",
      "evidence_tier": "",
      "filed_at": "2020-01-01T00:00:00Z",
      "last_action": "2020-01-01T00:00:00Z",
      "url": "https://github.com/acme/demo/pull/1",
      "actions_taken": [],
      "notes": "",
      "labels": [],
      "is_upstream": true
    }
  ],
  "issues": [],
  "activity_log": []
}
JSON
}

# A) sync persists the changed write and advances last_synced.
test_a() {
  local T="$ROOT/.tmp-fr-sync-a.$$"
  rm -rf "$T"; mkdir -p "$T/bin" "$T/memory"
  mk_stub_gh "$T/bin"
  mk_registry "$T/memory/filing-registry.json"
  git -C "$T" init -q
  git -C "$T" config user.email t@example.com
  git -C "$T" config user.name t
  echo x > "$T/f"; git -C "$T" add f; git -C "$T" commit -qm init
  git -C "$T" branch -M main 2>/dev/null || true
  # make it look changed: gh returns closed_unmerged for PR
  local out rc
  set +e
  out=$(AEON_ROOT="$T" REGISTRY="$T/memory/filing-registry.json" PATH="$T/bin:$PATH" GH_STUB_MODE=closed_unmerged \
    bash "$FR" sync 2>&1)
  rc=$?
  set -e
  assert_eq "$rc" "0" "A: sync rc"
  assert_contains "$out" "SYNC_DONE: 1 items updated" "A: prints SYNC_DONE"
  local state status last
  state=$(jq -r '.pulls[0].state' "$T/memory/filing-registry.json")
  status=$(jq -r '.pulls[0].status' "$T/memory/filing-registry.json")
  last=$(jq -r '.last_synced' "$T/memory/filing-registry.json")
  assert_eq "$state" "closed" "A: state persisted"
  assert_eq "$status" "closed" "A: status persisted"
  if [[ "$last" != "2020-01-01T00:00:00Z" ]]; then pass "A: last_synced advanced"; else bad "A: last_synced not advanced"; fi
  rm -rf "$T"
}

# C) failed gh fetch → SYNC_INCOMPLETE, rc != 0.
test_c() {
  local T="$ROOT/.tmp-fr-sync-c.$$"
  rm -rf "$T"; mkdir -p "$T/bin" "$T/memory"
  mk_stub_gh "$T/bin"
  mk_registry "$T/memory/filing-registry.json"
  git -C "$T" init -q
  git -C "$T" config user.email t@example.com
  git -C "$T" config user.name t
  echo x > "$T/f"; git -C "$T" add f; git -C "$T" commit -qm init
  git -C "$T" branch -M main 2>/dev/null || true
  local out rc
  set +e
  out=$(AEON_ROOT="$T" REGISTRY="$T/memory/filing-registry.json" PATH="$T/bin:$PATH" GH_STUB_MODE=fail \
    bash "$FR" sync 2>&1)
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then pass "C: rc non-zero on failed fetch"; else bad "C: rc was 0"; fi
  assert_contains "$out" "SYNC_INCOMPLETE" "C: prints SYNC_INCOMPLETE"
  assert_not_contains "$out" "SYNC_OK" "C: no false-green SYNC_OK"
  rm -rf "$T"
}

# D) malformed repo/number → SYNC_MALFORMED, rc != 0, no gh call made.
test_d() {
  local T="$ROOT/.tmp-fr-sync-d.$$"
  rm -rf "$T"; mkdir -p "$T/bin" "$T/memory"
  mk_stub_gh "$T/bin"
  cat > "$T/memory/filing-registry.json" <<'JSON'
{
  "version": "1.0", "last_synced": "2020-01-01T00:00:00Z", "account": "t",
  "pulls": [{"id":"bad#x","repo":"badrepo","number":null,"type":"pr","title":"Bad","state":"open","status":"pending_review","next_action":"","evidence_tier":"","filed_at":"2020-01-01T00:00:00Z","last_action":"2020-01-01T00:00:00Z","url":"","actions_taken":[],"notes":"","labels":[],"is_upstream":true}],
  "issues": [], "activity_log": []
}
JSON
  git -C "$T" init -q
  git -C "$T" config user.email t@example.com
  git -C "$T" config user.name t
  echo x > "$T/f"; git -C "$T" add f; git -C "$T" commit -qm init
  git -C "$T" branch -M main 2>/dev/null || true
  local log="$T/gh.log"
  # Wrap stub to record calls
  mv "$T/bin/gh" "$T/bin/gh.real"
  cat > "$T/bin/gh" <<WRAP
#!/usr/bin/env bash
echo "\$*" >> "$log"
exec "$T/bin/gh.real" "\$@"
WRAP
  chmod +x "$T/bin/gh"
  local out rc
  set +e
  out=$(AEON_ROOT="$T" REGISTRY="$T/memory/filing-registry.json" PATH="$T/bin:$PATH" GH_STUB_MODE=ok \
    bash "$FR" sync 2>&1)
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then pass "D: rc non-zero on malformed record"; else bad "D: rc was 0"; fi
  assert_contains "$out" "SYNC_MALFORMED" "D: prints SYNC_MALFORMED"
  local calls=0
  [[ -f "$log" ]] && calls=$(wc -l < "$log" | tr -d ' ')
  assert_eq "$calls" "0" "D: no gh call made for malformed record"
  rm -rf "$T"
}

# E) branch preflight
test_e() {
  local T="$ROOT/.tmp-fr-sync-e.$$"
  rm -rf "$T"; mkdir -p "$T/bin" "$T/memory"
  mk_stub_gh "$T/bin"
  mk_registry "$T/memory/filing-registry.json"
  git -C "$T" init -q
  git -C "$T" config user.email t@example.com
  git -C "$T" config user.name t
  echo x > "$T/f"; git -C "$T" add f; git -C "$T" commit -qm init
  git -C "$T" checkout -qb feature-x

  local out rc
  set +e
  out=$(AEON_ROOT="$T" REGISTRY="$T/memory/filing-registry.json" PATH="$T/bin:$PATH" GH_STUB_MODE=ok \
    bash "$FR" sync 2>&1)
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then pass "E: non-main checkout rc != 0"; else bad "E: rc was 0 on non-main"; fi
  assert_contains "$out" "SYNC_BRANCH_MISMATCH" "E: prints SYNC_BRANCH_MISMATCH"

  # With AEON_ALLOW_BRANCH=1, preflight passes; stub gh ok -> no changes -> SYNC_OK.
  # (Proves preflight passed; not SYNC_INCOMPLETE, which would mean fetch happened under fail mode.)
  set +e
  out=$(AEON_ROOT="$T" REGISTRY="$T/memory/filing-registry.json" PATH="$T/bin:$PATH" \
    GH_STUB_MODE=ok AEON_ALLOW_BRANCH=1 bash "$FR" sync 2>&1)
  rc=$?
  set -e
  assert_eq "$rc" "0" "E: AEON_ALLOW_BRANCH=1 proceeds (stub ok -> SYNC_OK)"
  assert_contains "$out" "SYNC_OK" "E: override run reaches sync result"
  rm -rf "$T"
}

# F) overwrite guard (source-extracted) + registry untouched on abort
test_f() {
  local T="$ROOT/.tmp-fr-sync-f.$$"
  rm -rf "$T"; mkdir -p "$T"
  # source-extract the function
  local fn
  fn=$(sed -n '/^sync_overwrite_guard()/,/^}/p' "$FR")
  if [[ -z "$fn" ]]; then bad "F: failed to extract sync_overwrite_guard"; rm -rf "$T"; return; fi
  pass "F: extracted sync_overwrite_guard"

  # helper to build JSON with N items (writes to file to avoid quoting issues)
  make_json_file() {
    local n="$1" path="$2"
    if [[ "$n" -eq 0 ]]; then
      echo '{"pulls":[],"issues":[]}' > "$path"
    else
      python3 - "$n" "$path" <<'PY'
import json,sys
n=int(sys.argv[1]); path=sys.argv[2]
items=[{"id":f"x/y#{i}","repo":"x/y","number":i,"type":"pr","state":"open"} for i in range(n)]
with open(path,'w') as f: json.dump({"pulls":items,"issues":[]}, f)
PY
    fi
  }

  local rc out
  make_json_file 196 "$T/old196.json"; make_json_file 0 "$T/new0.json"
  make_json_file 10 "$T/old10.json"; make_json_file 50 "$T/old50.json"
  make_json_file 1 "$T/new1.json"; make_json_file 51 "$T/old51.json"

  # Define the guard in this shell (eval, not bash -c, so "$(cat file)" quoting stays intact).
  eval "$fn"

  set +e
  out=$(sync_overwrite_guard "$(cat "$T/old196.json")" "$(cat "$T/new0.json")" 2>&1); rc=$?
  set -e
  assert_eq "$rc" "4" "F: 196->0 rc 4"
  assert_contains "$out" "SYNC_OVERWRITE_GUARD" "F: 196->0 prints guard message"

  set +e; sync_overwrite_guard "$(cat "$T/old10.json")" "$(cat "$T/new0.json")" >/dev/null 2>&1; rc=$?; set -e
  assert_eq "$rc" "0" "F: 10->0 rc 0"
  set +e; sync_overwrite_guard "$(cat "$T/old50.json")" "$(cat "$T/new0.json")" >/dev/null 2>&1; rc=$?; set -e
  assert_eq "$rc" "0" "F: 50->0 rc 0"
  set +e; sync_overwrite_guard "$(cat "$T/old51.json")" "$(cat "$T/new1.json")" >/dev/null 2>&1; rc=$?; set -e
  assert_eq "$rc" "0" "F: 51->1 rc 0"

  # Registry untouched after guard abort: function returns 4 and makes no writes.
  make_json_file 51 "$T/reg.json"; make_json_file 0 "$T/zero.json"
  local before after
  before=$(sha256sum "$T/reg.json" | awk '{print $1}')
  set +e; sync_overwrite_guard "$(cat "$T/reg.json")" "$(cat "$T/zero.json")" >/dev/null 2>&1; rc=$?; set -e
  after=$(sha256sum "$T/reg.json" | awk '{print $1}')
  assert_eq "$rc" "4" "F: direct guard abort rc 4"
  assert_eq "$before" "$after" "F: registry file untouched after guard abort"
  rm -rf "$T"
}

# G) retention end-to-end
test_g() {
  local T="$ROOT/.tmp-fr-sync-g.$$"
  rm -rf "$T"; mkdir -p "$T/bin" "$T/memory"
  mk_stub_gh "$T/bin"
  mk_registry "$T/memory/filing-registry.json"
  git -C "$T" init -q
  git -C "$T" config user.email t@example.com
  git -C "$T" config user.name t
  echo x > "$T/f"; git -C "$T" add f; git -C "$T" commit -qm init
  # ensure on main
  git -C "$T" branch -M main 2>/dev/null || true

  local D="$T/memory"
  # audit evidence (must keep)
  echo a > "$D/filing-registry.json.bak-20261030-empty-skeleton"
  echo b > "$D/filing-registry.json.bak-20261030-restore-pre-edit"
  # exact-date dailies bak-20261009 .. bak-20261015 (6 files)
  for d in 20261009 20261010 20261011 20261012 20261013 20261014; do
    echo "$d" > "$D/filing-registry.json.bak-$d"
  done
  # timestamped (prune) and suffixed (prune)
  echo t > "$D/filing-registry.json.bak-20261010T002524Z"
  echo s > "$D/filing-registry.json.bak-20261011-123456"
  # .pre-* files (prune)
  echo p > "$D/filing-registry.json.pre-foo"
  echo p > "$D/filing-registry.pre-bar"

  local out rc
  set +e
  out=$(AEON_ROOT="$T" REGISTRY="$D/filing-registry.json" PATH="$T/bin:$PATH" GH_STUB_MODE=ok \
    bash "$FR" sync 2>&1)
  rc=$?
  set -e
  assert_eq "$rc" "0" "G: sync rc 0"
  assert_contains "$out" "SYNC_OK" "G: prints SYNC_OK"

  # audit evidence kept
  [[ -f "$D/filing-registry.json.bak-20261030-empty-skeleton" ]] && pass "G: empty-skeleton kept" || bad "G: empty-skeleton missing"
  [[ -f "$D/filing-registry.json.bak-20261030-restore-pre-edit" ]] && pass "G: restore-pre-edit kept" || bad "G: restore-pre-edit missing"
  # all 6 exact-date dailies present
  local missing_daily=0
  for d in 20261009 20261010 20261011 20261012 20261013 20261014; do
    [[ -f "$D/filing-registry.json.bak-$d" ]] || missing_daily=1
  done
  assert_eq "$missing_daily" "0" "G: all exact-date dailies present"
  # pruned
  [[ ! -e "$D/filing-registry.json.bak-20261010T002524Z" ]] && pass "G: timestamped bak pruned" || bad "G: timestamped bak still present"
  [[ ! -e "$D/filing-registry.json.bak-20261011-123456" ]] && pass "G: suffixed bak pruned" || bad "G: suffixed bak still present"
  [[ ! -e "$D/filing-registry.json.pre-foo" ]] && pass "G: .pre-foo pruned" || bad "G: .pre-foo still present"
  [[ ! -e "$D/filing-registry.pre-bar" ]] && pass "G: .pre-bar pruned" || bad "G: .pre-bar still present"

  local today manifest
  today=$(date -u +%Y%m%d)
  manifest="$D/pruned-baks-$today.txt"
  [[ -f "$manifest" ]] && pass "G: pruned-baks manifest exists" || bad "G: manifest missing"
  if [[ -f "$manifest" ]]; then
    assert_contains "$(cat "$manifest")" "filing-registry.json.bak-20261010T002524Z" "G: manifest lists timestamped"
    assert_contains "$(cat "$manifest")" "filing-registry.json.bak-20261011-123456" "G: manifest lists suffixed"
    assert_contains "$(cat "$manifest")" "filing-registry.json.pre-foo" "G: manifest lists .pre-foo"
  fi

  local bak_count
  bak_count=$(ls "$D"/*.bak* "$D"/*.pre-* 2>/dev/null | wc -l | tr -d ' ' || true)
  assert_eq "$bak_count" "8" "G: bak/pre count == 8"

  rm -rf "$T"
}

test_a
test_c
test_d
test_e
test_f
test_g

echo
if [[ "$fail" -eq 0 ]]; then
  echo "ALL PASS"
  exit 0
else
  echo "SOME FAILURES"
  exit 1
fi
