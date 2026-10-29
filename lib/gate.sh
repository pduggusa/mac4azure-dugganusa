#!/bin/bash
# lib/gate.sh — the change-control gate. Pure: it makes no Azure calls.
#
# m4a_gate <action> <vm>   returns 0 = allowed, 10 = denied (reason in GATE_REASON).
#
# Providers (GATE_PROVIDER):
#   none         no change control. Mutating actions are DENIED unless AZVM_ALLOW_NO_GATE=1 (lab use only).
#   file         a JSON change record on disk (GATE_FILE). The portable provider and the test double.
#   servicenow   ServiceNow Table API, change_request. See docs/SERVICENOW.md. NOT tested against a live
#                instance by us; the parsing is tested against a fixture of the documented response shape.
#
# On top of any provider, AZVM_WINDOW_START / AZVM_WINDOW_END (UTC) add a local maintenance-window check.
# There is deliberately NO bypass flag. The emergency path is a human using az directly under your own policy.

GATE_REASON=""

_gate_now() { printf '%s' "${M4A_NOW:-$(date -u +%s)}"; }

m4a_window_ok() { # start end (either may be empty = unbounded)
  local now s e
  now=$(_gate_now)
  if [ -n "${1:-}" ]; then
    s=$(m4a_epoch "$1") || { GATE_REASON="unparseable window start '$1'"; return 10; }
    [ "$now" -ge "$s" ] || { GATE_REASON="before the maintenance window opens ($1)"; return 10; }
  fi
  if [ -n "${2:-}" ]; then
    e=$(m4a_epoch "$2") || { GATE_REASON="unparseable window end '$2'"; return 10; }
    [ "$now" -le "$e" ] || { GATE_REASON="after the maintenance window closed ($2)"; return 10; }
  fi
  return 0
}

_gate_file() { # action vm
  local f="${GATE_FILE:-}" id st ws we cvm who
  [ -n "$f" ] && [ -r "$f" ] || { GATE_REASON="GATE_FILE is not set or not readable"; return 10; }
  jq -e . "$f" >/dev/null 2>&1 || { GATE_REASON="GATE_FILE is not valid JSON"; return 10; }
  [ -n "${CHANGE_ID:-}" ] || { GATE_REASON="no change id (pass --change or set CHANGE_ID)"; return 10; }
  id=$(jq -r '.change_id // ""' "$f");        [ "$id" = "$CHANGE_ID" ] || { GATE_REASON="change record is for '$id', not '$CHANGE_ID'"; return 10; }
  st=$(jq -r '.state // ""' "$f" | tr 'A-Z' 'a-z')
  case " ${GATE_OK_STATES:-implement} " in *" $st "*) ;; *) GATE_REASON="change state is '$st', need one of: ${GATE_OK_STATES:-implement}"; return 10;; esac
  cvm=$(jq -r '.vm // ""' "$f");              [ "$cvm" = "$2" ] || { GATE_REASON="change record is for VM '$cvm', not '$2'"; return 10; }
  jq -e --arg a "$1" '(.actions // []) | index($a) != null' "$f" >/dev/null 2>&1 || { GATE_REASON="change record does not authorize action '$1'"; return 10; }
  who=$(jq -r '.approved_by // ""' "$f");     [ -n "$who" ] || { GATE_REASON="change record has no approved_by"; return 10; }
  ws=$(jq -r '.window_start // ""' "$f"); we=$(jq -r '.window_end // ""' "$f")
  [ -n "$ws" ] && [ -n "$we" ] || { GATE_REASON="change record has no maintenance window"; return 10; }
  m4a_window_ok "$ws" "$we"
}

# Fetch one change_request row. Credentials never touch argv: curl reads its config from stdin.
# Keychain items: service "mac4azure-snow", account = $SNOW_USER (password) or "token" (bearer).
_snow_fetch() { # change number
  local host="${SNOW_INSTANCE:-}" cfg url pw tok
  [ -n "$host" ] || { GATE_REASON="SNOW_INSTANCE is not set"; return 10; }
  printf '%s' "$host" | grep -Eq "${SNOW_HOST_REGEX:-^[a-z0-9-]+\.service-now\.com$}" \
    || { GATE_REASON="SNOW_INSTANCE does not match the allowed host pattern (credentials are only sent there)"; return 10; }
  printf '%s' "$1" | grep -Eq '^[A-Za-z]{2,6}[0-9]{4,12}$' || { GATE_REASON="change id '$1' is not in the expected form"; return 10; }
  url="https://$host/api/now/table/change_request?sysparm_query=number%3D$1&sysparm_limit=1&sysparm_display_value=all&sysparm_fields=number,state,approval,start_date,end_date,cmdb_ci,type"
  if tok=$(security find-generic-password -s mac4azure-snow -a token -w 2>/dev/null) && [ -n "$tok" ]; then
    cfg=$(printf 'header = "Authorization: Bearer %s"\nheader = "Accept: application/json"\n' "$tok")
  else
    [ -n "${SNOW_USER:-}" ] || { GATE_REASON="no keychain token and SNOW_USER is not set"; return 10; }
    pw=$(security find-generic-password -s mac4azure-snow -a "$SNOW_USER" -w 2>/dev/null) || { GATE_REASON="no keychain password for $SNOW_USER (service mac4azure-snow)"; return 10; }
    pw=$(printf '%s' "$pw" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    cfg=$(printf 'user = "%s:%s"\nheader = "Accept: application/json"\n' "$SNOW_USER" "$pw")
  fi
  printf '%s\n' "$cfg" | curl --silent --show-error --fail --max-time 20 --proto '=https' -K - "$url"
}

_gate_snow() { # action vm
  local json st ap ws we ci num
  if [ -n "${SNOW_FIXTURE:-}" ]; then
    json=$(cat "$SNOW_FIXTURE" 2>/dev/null) || { GATE_REASON="SNOW_FIXTURE unreadable"; return 10; }
  else
    [ -n "${CHANGE_ID:-}" ] || { GATE_REASON="no change id (pass --change or set CHANGE_ID)"; return 10; }
    json=$(_snow_fetch "$CHANGE_ID") || { [ -n "$GATE_REASON" ] || GATE_REASON="ServiceNow lookup failed"; return 10; }
  fi
  printf '%s' "$json" | jq -e '.result | length > 0' >/dev/null 2>&1 || { GATE_REASON="no change request found for '${CHANGE_ID:-?}'"; return 10; }
  num=$(printf '%s' "$json" | jq -r '.result[0].number.value // .result[0].number // ""')
  [ "$num" = "${CHANGE_ID:-}" ] || { GATE_REASON="ServiceNow returned '$num', not '${CHANGE_ID:-}'"; return 10; }
  st=$(printf '%s' "$json" | jq -r '.result[0].state.value // ""')
  case " ${SNOW_OK_STATES:--1} " in *" $st "*) ;; *) GATE_REASON="change state value is '$st', need one of: ${SNOW_OK_STATES:--1}"; return 10;; esac
  if [ "${SNOW_REQUIRE_APPROVED:-1}" = 1 ]; then
    ap=$(printf '%s' "$json" | jq -r '.result[0].approval.value // ""')
    [ "$ap" = "approved" ] || { GATE_REASON="change approval is '$ap', not 'approved'"; return 10; }
  fi
  if [ "${SNOW_SKIP_CI_CHECK:-0}" != 1 ]; then
    ci=$(printf '%s' "$json" | jq -r '.result[0].cmdb_ci.display_value // ""' | tr 'A-Z' 'a-z')
    [ "$ci" = "$(printf '%s' "$2" | tr 'A-Z' 'a-z')" ] || { GATE_REASON="change CI is '$ci', not VM '$2' (set SNOW_SKIP_CI_CHECK=1 only if you bind VMs another way)"; return 10; }
  fi
  ws=$(printf '%s' "$json" | jq -r '.result[0].start_date.value // ""'); we=$(printf '%s' "$json" | jq -r '.result[0].end_date.value // ""')
  [ -n "$ws" ] && [ -n "$we" ] || { GATE_REASON="change has no planned start/end date"; return 10; }
  m4a_window_ok "$ws" "$we"
}

m4a_gate() { # action vm
  local action="$1" vm="$2" rc=0
  GATE_REASON=""
  case "${GATE_PROVIDER:-none}" in
    none)
      if [ "${AZVM_ALLOW_NO_GATE:-0}" = 1 ]; then GATE_REASON="no change control (AZVM_ALLOW_NO_GATE=1, lab use)"; rc=0
      else GATE_REASON="no change control configured: set GATE_PROVIDER=file|servicenow (see docs/SAFETY.md)"; rc=10; fi ;;
    file)       _gate_file "$action" "$vm"; rc=$? ;;
    servicenow) _gate_snow "$action" "$vm"; rc=$? ;;
    *)          GATE_REASON="unknown GATE_PROVIDER '${GATE_PROVIDER}'"; rc=10 ;;
  esac
  if [ "$rc" -eq 0 ] && { [ -n "${AZVM_WINDOW_START:-}" ] || [ -n "${AZVM_WINDOW_END:-}" ]; }; then
    m4a_window_ok "${AZVM_WINDOW_START:-}" "${AZVM_WINDOW_END:-}"; rc=$?
  fi
  return "$rc"
}
