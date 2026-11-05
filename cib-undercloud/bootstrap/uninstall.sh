#!/usr/bin/env bash
# Remove a Sunbeam install from this host so ./install.sh can start clean.
#
#   ./uninstall.sh                asks first, then removes
#   ./uninstall.sh --yes          no question (for scripts)
#   ./uninstall.sh --keep-disks   leave Ceph disks alone (default: zap disks holding a Ceph OSD)
#
# Removes: the OpenStack, Ceph, Kubernetes, Juju and related snaps; Juju's
# LXD containers (and LXD itself, only if nothing else uses it); Juju and
# Sunbeam state directories (including /etc/cni). Moves this install's admin_openrc, vault_keys,
# certs/ and manifest.yaml into old-<date>/ (useless against a new install,
# but kept in case you need something from them).
#
# Every step runs even if an earlier one fails (half-removed installs are
# what this is for); failures are listed at the end. Full output goes to
# uninstall-<date>.log.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

YES=false
KEEP_DISKS=false
for arg in "$@"; do
  case $arg in
    --yes) YES=true ;;
    --keep-disks) KEEP_DISKS=true ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg (see --help)" >&2; exit 1 ;;
  esac
done

STAMP=$(date +%Y%m%d-%H%M%S)
LOG="$HERE/uninstall-$STAMP.log"
FAILED=()

if [[ -t 1 ]]; then
  RED=$'\033[0;31m' GREEN=$'\033[0;32m' BLUE=$'\033[0;34m' CYAN=$'\033[0;36m'
  MAGENTA=$'\033[0;35m' BOLD=$'\033[1m' NC=$'\033[0m'
else
  RED='' GREEN='' BLUE='' CYAN='' MAGENTA='' BOLD='' NC=''
fi

section() { echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}"; }
info()    { echo -e "${BLUE}ℹ $1${NC}"; }

# step "Label" command args...
# The label is only printed; the command runs as given (no word-splitting
# of a joined string). Spinner while it runs, output to the log, ✓ or ✗
# after, and the last lines of output on failure.
step() {
  local label=$1; shift
  local out; out=$(mktemp)
  echo "### $label: $*" >>"$LOG"
  "$@" >"$out" 2>&1 &
  local pid=$! spin='|/-\' i=0
  if [[ -t 1 ]]; then
    while kill -0 "$pid" 2>/dev/null; do
      printf "\r%s %s" "${spin:i++%4:1}" "$label"
      sleep 0.1
    done
    printf "\r\033[K"
  fi
  wait "$pid"; local rc=$?
  cat "$out" >>"$LOG"
  if (( rc == 0 )); then
    echo -e "${GREEN}✓${NC} $label"
  else
    echo -e "${RED}✗ $label (exit $rc)${NC}"
    tail -n 5 "$out" | sed 's/^/    /'
    FAILED+=("$label")
  fi
  rm -f "$out"
  return $rc
}

installed() { snap list "$1" >/dev/null 2>&1; }

remove_snap() {
  if installed "$1"; then step "Remove snap $1" sudo snap remove --purge "$1"; fi
}

# ---------------------------------------------------------------- confirm --
section "Sunbeam uninstall on $(hostname -f)"
bluestore=""
if ! $KEEP_DISKS; then
  bluestore=$(python3 -I ./utils/ceph-disks.py --bluestore 2>/dev/null || true)
fi
echo "This removes OpenStack, Ceph, Kubernetes, Juju and their data from this host."
if [[ -n $bluestore ]]; then
  echo "It also ZAPS these Ceph disks:"
  tr ',' '\n' <<<"$bluestore" | sed 's/^/    /'
elif ! $KEEP_DISKS; then
  echo "No disks with a Ceph OSD found; no disks will be touched."
fi
if ! $YES; then
  read -r -p "Type 'uninstall' to continue: " answer
  [[ $answer == uninstall ]] || { echo "nothing changed"; exit 1; }
fi
sudo -v || exit 1

# ------------------------------------------------------ OpenStack and Ceph --
section "OpenStack and Ceph"
remove_snap openstack
remove_snap openstack-hypervisor
remove_snap microceph

if [[ -n $bluestore ]]; then
  section "Ceph disks"
  step "Zap $bluestore" sudo python3 -I ./utils/ceph-disks.py --zap "$bluestore" --yes --force-bluestore
fi

# ------------------------------------------------- Kubernetes, Juju, extras --
section "Bootstrap snaps"
for s in k8s cinder-volume manila-data grafana-agent kubectl epa-orchestrator \
         opentelemetry-collector node-exporter microovn helm juju juju-db; do
  remove_snap "$s"
done

section "Juju and Sunbeam state"
if [[ -x /usr/sbin/remove-juju-services ]]; then
  step "Remove Juju services" sudo /usr/sbin/remove-juju-services
fi
for dir in /var/lib/juju "$HOME/.local/share/juju" "$HOME/.local/share/openstack" \
           "$HOME/snap/openstack" "$HOME/snap/openstack-hypervisor" "$HOME/snap/microstack" \
           "$HOME/snap/juju" "$HOME/snap/k8s" /run/containerd "$HOME/.kube/cache" \
           /etc/cni; do
  # /etc/cni: the k8s snap's CNI config (net.d). Left behind, the next
  # Kubernetes picks up the old network plugin's config and pods can't start.
  if [[ -e $dir ]]; then step "Remove $dir" sudo rm -rf "$dir"; fi
done

# ------------------------------------------------------------------- LXD --
# Only Juju's containers. LXD itself goes only if nothing else is left in it
# (on a desktop it may be yours).
if installed lxd; then
  section "LXD"
  for c in $(lxc list -c n -f csv 2>/dev/null | grep '^juju-' || true); do
    step "Delete Juju container $c" lxc delete --force "$c"
  done
  if [[ -z $(lxc list -c n -f csv 2>/dev/null) ]]; then
    remove_snap lxd
  else
    info "LXD kept: it still has containers that aren't Juju's ($(lxc list -c n -f csv | tr '\n' ' '))"
  fi
fi

# --------------------------------------------------- this install's files --
section "Files from install.sh"
old="old-$STAMP"
for f in admin_openrc vault_keys certs manifest.yaml; do
  if [[ -e $f ]]; then
    mkdir -m 700 -p "$old"
    if [[ $f == vault_keys ]]; then step "Unlock vault_keys" sudo chattr -i vault_keys; fi
    step "Move $f to $old/" sudo mv "$f" "$old/"
  fi
done

# ---------------------------------------------------------------- summary --
section "Done"
if (( ${#FAILED[@]} )); then
  echo -e "${RED}${#FAILED[@]} step(s) failed:${NC}"
  printf '    %s\n' "${FAILED[@]}"
  echo "Details: $LOG. Re-running ./uninstall.sh is safe; it skips what's already gone."
  exit 1
fi
echo -e "${MAGENTA}${BOLD}Host is clean. Next: ./install.sh --check${NC}"
echo "Log: $LOG"
