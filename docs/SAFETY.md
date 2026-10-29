# Safety model

The threat model has two parts: a tired human at 2 a.m., and an AI agent with a shell. Both can be talked into things. The tools are built so that **being talked into it is not enough**.

## The rules

1. **Dry run is the default.** `--apply` is required for every mutation. A dry run prints the whole plan, the preflight and the gate verdict, and changes nothing.
2. **The subscription is always pinned.** `--subscription` or `AZVM_SUBSCRIPTION`. The tools never act on the CLI's default, and print the subscription name before a plan.
3. **A change gate must say ALLOW.** Providers: `none` (denies every mutation unless `AZVM_ALLOW_NO_GATE=1`, for a lab), `file` (a JSON change record) and `servicenow`. The gate checks: the change id matches, the state is right, the record is bound to **this VM**, the action is authorized, the change is approved, and **now is inside the maintenance window**.
4. **`--yes` is only valid with a real gate.** Without `--yes`, a human types the VM name.
5. **Snapshot first, prove it restores.** `azvm-resize` snapshots every disk and runs a restore test before touching the VM, unless `--skip-snapshot` (logged).
6. **Preflight FAIL blocks apply.** Unknown is not a pass: a check that could not read its input FAILs with that reason.
7. **Hooks are files, never strings.** `--pre-hook` and `--post-hook` run an executable from `hooks/` only.
8. **Everything is audited.** Each apply, denial and abort appends one JSON line to `~/.mac4azure/audit.log` (mode 700 directory): time, user, subscription, VM, action, result, change id. No secret goes in it.
9. **No secret on a command line.** ServiceNow credentials live in the macOS Keychain and reach `curl` on stdin. The tools never print a token.
10. **No bypass flag.** The emergency path is a human using `az` directly under your own policy. A flag that skips the gate is a flag an attacker, or a hurried person, will find.

## What the gate does not do

It is a **guard**, not a scheduler and not an identity system. It trusts the change record you point it at: a `file` record can be written by anyone who can write the file, so keep that file where your change process owns it (a repo with review, or a ServiceNow record). With ServiceNow, the record is as trustworthy as your instance's approval flow.

## Agents

An agent can propose and prepare, and a person applies. See [CLAUDE-HOWTO.md](CLAUDE-HOWTO.md). The repository's [CLAUDE.md](../CLAUDE.md) tells Claude Code never to pass `--apply` or `--yes` and never to read or paste credentials.
