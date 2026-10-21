#!/usr/bin/env bash
# Snapshot diagnostics for a hung VirtualBox VM from the host.
# Safer quoting; optional sudo for privileged /proc reads.
#
# Usage:
#   ./collect_vbox_vm_hang_snapshot_v2.sh "VM Name" [--sudo-proc] [--with-core] [--with-gdb]
#
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 \"VM Name\" [--sudo-proc] [--with-core] [--with-gdb]" >&2
  exit 2
fi

VM_NAME="$1"; shift || true
USE_SUDO_PROC=0
WITH_CORE=0
WITH_GDB=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sudo-proc) USE_SUDO_PROC=1;;
    --with-core) WITH_CORE=1;;
    --with-gdb)  WITH_GDB=1;;
    *) echo "Unknown option: $1" >&2; exit 2;;
  esac
  shift
done

SUDO=""
if [[ $USE_SUDO_PROC -eq 1 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "WARN: --sudo-proc requested but sudo not found; proceeding without sudo." >&2
  fi
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
outdir="$HOME/vbox_vm_hang_${timestamp}"
mkdir -p "$outdir"

log() { echo "[$(date +%H:%M:%S)] $*"; }

if ! command -v VBoxManage >/dev/null 2>&1; then
  echo "ERROR: VBoxManage not found in PATH" >&2
  exit 1
fi

log "Output dir: $outdir"
# 1) VM info
VBoxManage showvminfo "$VM_NAME" --machinereadable > "$outdir/showvminfo.mr" 2>&1 || true
VBoxManage showvminfo "$VM_NAME" > "$outdir/showvminfo.txt" 2>&1 || true

# Extract CfgFile without awk quoting heck
cfg_file=""
if grep -q '^CfgFile=' "$outdir/showvminfo.mr"; then
  cfg_file="$(grep '^CfgFile=' "$outdir/showvminfo.mr" | head -n1)"
  cfg_file="${cfg_file#CfgFile=}"
  cfg_file="${cfg_file%$'\r'}"
  cfg_file="${cfg_file%\"}"; cfg_file="${cfg_file#\"}"
fi

if [[ -n "$cfg_file" && -f "$cfg_file" ]]; then
  vm_dir="$(dirname "$cfg_file")"
  if [[ -d "$vm_dir/Logs" ]]; then
    cp -a "$vm_dir/Logs" "$outdir/"
  fi
fi

# 2) Processes
ps -eo pid,ppid,stat,wchan:20,comm,etimes,cmd | grep -E 'PID|VirtualBox' > "$outdir/ps_virtualbox.txt" || true
pgrep -af VirtualBox > "$outdir/pgrep_virtualbox.txt" || true

# Try to find PID robustly: match --comment "VM_NAME" or entire name in cmdline
pid="$(pgrep -f "VirtualBoxVM.*--comment $VM_NAME" || true)"
if [[ -z "$pid" ]]; then
  pid="$(pgrep -f "VirtualBoxVM.*$VM_NAME" || true)"
fi
if [[ -z "$pid" ]]; then
  pid="$(pgrep -f "VBoxHeadless.*$VM_NAME" || true)"
fi
echo "$pid" > "$outdir/vm_pid.txt"

if [[ -n "$pid" ]]; then
  # privileged /proc reads via sudo if requested
  ${SUDO} bash -c "cat /proc/$pid/status" > "$outdir/proc_${pid}_status.txt" 2>/dev/null || true
  ${SUDO} bash -c "cat /proc/$pid/stack"  > "$outdir/proc_${pid}_stack.txt"  2>/dev/null || true
  ${SUDO} bash -c "cat /proc/$pid/wchan"  > "$outdir/proc_${pid}_wchan.txt"  2>/dev/null || true
  ${SUDO} bash -c "cat /proc/$pid/limits" > "$outdir/proc_${pid}_limits.txt" 2>/dev/null || true
  ${SUDO} bash -c "ls -l /proc/$pid/fd"   > "$outdir/proc_${pid}_fd.txt"     2>/dev/null || true
  if [[ -d "/proc/$pid/task" ]]; then
    for t in /proc/$pid/task/*; do
      tid="${t##*/}"
      ${SUDO} bash -c "cat '$t/stack' " > "$outdir/proc_${pid}_task_${tid}_stack.txt"  2>/dev/null || true
      ${SUDO} bash -c "cat '$t/wchan' " > "$outdir/proc_${pid}_task_${tid}_wchan.txt"  2>/dev/null || true
    done
  fi
fi

# 3) VBox debug info (non-invasive)
VBoxManage debugvm "$VM_NAME" info > "$outdir/debugvm_info.txt" 2>&1 || true
VBoxManage debugvm "$VM_NAME" osdetect > "$outdir/debugvm_osdetect.txt" 2>&1 || true
VBoxManage debugvm "$VM_NAME" getregisters > "$outdir/debugvm_registers.txt" 2>&1 || true

if [[ $WITH_GDB -eq 1 && -n "${pid:-}" && -x "$(command -v gdb)" ]]; then
  gdb -batch -p "$pid" -ex "set pagination off" -ex "thread apply all bt" > "$outdir/gdb_bt_${pid}.txt" 2>&1 || true
fi

if [[ $WITH_CORE -eq 1 ]]; then
  VBoxManage debugvm "$VM_NAME" dumpvmcore --filename "$outdir/vmcore.core" > "$outdir/dumpvmcore.log" 2>&1 || true
fi

# 4) Logs around now
${SUDO} bash -c "journalctl -k --since '-5min'" > "$outdir/journal_kernel_5m.txt" 2>/dev/null || true
${SUDO} bash -c "journalctl --since '-5min'"   > "$outdir/journal_all_5m.txt"   2>/dev/null || true
dmesg -T > "$outdir/dmesg_all.txt" 2>&1 || true

# 5) HW snapshot
uname -a > "$outdir/uname.txt" || true
(lsb_release -a > "$outdir/lsb_release.txt" 2>&1) || true
lspci -nnk > "$outdir/lspci_nnk.txt" 2>&1 || true
lsmod | sort > "$outdir/lsmod.txt" 2>&1 || true
cat /proc/cmdline > "$outdir/proc_cmdline.txt" 2>&1 || true

# 6) VBox versions
VBoxManage --version > "$outdir/vbox_version.txt" 2>&1 || true
(modinfo vboxdrv > "$outdir/modinfo_vboxdrv.txt" 2>&1) || true
(modinfo vboxnetflt > "$outdir/modinfo_vboxnetflt.txt" 2>&1) || true

# 7) AMDGPU params and tail
if [[ -d /sys/module/amdgpu/parameters ]]; then
  grep . /sys/module/amdgpu/parameters/* > "$outdir/amdgpu_params.txt" 2>&1 || true
fi
${SUDO} bash -c "journalctl -k | grep -i -E 'amdgpu|ring|gpu|reset|lockup|rcu|soft lockup|hard lockup|rcu stall' | tail -n 200" > "$outdir/journal_gpu_tail.txt" 2>/dev/null || true

# 8) Packages
if command -v dpkg >/dev/null 2>&1; then
  dpkg -l | grep -i virtualbox > "$outdir/dpkg_virtualbox.txt" 2>&1 || true
fi

echo "$outdir"
