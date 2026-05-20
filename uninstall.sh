#!/usr/bin/env bash

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Bold text
BOLD='\033[1m'

# --- Spinner Function ---
spinner() {
  local pid=$1
  local message=$2
  local spin_chars=('|' '/' '-' '\')
  local i=0
  local spin_str=""

  # Hide the cursor
  tput civis

  # Start spinner
  while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) % ${#spin_chars[@]} ))
    spin_str="${spin_chars[$i]}"
    printf "\r${YELLOW}${spin_str} ${message}${NC}"
    sleep 0.1
  done

  # Clear the spinner line
  printf "\r\033[K"
  tput cnorm
}

run_with_spinner() {
  local message=$1
  shift
  printf "${YELLOW}→ ${message}...${NC}\n"
  "$@" &
  local pid=$!
  spinner $pid "$message"
  wait $pid
  local status=$?
  if [ $status -eq 0 ]; then
    echo -e "${GREEN}✓ ${message} completed${NC}"
  else
    echo -e "${RED}✗ ${message} failed${NC}"
  fi
  return $status
}

# --- Helper Functions ---
print_section() {
  echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

# --- Script Start ---
print_section "System Cleanup: Removing OpenStack and Ceph"

# Remove OpenStack
run_with_spinner "Removing OpenStack snap" sudo snap remove --purge openstack
run_with_spinner "Removing OpenStack Hypervisor snap" sudo snap remove --purge openstack-hypervisor

# Tidy up Ceph
run_with_spinner "Removing MicroCeph snap" sudo snap remove --purge microceph

# --- Disk Cleanup ---
print_section "Ceph Disk Signature Check and Cleanup"

for each_disk in sda sdb sdc sdd; do
  print_info "Checking /dev/$each_disk for Ceph signatures..."
  disk_type=$(sudo blkid /dev/$each_disk | cut -f 2 -d '=' | tr -d '"')
  print_info "Disk type: $disk_type"

  if [[ $disk_type == "ceph_bluestore" ]]; then
    print_info "Nuking disk /dev/$each_disk..."
    # Wipe and clear operations
    run_with_spinner "Running wipefs on /dev/$each_disk" sudo wipefs -af /dev/$each_disk
    run_with_spinner "Running sgdisk --zap-all on /dev/$each_disk" sudo sgdisk --zap-all /dev/$each_disk
    run_with_spinner "Running sgdisk --clear on /dev/$each_disk" sudo sgdisk --clear /dev/$each_disk

    # dd operations
    print_info "Erasing disk signatures..."
    run_with_spinner "Erasing first 9 blocks on /dev/$each_disk" sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=9 seek=0 >/dev/null 2>&1
    run_with_spinner "Erasing block 128 on /dev/$each_disk" sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=1 seek=128 >/dev/null 2>&1
    run_with_spinner "Erasing block 2048 on /dev/$each_disk" sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=1 seek=2048 >/dev/null 2>&1
    run_with_spinner "Erasing blocks at 2097152 on /dev/$each_disk" sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=4 seek=2097152 >/dev/null 2>&1
    run_with_spinner "Erasing blocks at 20971520 on /dev/$each_disk" sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=4 seek=20971520 >/dev/null 2>&1
    run_with_spinner "Erasing blocks at 209715200 on /dev/$each_disk" sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=4 seek=209715200 >/dev/null 2>&1
    run_with_spinner "Erasing blocks at 2097152000 on /dev/$each_disk" sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=4 seek=2097152000 >/dev/null 2>&1

    DISKSIZE=$(sudo blockdev --getsize64 /dev/$each_disk)
    LASTBLOCK=$(( $DISKSIZE / 512 ))
    run_with_spinner "Erasing last 2 blocks on /dev/$each_disk" sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=2 seek=$(($LASTBLOCK - 2)) >/dev/null 2>&1

    print_success "Disk /dev/$each_disk has been successfully nuked!"
  else
    print_success "Disk /dev/$each_disk is fine for reuse"
  fi
done

print_section "Disk Check and Cleanup Complete"

# --- Remove Bootstrap Snaps ---
print_section "Removing Bootstrap Snaps"
for snap in k8s cinder-volume manila-data grafana-agent kubectl epa-orchestrator opentelemetry-collector node-exporter juju helm microovn; do
  run_with_spinner "Removing $snap snap" sudo snap remove --purge $snap
done

# --- Remove Misc Files ---
print_section "Cleaning Up Miscellaneous Files"
run_with_spinner "Removing Juju services" sudo /usr/sbin/remove-juju-services

print_info "Removing Juju and OpenStack directories..."
for dir in /var/lib/juju ~/.local/share/juju ~/.local/share/openstack ~/snap/openstack ~/snap/openstack-hypervisor ~/snap/microstack ~/snap/juju ~/snap/k8s /run/containerd ~/.kube/cache; do
  run_with_spinner "Removing $dir" sudo rm -rf $dir
done

run_with_spinner "Removing immutable attribute from vault_keys" sudo chattr -i ./vault_keys

# --- Remove LXD ---
print_section "Removing LXD"
print_info "Stopping and deleting all LXD containers..."
for container in $(lxc list -c n -f csv); do
  run_with_spinner "Stopping and deleting container: $container" lxc stop $container >/dev/null 2>&1 && lxc delete $container >/dev/null 2>&1
done

run_with_spinner "Removing LXD snap" sudo snap remove --purge lxd

# --- Completion ---
print_section "System Cleanup Complete"
echo -e "${MAGENTA}${BOLD}All tasks completed. System is ready for reuse.${NC}"