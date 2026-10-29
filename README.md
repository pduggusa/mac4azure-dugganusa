# mac4azure-dugganusa

A small, safe script library for **right-sizing Azure VMs from a Mac**, built to be driven by a person, by [Claude Code](https://claude.com/claude-code), or by a change workflow (ServiceNow, a pipeline, a runbook).

It exists because of one measurement. On a VM we run, the disks averaged single digits and peaked at 81%, CPU peaked at 71%, and the only thing that ever reached 100% was the limit the **VM size** puts on all of its disks combined. A stripe set would have raised the ceiling of a layer that was never hitting it. Free platform metrics said so in one query. These tools make that query, the checks around it, and the change itself repeatable and safe.

## What is in it

| Tool | What it does | Changes Azure? |
|---|---|---|
| `bin/azvm-metrics` | Which layer is at its ceiling: VM-level disk caps, disk caps, CPU, last N hours | no |
| `bin/azvm-sizes` | Compare candidate sizes: vCPU, memory, disk IOPS and MB/s, temp disk, quota headroom, retail price | no |
| `bin/azvm-preflight` | Every check you want green before a resize: generation, static IP, locks, quota, temp disk, controller type | no |
| `bin/azvm-gate` | Ask the change gate "may this run now?" Exit codes are a contract for workflows | no |
| `bin/azvm-snapshot` | Incremental snapshots of every disk, with a restore test | **dry run by default** |
| `bin/azvm-resize` | Preflight, gate, snapshot, resize, verify, print the rollback | **dry run by default** |
| `bin/azvm-quota` | Show and request vCPU quota | **dry run by default** |
| `bin/azvm-policy` | Express the process as Azure Policy (custom definitions plus an initiative) | **plan by default** |

Everything runs on the **stock macOS bash 3.2**. No Homebrew bash, no Python, no Node.

## Quick start

```bash
brew install azure-cli jq          # see docs/SETUP-MAC.md for sources and versions
az login                           # an Entra ID user with MFA; no service principal secret on a laptop
export AZVM_SUBSCRIPTION="<subscription id or name>"   # always pinned; the tools refuse to guess

./bin/azvm-metrics   --vm my-vm --hours 24
./bin/azvm-sizes     --location eastus2 Standard_D4as_v4 Standard_D4as_v5
./bin/azvm-preflight --vm my-vm --target-size Standard_D4as_v5
./bin/azvm-resize    --vm my-vm --target-size Standard_D4as_v5      # a dry run: shows the whole plan
```

Applying a change needs `--apply` **and** a passing change gate. See [docs/SAFETY.md](docs/SAFETY.md).

## The safety model in five lines

1. **Read-only is the default.** Nothing mutates without `--apply`.
2. **A change gate sits in front of every mutation.** It needs a real change record (a JSON file, or a ServiceNow change in the Implement state, bound to that VM, inside its maintenance window). With no change control configured, mutations are denied.
3. **Typed confirmation** of the VM name, or `--yes` only when a real gate passed.
4. **Snapshot first, and prove it restores.** Resize takes incremental snapshots and runs a restore test before it touches the VM.
5. **Everything is audited locally and nothing carries a secret.** Credentials never touch a command line.

There is no bypass flag. The emergency path is a human using `az` directly under your own policy.

## Documentation

- [docs/SETUP-MAC.md](docs/SETUP-MAC.md): free prerequisites, with sources
- [docs/PERSONAS-AND-ACCESS.md](docs/PERSONAS-AND-ACCESS.md): who does what, and the least Azure access each needs
- [docs/TESTED-VERSIONS.md](docs/TESTED-VERSIONS.md): what we ran this on, what we did **not** test, and recommended tools
- [docs/SAFETY.md](docs/SAFETY.md): the threat model and the rules
- [docs/SERVICENOW.md](docs/SERVICENOW.md) and [docs/MAINTENANCE-WINDOWS.md](docs/MAINTENANCE-WINDOWS.md): plugging into change management
- [docs/POLICIES.md](docs/POLICIES.md): the process as Azure Policy
- [docs/LESSONS.md](docs/LESSONS.md): the traps we hit (ephemeral temp disks, mount order, quota, caps)
- [docs/CLAUDE-HOWTO.md](docs/CLAUDE-HOWTO.md) and [CLAUDE.md](CLAUDE.md): driving this with Claude Code safely

## Background reading

- [How To Architect on Azure: Uptime Is the Wrong Humble-Brag](https://www.dugganusa.com/post/how-to-architect-on-azure-uptime-is-the-wrong-humble-brag): how we troubleshoot, and the free Azure features that keep a VM honest
- [Why I'd Never Manage Azure from a PC](https://www.dugganusa.com/post/why-i-d-never-manage-azure-from-a-pc): why the Azure management plane does not need Windows, what our research says about who attackers write for, and where Windows still wins

## Honest status

Read-only paths, the dry runs and the refusal behavior were exercised against a real subscription. The offline test suite (`tests/run-tests.sh`, 36 checks) covers the gate. The `--apply` paths mirror a manual runbook we executed once on a production VM, but **the scripted apply paths have not been run end to end**, and the ServiceNow client and the policy creation have **not** been run against a live instance or subscription. Details and the full list are in [docs/TESTED-VERSIONS.md](docs/TESTED-VERSIONS.md). Try applies on a non-production VM first.

## License

MIT. See [LICENSE](LICENSE). Maintained by [DugganUSA LLC](https://www.dugganusa.com).
