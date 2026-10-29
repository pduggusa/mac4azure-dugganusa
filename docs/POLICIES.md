# The process as Azure Policy

A process people remember is a habit. A process Azure reports on is a standard. `bin/azvm-policy` ships three custom definitions and one initiative that also references three **built-in** policies, so "right-sizing" has a tag standard, an approved-size list and an audit trail inside Azure itself. Documentation: https://learn.microsoft.com/azure/governance/policy/overview and https://learn.microsoft.com/azure/governance/policy/concepts/definition-structure-basics

> **Status:** the rule fields were checked against the live resource-provider aliases. Creating the definitions, the initiative and an assignment has **not** been exercised by us. Try a non-production subscription. Assignment defaults to `DoNotEnforce` (report only).

## The tag standard

| Tag | Meaning |
|---|---|
| `maintenance-window` | when this VM may be changed, in words your change process uses |
| `owner` | who gets the call |
| `workload` | `sustained` or `burst`, which drives the size family |

## Custom definitions (in `policy/definitions/`)

| Name | What it reports |
|---|---|
| `m4a-vm-governance-tags` | VMs missing any of the three tags (effect `Audit`, or `Deny` once you are ready) |
| `m4a-vm-burstable-sustained` | B-series VMs tagged `workload=sustained`: a right-sizing review waiting to happen |
| `m4a-public-ip-static` | public IPs using `Dynamic` allocation, which a deallocate can change |

## Built-in policies the initiative references (IDs verified 2026-10-29)

| Built-in | ID |
|---|---|
| Allowed virtual machine size SKUs | `cccc23c7-8427-4f53-ad12-b6a63eb452b3` |
| Machines should be configured to periodically check for missing system updates | `bd876905-5b84-4f73-ab2d-2e7a7c4568d9` |
| Azure Backup should be enabled for Virtual Machines | `013e242c-8828-4970-87b3-ab247555486d` |

The allowed-sizes list has **no default**: your change process decides it. See `policy/assignment-parameters.example.json`.

## Roll-out path

1. `./bin/azvm-policy plan` and read it.
2. Create in a non-production subscription: `./bin/azvm-policy apply --apply` (needs a passing gate).
3. Assign with `--assign --scope <scope> --params <file>`, report-only.
4. Read the compliance results for a few weeks. Fix the tags. Look at what the burstable policy finds.
5. Only then consider `Deny` for tags and the allowed-sizes list, on a narrow scope first.

Policy tells you what exists. It does not tell you what is hitting a ceiling: that is `azvm-metrics`.
