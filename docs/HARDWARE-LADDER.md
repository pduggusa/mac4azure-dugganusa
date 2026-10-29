# The hardware ladder: from the Azure limit down to the block device

When something is slow, the instinct is to tune the layer you are looking at. This is a fixed order of rungs, top to bottom, with the question each one answers and the command that answers it. Walk it before you change anything. Two tools do the walking read-only: `azmac-doctor` (the Mac) and `azvm-stack` (the VM).

| Rung | The question | Where the answer is | What it proved to us |
|---|---|---|---|
| **M. Your Mac** | Is the workstation sound: encrypted, patched, on power, clock right, network path clean? | `azmac-doctor` | A system proxy was routing every `az` call through a local app; we measured it fairly and cleared it |
| **0. Azure's limits** | Which limit is the VM actually hitting: the VM's own disk cap, a disk's cap, or CPU? | `azvm-metrics` (platform metrics, free, 93 days) | Only the VM-level cap reached 100%; the disks never did |
| **1. The size** | What did the hypervisor give this guest? | `azvm-stack` rung 1 (`lscpu`, `free`) | The CPU model and the real memory |
| **2. Pressure** | Are tasks stalled waiting on CPU, memory or disk, and for what share of the time? | `/proc/pressure/{cpu,io,memory}` (PSI) | On a "fixed" VM, I/O stalls were still 20 to 40% while CPU pressure was zero |
| **3. The device map** | Which Azure disk is which `/dev` name? | `/dev/disk/azure/scsi1/lunN`, `/dev/disk/azure/resource` | LUN 1 was `sdb`; the temp disk was `sdd` and ephemeral |
| **4. I/O now** | Utilization and wait per device, this second | `iostat -dx 1 2` | A quiet sample can hide a bursty workload: read it with rung 2, not instead of it |
| **5. Mounts** | Is every fstab target mounted, and in the right order? Each checked on its own | `mountpoint -q <path>` per target | A combined `findmnt` printed nothing and looked like success |
| **6. fstab structure** | Wrong order, a missing target, a bad option? | `findmnt --verify` | The parent listed after its children caused a real shadowing bug |
| **7. Space** | Is any filesystem filling, and does `df` agree with `du`? | `df -hT`, `df -i` | `du` found 6 GB, `df` said 20 GB |
| **8. Network** | What is listening, and how many sockets? | `ss -s`, `ss -ltnH` | Which ports the host exposes, with no process arguments |
| **9. Kernel and services** | Failed units, kernel errors, error counts by program | `systemctl --failed`, `journalctl -p err` | Counts per program found the one noisy client |

## The two lessons that need the ladder to see

**When `df` and `du` disagree, the gap is the clue.** On a database VM the OS disk was 68% full and `du` could account for less than a third of it. There were no deleted-but-open files (`lsof +L1` showed none). The rest was **14 GB hiding underneath a mount point**: a bind mount of `/` (`mount --bind / /somewhere`) shows the root filesystem without anything layered on top of it, and there was an old copy of the database, untouched for months, sitting under the directory where its replacement disk is mounted. Nothing alerted on it because every normal tool reads the mounted view.

**Read pressure beside utilization.** `iostat` over two seconds showed idle disks while the pressure counters showed tasks stalled on I/O for a fifth to two-fifths of the time. Pressure is the time tasks spent waiting; utilization is a snapshot of the device. A bursty indexer lives in the gap.

## Safety of the walk

`azvm-stack` sends one fixed script, `hardware/ladder.sh`, over your existing ssh access. It refuses to send it unless its sha256 matches `hardware/MANIFEST.sha256`, so a modified copy of this repo cannot quietly run something else on your VM. The script changes nothing and prints no environment variables, no process arguments, no file contents and nothing from a credential file. It lists directory sizes and counts, never lines from logs. `azmac-doctor` prints no serial number, hardware UUID, MAC address, subscription id or account name.

## Not covered yet

Windows guests, Azure Run Command as an alternative to ssh (it needs the VM agent to be healthy and returns limited output), NVMe-attached disks, and the cloud rung for VM scale sets.
