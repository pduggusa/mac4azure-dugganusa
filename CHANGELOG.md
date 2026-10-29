# Changelog

## 0.2.0 - 2026-10-29
- `azmac-doctor`: is this Mac a sound place to run Azure changes from? Hardware, workstation posture, network path to Azure, clock, power and thermal. `--ab` runs a fair A/B of `az` through the system proxy versus bypassing it, alternating calls so both see the same network. Prints no serial, UUID, MAC, subscription or account.
- `azvm-stack`: walk a VM from Azure's limits down to its block devices, read-only, with a checksum-verified fixed script (`hardware/ladder.sh`).
- `docs/HARDWARE-LADDER.md`: the rungs, what each proves, and two lessons that needed the ladder to see.

- Security review fixes before release: `azvm-stack` keeps no temp file; `azmac-doctor` prints error classes, never error text (a regression test proves no email or tenant name can appear).

## 0.1.0
- Initial release: metrics, sizes, preflight, change gate (file and ServiceNow providers, maintenance windows), snapshot with restore test, resize, quota, Azure Policy.
