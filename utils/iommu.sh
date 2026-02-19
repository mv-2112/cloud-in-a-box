#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly GRUB_FILE="/etc/default/grub"
readonly BACKUP_FILE="/etc/default/grub.bak.$(date +%Y%m%d%H%M%S)"
readonly COMMON_PARAM="iommu=pt"

IOMMU_VENDOR_PARAM=""
ACTION="enable"

usage() {
  cat <<EOF
Usage: $0 [-u]

Options:
  -u    Disable IOMMU (removes vendor flag and iommu=pt)
  -h    Show this help
EOF
}

error() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "INFO: $*"
}

require_root() {
  [[ $EUID -eq 0 ]] || error "Run as root (sudo $0)"
}

verify_ubuntu() {
  [[ -f /etc/os-release ]] || error "Cannot verify OS."

  # shellcheck disable=SC1091
  source /etc/os-release

  [[ "${ID:-}" == "ubuntu" ]] || \
    error "This script only supports Ubuntu. Detected: ${ID:-unknown}"

  command -v update-grub >/dev/null 2>&1 || \
    error "update-grub not found. This does not appear to be Ubuntu."
}

verify_grub_file() {
  [[ -f "$GRUB_FILE" ]] || error "$GRUB_FILE not found"

  grep -q '^GRUB_CMDLINE_LINUX_DEFAULT="' "$GRUB_FILE" || \
    error "GRUB_CMDLINE_LINUX_DEFAULT not found or malformed."
}

detect_cpu_vendor() {
  local vendor
  vendor=$(awk -F: '/vendor_id/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo)

  case "$vendor" in
    GenuineIntel)
      IOMMU_VENDOR_PARAM="intel_iommu=on"
      ;;
    AuthenticAMD)
      IOMMU_VENDOR_PARAM="amd_iommu=on"
      ;;
    *)
      error "Unsupported CPU vendor: $vendor"
      ;;
  esac

  info "Detected CPU vendor: $vendor"
}

is_iommu_enabled() {
  grep -qE 'intel_iommu=on|amd_iommu=on' "$GRUB_FILE"
}

backup_grub() {
  cp --preserve=mode,ownership,timestamps "$GRUB_FILE" "$BACKUP_FILE" \
    || error "Failed to create backup"

  info "Backup created: $BACKUP_FILE"
}

add_param_if_missing() {
  local param="$1"

  if ! grep -qE "(^| )${param}( |\")" "$GRUB_FILE"; then
    sed -i -E \
      "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 ${param}\"/" \
      "$GRUB_FILE" || error "Failed to modify $GRUB_FILE"

    info "Added $param"
  fi
}

remove_param() {
  local param_regex="$1"

  sed -i -E \
    "s/(^| )${param_regex}( |\")/\1\2/g" \
    "$GRUB_FILE" || error "Failed to modify $GRUB_FILE"
}

clean_whitespace() {
  sed -i -E \
    's/[[:space:]]+/ /g; s/ \"$/\"/' \
    "$GRUB_FILE"
}

enable_iommu() {
  if is_iommu_enabled; then
    info "IOMMU already enabled."
  else
    backup_grub
    add_param_if_missing "$IOMMU_VENDOR_PARAM"
  fi

  add_param_if_missing "$COMMON_PARAM"
}

disable_iommu() {
  if ! is_iommu_enabled && ! grep -q "$COMMON_PARAM" "$GRUB_FILE"; then
    info "IOMMU already disabled."
    return
  fi

  backup_grub

  remove_param 'intel_iommu=on'
  remove_param 'amd_iommu=on'
  remove_param 'iommu=pt'

  clean_whitespace

  info "Removed IOMMU parameters"
}

update_grub_config() {
  info "Updating grub..."
  update-grub || error "update-grub failed"
}

# ---- Main ----

while getopts ":uh" opt; do
  case "$opt" in
    u) ACTION="disable" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

require_root
verify_ubuntu
verify_grub_file
detect_cpu_vendor

case "$ACTION" in
  enable)  enable_iommu ;;
  disable) disable_iommu ;;
esac

update_grub_config

info "Done. Reboot required."
