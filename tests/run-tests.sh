#!/bin/bash
# tests/run-tests.sh — offline tests. No Azure, no ServiceNow, no network. Run on macOS bash 3.2.
cd "$(dirname "$0")/.." || exit 1
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
expect() { # name expected_rc cmd...
  local name="$1" want="$2"; shift 2
  "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" = "$want" ]; then ok "$name"; else bad "$name (rc=$rc, wanted $want)"; fi
}
GATE=bin/azvm-gate
epoch() { date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null || date -u -d "$1" +%s; }
IN=$(epoch 2026-11-03T03:00:00Z); BEFORE=$(epoch 2026-11-03T01:00:00Z); AFTER=$(epoch 2026-11-03T05:00:00Z)
F=tests/fixtures/change-ok.json; S=tests/fixtures/snow-ok.json

echo "syntax"
for f in bin/* lib/*.sh tests/*.sh; do bash -n "$f" 2>/dev/null && ok "bash -n $f" || bad "bash -n $f"; done

echo "gate: none provider"
expect "denies mutating action with no change control" 10 env GATE_PROVIDER=none $GATE check --action resize --vm example-vm
expect "lab override is explicit"                      0  env GATE_PROVIDER=none AZVM_ALLOW_NO_GATE=1 $GATE check --action resize --vm example-vm

echo "gate: file provider"
base() { env M4A_NOW=$IN GATE_PROVIDER=file GATE_FILE=$F "$@"; }
expect "allows: right change, vm, action, window"      0  base $GATE check --action resize --vm example-vm --change CHG0030001
expect "denies: wrong change id"                       10 base $GATE check --action resize --vm example-vm --change CHG0099999
expect "denies: wrong vm"                              10 base $GATE check --action resize --vm other-vm   --change CHG0030001
expect "denies: action not authorized"                 10 base $GATE check --action quota  --vm example-vm --change CHG0030001
expect "denies: no change id"                          10 base $GATE check --action resize --vm example-vm
expect "denies: before the window"                     10 env M4A_NOW=$BEFORE GATE_PROVIDER=file GATE_FILE=$F $GATE check --action resize --vm example-vm --change CHG0030001
expect "denies: after the window"                      10 env M4A_NOW=$AFTER  GATE_PROVIDER=file GATE_FILE=$F $GATE check --action resize --vm example-vm --change CHG0030001
expect "denies: state not implement"                   10 env GATE_OK_STATES=review M4A_NOW=$IN GATE_PROVIDER=file GATE_FILE=$F $GATE check --action resize --vm example-vm --change CHG0030001
expect "denies: unreadable change file"                10 env M4A_NOW=$IN GATE_PROVIDER=file GATE_FILE=/nonexistent $GATE check --action resize --vm example-vm --change CHG0030001
expect "extra local window can narrow a valid change"  10 base env AZVM_WINDOW_END=2026-11-03T02:30:00Z $GATE check --action resize --vm example-vm --change CHG0030001

echo "gate: servicenow provider (fixture of the documented response shape; NOT a live instance)"
sn() { env M4A_NOW=$IN GATE_PROVIDER=servicenow SNOW_FIXTURE=$S "$@"; }
expect "allows: implement + approved + CI matches + in window" 0  sn $GATE check --action resize --vm example-vm --change CHG0030001
expect "denies: CI is a different VM"                           10 sn $GATE check --action resize --vm other-vm   --change CHG0030001
expect "denies: wrong number returned"                          10 sn $GATE check --action resize --vm example-vm --change CHG0099999
expect "denies: outside window"                                 10 env M4A_NOW=$AFTER GATE_PROVIDER=servicenow SNOW_FIXTURE=$S $GATE check --action resize --vm example-vm --change CHG0030001
expect "denies: state value not in SNOW_OK_STATES"              10 sn env SNOW_OK_STATES="0" $GATE check --action resize --vm example-vm --change CHG0030001
expect "refuses a host outside *.service-now.com"               10 env GATE_PROVIDER=servicenow SNOW_INSTANCE=evil.example.com $GATE check --action resize --vm example-vm --change CHG0030001

echo "gate: json contract"
out=$(base $GATE check --action resize --vm example-vm --change CHG0030001 --json 2>/dev/null)
[ "$(printf '%s' "$out" | jq -r .verdict 2>/dev/null)" = ALLOW ] && ok "json verdict ALLOW" || bad "json verdict ALLOW"

echo "policy files are valid JSON"
for f in policy/definitions/*.json policy/*.json; do [ -f "$f" ] || continue; jq -e . "$f" >/dev/null 2>&1 && ok "$f" || bad "$f"; done

echo; echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
