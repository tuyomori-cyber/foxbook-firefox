#!/usr/bin/env bash
set -euo pipefail

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

config_target="${target_dir}/foxbook-dev-temp-addon.cfg"
if [[ -e "${config_target}" ]]; then
  rm -- "${config_target}"
  printf 'removed development loader: %s\n' "${config_target}"
else
  printf 'not present: %s\n' "${config_target}"
fi
