#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly BOOTSTRAP_CONFIG_NAME="foxbook-autoconfig.cfg"
readonly SPLITVIEW_CONFIG_NAME="foxbook-splitview.cfg"
readonly LEGACY_DEV_CONFIG_NAME="foxbook-dev-temp-addon.cfg"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

find_firefox_dir() {
  local candidate sudo_home
  local -a candidates=(/usr/lib64/firefox /usr/lib/firefox /opt/firefox)
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    sudo_home="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
    [[ -n "${sudo_home}" ]] && candidates=(
      "${sudo_home}/.local/opt/foxbook-firefox" "${candidates[@]}"
    )
  fi
  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}/application.ini" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

[[ $# -le 1 ]] || die 'usage: uninstall-dev-addon.sh [FIREFOX_DIR]'
[[ "$(id -u)" -eq 0 ]] || die 'run as root (for example: sudo ./scripts/uninstall-dev-addon.sh)'
target_dir="${1:-}"
if [[ -z "${target_dir}" ]]; then
  target_dir="$(find_firefox_dir)" || die 'Firefox installation not found; pass FIREFOX_DIR explicitly'
fi
[[ -f "${target_dir}/application.ini" ]] || die "not a Firefox installation: ${target_dir}"
[[ -f "${PROJECT_DIR}/autoconfig/${SPLITVIEW_CONFIG_NAME}" ]] || \
  die "source missing: ${SPLITVIEW_CONFIG_NAME}"

config_target="${target_dir}/${BOOTSTRAP_CONFIG_NAME}"
if [[ -e "${config_target}" ]]; then
  install -D -o root -g root -m 0644 -- \
    "${PROJECT_DIR}/autoconfig/${SPLITVIEW_CONFIG_NAME}" "${config_target}"
  printf 'restored normal AutoConfig: %s\n' "${config_target}"
else
  die "normal AutoConfig is not installed: ${config_target}"
fi

legacy_config_target="${target_dir}/${LEGACY_DEV_CONFIG_NAME}"
if [[ -e "${legacy_config_target}" ]]; then
  rm -- "${legacy_config_target}"
  printf 'removed legacy development loader: %s\n' "${legacy_config_target}"
fi
