# Tested versions, and what we did not test

Written 2026-10-29, from the machine the tools were developed and run on. Versions were read from the tools themselves, not from memory.

## Versions we ran

| Component | Version |
|---|---|
| macOS | 27.0.1 (build 26A434), Apple silicon |
| bash (system, the one the tools target) | GNU bash 3.2.57 |
| zsh (interactive shell) | 5.9 |
| Azure CLI | 2.83.0 (Homebrew, running on Python 3.13.11) |
| jq | 1.8.1 |
| curl | 8.7.1 (SecureTransport) |
| OpenSSH | 10.3p1 |
| git | 2.54.0 (Apple Git-157) |
| GitHub CLI | 2.102.0 |
| Homebrew | 7.0.10 |

## What was exercised for real

Against a real subscription and a real production VM, **read-only**:

- `azvm-metrics`: matched the same numbers pulled by hand the same day.
- `azvm-sizes`: matched the SKU capabilities, quota and retail prices pulled by hand. Found and fixed a real bug (five parallel `az` calls fail silently; concurrency is now capped and failures are reported as `LOOKUP FAILED`, not "not offered").
- `azvm-preflight`: caught a real quota refusal and a real temp-disk change; found and fixed a false FAIL on a transient read.
- `azvm-snapshot`, `azvm-quota request`, `azvm-resize`, `azvm-policy`: **dry runs only**, including `azvm-resize --apply` correctly refusing on a failed preflight and a denied gate.
- The Azure Policy rule fields were checked against the live resource-provider alias lists (`Microsoft.Compute/virtualMachines/sku.name`, `Microsoft.Network/publicIPAddresses/publicIPAllocationMethod`).

New in 0.2.0, run for real on 2026-10-29: `azmac-doctor` (with and without `--ab`) on the machine above, where it found a system proxy and a world-readable Azure CLI config directory, and a fair alternating test cleared the proxy (12 of 12 on both paths); `azvm-stack` against the production VM over ssh, read-only, where it found I/O pressure while the disks looked idle and 14 GB hiding under a mount point on the OS disk. `azmac-doctor` is macOS only. `azvm-stack` was run against Ubuntu 22.04 only; the other distributions' `/dev/disk/azure` links are assumed, not verified.

Offline, no Azure and no network: `tests/run-tests.sh` (the change gate in all three providers, window edges, host allow-list, JSON contract, policy JSON validity, `bash -n` on every script).

## What we did NOT test

| Not tested | Why it matters |
|---|---|
| The scripted `--apply` paths of `azvm-snapshot`, `azvm-resize`, `azvm-quota` | They mirror the manual runbook we ran on 2026-10-29 (snapshots, a restore test, a resize, a quota request), but the scripts themselves have not driven a change end to end. Run them on a non-production VM first. |
| The ServiceNow provider against a live instance | Only against a fixture of the documented Table API response shape. State values, field names and your instance's change model must be verified (docs/SERVICENOW.md). |
| Creating the Azure Policy definitions, initiative or assignment | Rule fields verified; creation not exercised. Try a non-production subscription. |
| Linux, Windows or WSL | The tools target macOS. BSD `date` is tried first, GNU `date` second, but we ran neither Linux nor WSL. |
| bash 4 or 5, Homebrew bash | Written for 3.2 so they should work, but not run. |
| `shellcheck` | Not installed on the test machine. |
| VMs with NVMe disk controllers, Windows guests, VM scale sets, availability sets | Out of scope for v1. |

## Recommended tools

Required: Azure CLI, `jq`. Recommended: `shellcheck` (lint), `gh` (review), FileVault and the macOS Keychain (credentials). Free throughout. Pricing for Azure features changes: confirm on Microsoft's pages before relying on any "free" claim here.
