# Personas and Azure access

Give each person the least access their job needs, at the smallest scope that works (the VM's resource group, not the subscription, where you can). The role names below are Azure built-in roles; the permission lists were read from `az role definition list` on 2026-10-29. Reference: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles

| Persona | Does | Azure roles | Tools they can run |
|---|---|---|---|
| **Inspector** | looks, measures, proposes | `Reader`, `Monitoring Reader` | `azvm-metrics`, `azvm-sizes`, `azvm-preflight`, `azvm-gate`, `azvm-quota show`, `azvm-policy plan`, any dry run |
| **Operator** | performs an approved change | Inspector, plus `Virtual Machine Contributor` and `Disk Snapshot Contributor` | `azvm-snapshot --apply`, `azvm-resize --apply` |
| **Quota requester** | asks for capacity ahead of the window | `Quota Request Operator` (subscription) | `azvm-quota request --apply` |
| **Policy author** | defines the standard | `Resource Policy Contributor` | `azvm-policy apply` |
| **Change manager** | approves the change record | no Azure access needed | approves in ServiceNow (or signs the change file) |

## What the roles actually grant (verified)

- `Virtual Machine Contributor`: `Microsoft.Compute/virtualMachines/*`, `disks/read|write|delete`, `locations/*`, `publicIPAddresses/read|join`. It does **not** include snapshot write, which is why `Disk Snapshot Contributor` is separate.
- `Disk Snapshot Contributor`: `snapshots/read|write|delete`, `snapshots/beginGetAccess`, `disks/beginGetAccess`.
- `Quota Request Operator`: `Microsoft.Quota/*` read and the capacity service-limit read and write.
- `Monitoring Reader`: read metrics and alert state.

A custom role that grants exactly `virtualMachines/write|read|restart|deallocate`, `disks/read|write|delete` and `snapshots/*` for one resource group is tighter still. We did not build one.

## Separate the persona from the person

- The person who **proposes** a resize (Inspector) is not the person who **applies** it (Operator), and neither is the person who **approves** the change. With one human in a small shop, the change record still names who approved and when, and the audit log shows the rest.
- Elevate only for the window. If your tenant has Privileged Identity Management (an Entra ID P2 feature, **not free**), make `Virtual Machine Contributor` an eligible role, not a standing one: https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-configure
- An AI agent is an Inspector. It may run every read-only tool and every dry run. The person applies. See [CLAUDE-HOWTO.md](CLAUDE-HOWTO.md).

## What the tools never do

They never create service principals, never read or write role assignments, never read Key Vault, never delete anything except the temporary disk the restore test creates, and never take an action the signed-in identity could not already take by hand.
