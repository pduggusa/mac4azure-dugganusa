#!/bin/bash
# hardware/ladder.sh — read-only walk from the guest kernel down to the block devices. Runs ON the VM (sent by azvm-stack).
# It prints no environment variables, no process arguments, no file contents, nothing from any credential file. It changes nothing.
# Each rung says what it proves. Fixed script: azvm-stack refuses to send it unless its sha256 matches hardware/MANIFEST.sha256.
set -u
say() { printf '\n== %s ==\n' "$1"; }

say "1. CPU and memory: what the hypervisor actually gave this guest"
uname -sr
lscpu 2>/dev/null | grep -E "^(Model name|CPU\(s\):|Thread|Hypervisor vendor|Virtualization type)" | sed 's/  */ /g'
free -h | sed -n '1,2p'
uptime

say "2. Pressure (PSI): share of time tasks were stalled. Sustained io or memory pressure is a bottleneck you can measure"
for r in cpu io memory; do [ -r /proc/pressure/$r ] && { printf '%-7s ' "$r"; head -1 /proc/pressure/$r; }; done

say "3. Block devices, and which Azure disk is which /dev name"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null | grep -v loop
for l in /dev/disk/azure/scsi1/lun*; do [ -e "$l" ] && printf '%s -> %s\n' "$(basename "$l")" "$(basename "$(readlink -f "$l")")"; done
[ -e /dev/disk/azure/resource ] && printf 'resource (temp) disk -> %s   [EPHEMERAL: recreated empty on resize]\n' "$(basename "$(readlink -f /dev/disk/azure/resource)")"

say "4. I/O right now: utilization and wait per device (2-second sample)"
if command -v iostat >/dev/null 2>&1; then iostat -dx 1 2 | awk '/^Device/ {n++} n==2' | grep -vE "^$|loop" | cut -c1-120; else echo "(iostat not installed; it ships in the sysstat package)"; fi

say "5. Mounts: is every fstab target mounted? Each is checked by itself (a combined findmnt can print nothing and look fine)"
awk '$1 !~ /^#/ && NF>=2 && $2 ~ /^\// {print $2}' /etc/fstab | while read -r m; do if mountpoint -q "$m"; then echo "MOUNTED      $m"; else echo "NOT MOUNTED  $m"; fi; done
echo "mount order as the kernel holds it (a parent must come before its children):"
findmnt -rn -o TARGET 2>/dev/null | grep -E "^/(data|mnt|srv|opt|home|var/lib)" | sed 's/^/   /'

say "6. fstab structure (findmnt --verify). Run without root it cannot probe filesystem types and reports that as errors; those lines are dropped"
findmnt --verify 2>&1 | grep -E "\[(E|W)\]" | grep -v "cannot detect on-disk filesystem type" | cut -c1-140 | head -8
echo "(anything above is a structural finding: wrong order, missing target, bad option; nothing above means none)"

say "7. Space and inodes"
df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | cut -c1-110
printf 'inode use on /: '; df -i / | awk 'NR==2 {print $5}'

say "8. Network: socket summary and listening ports (addresses and ports only, never process arguments)"
ss -s 2>/dev/null | head -3
printf 'listening on: '; ss -ltnH 2>/dev/null | awk '{print $4}' | sort -u | head -12 | tr '\n' ' '; echo

say "9. Kernel and service health"
printf 'failed systemd units: '; systemctl --failed --no-legend 2>/dev/null | grep -c . || true
printf 'kernel error-level messages this boot: '; journalctl -k -p err -b --no-pager 2>/dev/null | grep -vc '^--' || true
echo "error-level journal lines by program, last 24 h (counts only, no message text):"
journalctl -p err --since -24h --no-pager 2>/dev/null | awk 'NF>=5 && $1 !~ /^--/ {p=$5; sub(/\[.*/,"",p); sub(/:$/,"",p); print p}' | sort | uniq -c | sort -rn | head -6 | sed 's/^/   /'
echo
echo "(walk complete: read-only, nothing changed)"
