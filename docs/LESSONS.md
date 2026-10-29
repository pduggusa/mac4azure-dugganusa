# Lessons (each one cost us something)

## Measure the layer above the one you are tuning
A VM has its own disk throughput and IOPS cap that applies to all its disks combined. Each disk has a cap too, and the VM's is often the lower. In the VM we measured, disks averaged 4 to 6% (peaking at 81%), CPU peaked at 71%, and only the VM-level cap reached 100%. Striping disks, or buying faster ones, raises a ceiling that was not being hit. `azvm-metrics` reads the VM-level metrics (`VM Uncached Bandwidth Consumed Percentage` and `VM Uncached IOPS Consumed Percentage`). They are platform metrics: free, retained 93 days (https://learn.microsoft.com/azure/azure-monitor/essentials/metrics-aggregation-explained).

## Quota is invisible until the day you need it
A zero quota in a VM family produces no warning. The first sign is a refusal at validation, with a message naming the family. The refusal happens before anything changes, which is the good news. Audit quota for the families you might move to, ahead of the window (`azvm-sizes`, `azvm-quota show`). Newer families and older ones can differ: a subscription set up years ago may have headroom in one generation and zero in the next.

## The temp disk is ephemeral, and mountpoints under it vanish
Many VM sizes include a temporary disk. A resize or redeploy recreates it **empty**. Anything mounted beneath it, including the empty directories you mount other disks onto, disappears with it. A mount marked `nofail` then fails in silence and the VM boots "fine".
Fixes: keep mountpoints off ephemeral storage, or add the `x-systemd.mkdir` mount option so systemd recreates the directory.

## Mount order matters, and the mount-everything command follows file order
`mount -a` follows the order of `/etc/fstab`. If the parent (`/mnt`) is listed last, it mounts last and covers the child mounts: they look empty, and `df` reports the parent. Put the parent first. systemd orders boot-time mounts by path on its own; only the manual command and some tooling are order-sensitive.
Check each mount **by itself** with `mountpoint -q /path`. `findmnt` given several targets can print nothing and look like success.

## A restore is the only proof of a snapshot
Create a disk from the snapshot, compare its size in bytes to the source, delete it. That proves the block copy. A full drill (a scratch VM, start the service, compare application counts) proves the rest, and deserves a calendar date. Incremental snapshots bill for changed blocks (https://learn.microsoft.com/azure/virtual-machines/disks-incremental-snapshots).

## Burstable is for bursts
B-series sizes are excellent for spiky work and have low sustained disk limits. A database that indexes all day is a sustained workload. The right family was not much more expensive than the wrong one.

## Uptime is the wrong number
Uptime is the time since someone last looked. A long run means a stale kernel and an untested boot path. Track time to detect, time to restore (tested), patch age and the age of your last restore test.

## Do not fix before you know what is broken
Write hypotheses as hypotheses. We believe the VM cap caused the application waits we saw. That is not proven until the same wait is measured after the change, and our notes say so.

## `az` is flaky on a laptop, and silence is not "none"
Parallel `az` calls can fail on the shared token cache, and a flaky connection fails a call without warning. The tools cap concurrency, retry once, and report `LOOKUP FAILED` instead of an empty answer. An empty answer is "unknown", never "not offered".
