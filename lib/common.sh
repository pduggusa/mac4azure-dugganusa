#!/bin/bash
# lib/common.sh — shared helpers for the mac4azure tools.
#
# Runs on macOS's stock bash 3.2: no associative arrays, no mapfile, no ${var,,}.
# Design rules (see docs/SAFETY.md):
#   1. Read-only is the default. Anything that changes Azure needs --apply AND a passing change gate.
#   2. The subscription is always pinned explicitly. We never act on the CLI's "default" subscription.
#   3. No secret ever travels on a command line, into a log, or into the audit trail.
#   4. Every apply is written to a local audit log, pass or fail.

set -u
set -o pipefail

M4A_HOME="${M4A_HOME:-$HOME/.mac4azure}"
M4A_AUDIT_LOG="${M4A_AUDIT_LOG:-$M4A_HOME/audit.log}"
M4A_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
warn() { printf 'warn:  %s\n' "$*" >&2; }
info() { printf '%s\n' "$*"; }

need() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "missing prerequisite: $c (see docs/SETUP-MAC.md)"
  done
}

# Pin the subscription. Sets SUB, SUB_ID, SUB_NAME, USER_NAME.
m4a_require_subscription() {
  SUB="${SUB:-${AZVM_SUBSCRIPTION:-}}"
  [ -n "$SUB" ] || die "no subscription pinned: pass --subscription <id-or-name> or set AZVM_SUBSCRIPTION"
  SUB_NAME=$(az account show --subscription "$SUB" --query name -o tsv 2>/dev/null) \
    || die "not logged in, or no access to subscription '$SUB' (run: az login)"
  SUB_ID=$(az account show --subscription "$SUB" --query id -o tsv)
  USER_NAME=$(az account show --subscription "$SUB" --query user.name -o tsv)
}

# Every az call in the tools goes through az_ so the pinned subscription is always explicit.
az_() { az "$@" --subscription "$SUB"; }

# Resolve --vm NAME [--resource-group RG] into VM, RG. Errors if the name is ambiguous.
m4a_resolve_vm() {
  [ -n "${VM:-}" ] || die "--vm <name> is required"
  if [ -z "${RG:-}" ]; then
    local found count
    found=$(az_ vm list --query "[?name=='$VM'].resourceGroup" -o tsv 2>/dev/null) || die "could not list VMs"
    count=$(printf '%s\n' "$found" | grep -c . || true)
    [ "$count" -eq 1 ] || die "VM '$VM' matched $count resource groups; pass --resource-group"
    RG="$found"
  fi
}

# Append one JSON line per apply. No secrets, no free-form user input beyond a sanitized detail.
m4a_audit() { # action result [detail]
  mkdir -p "$M4A_HOME" && chmod 700 "$M4A_HOME" 2>/dev/null
  printf '{"ts":"%s","user":"%s","subscription":"%s","vm":"%s","action":"%s","result":"%s","change":"%s","detail":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${USER_NAME:-?}" "${SUB_ID:-?}" "${VM:-}" "$1" "$2" "${CHANGE_ID:-}" \
    "$(printf '%s' "${3:-}" | tr -d '"\\\n')" >> "$M4A_AUDIT_LOG"
}

# Parse "YYYY-MM-DD HH:MM:SS" or "YYYY-MM-DDTHH:MM:SS[.fff]Z" (UTC) to epoch seconds. BSD date first, GNU second.
m4a_epoch() {
  local s e
  s=$(printf '%s' "$1" | sed -e 's/T/ /' -e 's/Z$//' -e 's/\.[0-9]*$//')
  e=$(date -j -u -f '%Y-%m-%d %H:%M:%S' "$s" +%s 2>/dev/null) || e=$(date -u -d "$s UTC" +%s 2>/dev/null) || return 1
  printf '%s' "$e"
}

# Typed confirmation. --yes skips the prompt but ONLY when a real change gate passed (checked by the caller).
m4a_confirm_typed() { # phrase
  if [ "${ASSUME_YES:-0}" = 1 ] || [ "${M4A_PARENT_CONFIRMED:-0}" = 1 ]; then return 0; fi
  [ -t 0 ] || die "refusing to apply non-interactively without --yes (which itself requires a real change gate)"
  local a
  printf 'Type "%s" to continue: ' "$1" >&2
  read -r a
  [ "$a" = "$1" ] || die "confirmation did not match; nothing changed"
}
