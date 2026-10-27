#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly BOOTSTRAP_CONFIG_NAME="foxbook-autoconfig.cfg"
readonly SPLITVIEW_CONFIG_NAME="foxbook-splitview.cfg"
readonly PREF_NAME="foxbook-autoconfig.js"
readonly LEGACY_PREF_NAME="foxbook-splitview-autoconfig.js"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

find_firefox_dir() {
  local candidate sudo_home
  local -a candidates=(/usr/lib64/firefox /usr/lib/firefox /opt/firefox)

  # `sudo` changes HOME to root's home directory. Prefer the invoking user's
  # dedicated Firefox when it is installed under ~/.local/opt.
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
[[ -f "${PROJECT_DIR}/autoconfig/${BOOTSTRAP_CONFIG_NAME}" ]] || die "source missing: ${BOOTSTRAP_CONFIG_NAME}"
[[ -f "${PROJECT_DIR}/autoconfig/${SPLITVIEW_CONFIG_NAME}" ]] || die "source missing: ${SPLITVIEW_CONFIG_NAME}"
[[ -f "${PROJECT_DIR}/autoconfig/defaults/pref/${PREF_NAME}" ]] || die "source missing: ${PREF_NAME}"

if [[ -z "${target_dir}" ]]; then
  target_dir="$(find_firefox_dir)" || die 'Firefox installation not found; pass FIREFOX_DIR explicitly'
fi
[[ -f "${target_dir}/application.ini" ]] || die "not a Firefox installation: ${target_dir}"

readonly -a source_files=(
  "${PROJECT_DIR}/autoconfig/${BOOTSTRAP_CONFIG_NAME}"
  "${PROJECT_DIR}/autoconfig/${SPLITVIEW_CONFIG_NAME}"
  "${PROJECT_DIR}/autoconfig/defaults/pref/${PREF_NAME}"
)
readonly -a target_files=(
  "${target_dir}/${BOOTSTRAP_CONFIG_NAME}"
  "${target_dir}/${SPLITVIEW_CONFIG_NAME}"
  "${target_dir}/defaults/pref/${PREF_NAME}"
)
legacy_pref_target="${target_dir}/defaults/pref/${LEGACY_PREF_NAME}"

if [[ "${mode}" == "check" ]]; then
  matches=true
  for index in "${!source_files[@]}"; do
    if [[ ! -f "${target_files[index]}" ]] || ! cmp -s "${source_files[index]}" "${target_files[index]}"; then
      matches=false
    fi
  done
  if [[ "${matches}" == true && ! -e "${legacy_pref_target}" ]]; then
    printf 'installed and matches: %s\n' "${target_dir}"
    exit 0
  fi
  printf 'not installed or differs: %s\n' "${target_dir}" >&2
  exit 1
fi

backup_dir="${target_dir}/foxbook-autoconfig-backup-$(date +%Y%m%d-%H%M%S)"
for index in "${!source_files[@]}"; do
  source="${source_files[index]}"
  target="${target_files[index]}"
  if [[ -e "${target}" ]] && ! cmp -s "${source}" "${target}"; then
    relative_target="${target#"${target_dir}/"}"
    mkdir -p -- "${backup_dir}/$(dirname -- "${relative_target}")"
    cp -a -- "${target}" "${backup_dir}/${relative_target}"
  fi
done

for index in "${!source_files[@]}"; do
  install -D -o root -g root -m 0644 -- \
    "${source_files[index]}" "${target_files[index]}"
done

# v0.1 used a different pref filename. Leaving it in place would create two
# competing values for general.config.filename, so remove only this known
# legacy Foxbook file after the new files have been installed successfully.
if [[ -e "${legacy_pref_target}" ]]; then
  rm -- "${legacy_pref_target}"
  printf 'removed legacy config entry: %s\n' "${legacy_pref_target}"
fi

printf 'installed: %s\n' "${target_dir}"
[[ -d "${backup_dir}" ]] && printf 'backup: %s\n' "${backup_dir}"
