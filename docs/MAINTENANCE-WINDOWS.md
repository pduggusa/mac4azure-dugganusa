# Maintenance windows

Two different things carry this name, and the tools touch only one.

## 1. Your change window (the tools enforce this)

The gate refuses a mutation outside the window, from whichever source:

- `file` provider: `window_start` and `window_end` in the change record (UTC).
- `servicenow` provider: the change's planned start and end dates (UTC values).
- Any provider, extra: `AZVM_WINDOW_START` and `AZVM_WINDOW_END` narrow it further. They can only shrink the window, never widen it.

The window is checked **when the tool runs**, not when the change was approved. A late start is a denial.

The gate is a guard. It does not schedule anything. To run at the start of a window use whatever you already trust: the ServiceNow flow, Azure Automation, a pipeline, or `launchd`/`cron` on a Mac.

## 2. Azure's platform maintenance (Azure schedules this; you can shape it)

Azure patches the host under your VM. For VMs you can control when guest and host maintenance lands with Azure **maintenance configurations** (https://learn.microsoft.com/azure/virtual-machines/maintenance-configurations) and schedule guest OS patching with **Azure Update Manager** (https://learn.microsoft.com/azure/update-manager/overview). Update Manager is free for Azure VMs; Arc-enabled servers are billed per Microsoft's FAQ. Tag the VM with the window it lives in (`maintenance-window=...`) so the process, the policy and the humans all read the same fact. See [POLICIES.md](POLICIES.md).

## Reboot on a schedule

A VM that never reboots keeps its old kernel (kernel patches apply at reboot) and never exercises its boot path. Pick a monthly window and use it. Uptime is not the goal; recoverability is. After every reboot check each mount by itself (`mountpoint -q /path`), in order. See [LESSONS.md](LESSONS.md).
