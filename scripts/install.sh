#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly CONFIG_NAME="foxbook-splitview.cfg"
readonly PREF_NAME="foxbook-splitview-autoconfig.js"

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

target_dir=""
mode="install"
case "${1:-}" in
  --check)
    mode="check"
    [[ $# -le 2 ]] || die 'usage: install.sh [--check] [FIREFOX_DIR]'
    target_dir="${2:-}"
    ;;
  "") ;;
  *)
    [[ $# -eq 1 ]] || die 'usage: install.sh [--check] [FIREFOX_DIR]'
    target_dir="$1"
    ;;
esac

[[ "$(id -u)" -eq 0 ]] || die 'run as root (for example: sudo ./scripts/install.sh)'
[[ -f "${PROJECT_DIR}/autoconfig/${CONFIG_NAME}" ]] || die "source missing: ${CONFIG_NAME}"
[[ -f "${PROJECT_DIR}/autoconfig/defaults/pref/${PREF_NAME}" ]] || die "source missing: ${PREF_NAME}"

if [[ -z "${target_dir}" ]]; then
  target_dir="$(find_firefox_dir)" || die 'Firefox installation not found; pass FIREFOX_DIR explicitly'
fi
[[ -f "${target_dir}/application.ini" ]] || die "not a Firefox installation: ${target_dir}"

config_target="${target_dir}/${CONFIG_NAME}"
pref_target="${target_dir}/defaults/pref/${PREF_NAME}"

if [[ "${mode}" == "check" ]]; then
  if [[ -f "${config_target}" && -f "${pref_target}" ]] && \
     cmp -s "${PROJECT_DIR}/autoconfig/${CONFIG_NAME}" "${config_target}" && \
     cmp -s "${PROJECT_DIR}/autoconfig/defaults/pref/${PREF_NAME}" "${pref_target}"; then
    printf 'installed and matches: %s\n' "${target_dir}"
    exit 0
  fi
  printf 'not installed or differs: %s\n' "${target_dir}" >&2
  exit 1
fi

backup_dir="${target_dir}/foxbook-splitview-backup-$(date +%Y%m%d-%H%M%S)"
for target in "${config_target}" "${pref_target}"; do
  if [[ -e "${target}" ]] && ! cmp -s "${target}" "${PROJECT_DIR}/autoconfig/${CONFIG_NAME}" && \
     [[ "${target}" == "${config_target}" ]]; then
    mkdir -p -- "${backup_dir}"
    cp -a -- "${target}" "${backup_dir}/${CONFIG_NAME}"
  elif [[ -e "${target}" ]] && ! cmp -s "${target}" "${PROJECT_DIR}/autoconfig/defaults/pref/${PREF_NAME}" && \
       [[ "${target}" == "${pref_target}" ]]; then
    mkdir -p -- "${backup_dir}/defaults/pref"
    cp -a -- "${target}" "${backup_dir}/defaults/pref/${PREF_NAME}"
  fi
done

install -D -o root -g root -m 0644 -- \
  "${PROJECT_DIR}/autoconfig/${CONFIG_NAME}" "${config_target}"
install -D -o root -g root -m 0644 -- \
  "${PROJECT_DIR}/autoconfig/defaults/pref/${PREF_NAME}" "${pref_target}"

printf 'installed: %s\n' "${target_dir}"
[[ -d "${backup_dir}" ]] && printf 'backup: %s\n' "${backup_dir}"
