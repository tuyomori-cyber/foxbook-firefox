#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

find_firefox_dir() {
  local candidate
  for candidate in /usr/lib64/firefox /usr/lib/firefox /opt/firefox; do
    if [[ -f "${candidate}/application.ini" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

[[ $# -le 1 ]] || die 'usage: uninstall.sh [FIREFOX_DIR]'
[[ "$(id -u)" -eq 0 ]] || die 'run as root (for example: sudo ./scripts/uninstall.sh)'

target_dir="${1:-}"
if [[ -z "${target_dir}" ]]; then
  target_dir="$(find_firefox_dir)" || die 'Firefox installation not found; pass FIREFOX_DIR explicitly'
fi
[[ -f "${target_dir}/application.ini" ]] || die "not a Firefox installation: ${target_dir}"

config_target="${target_dir}/foxbook-splitview.cfg"
pref_target="${target_dir}/defaults/pref/foxbook-splitview-autoconfig.js"

for target in "${config_target}" "${pref_target}"; do
  if [[ -e "${target}" ]]; then
    rm -- "${target}"
    printf 'removed: %s\n' "${target}"
  else
    printf 'not present: %s\n' "${target}"
  fi
done
