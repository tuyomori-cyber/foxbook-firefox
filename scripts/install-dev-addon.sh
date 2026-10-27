#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly DEV_CONFIG_NAME="foxbook-dev-temp-addon.cfg"
readonly BOOTSTRAP_CONFIG_NAME="foxbook-autoconfig.cfg"
readonly SPLITVIEW_CONFIG_NAME="foxbook-splitview.cfg"
readonly PREF_NAME="foxbook-autoconfig.js"
readonly REGISTRY_DIR="/etc/foxbook"
readonly REGISTRY_PATH="${REGISTRY_DIR}/dev-addons.tsv"

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

manifest_id() {
  python3 - "${1}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    manifest = json.load(source)
gecko = manifest.get("browser_specific_settings", {}).get("gecko", {})
if not gecko:
    gecko = manifest.get("applications", {}).get("gecko", {})
identifier = gecko.get("id")
if not isinstance(identifier, str):
    raise SystemExit("manifest has no Gecko extension ID")
print(identifier)
PY
}

[[ $# -ge 2 && $# -le 3 ]] || die 'usage: install-dev-addon.sh ADDON_ID SOURCE_DIR [FIREFOX_DIR]'
[[ "$(id -u)" -eq 0 ]] || die 'run as root (for example: sudo ./scripts/install-dev-addon.sh ADDON_ID SOURCE_DIR)'
addon_id="$1"
[[ "${addon_id}" =~ ^[A-Za-z0-9._@{}-]+$ ]] || die 'ADDON_ID contains unsupported characters'
[[ -f "${PROJECT_DIR}/autoconfig/${DEV_CONFIG_NAME}" ]] || die "source missing: ${DEV_CONFIG_NAME}"
[[ -f "${PROJECT_DIR}/autoconfig/${SPLITVIEW_CONFIG_NAME}" ]] || die "source missing: ${SPLITVIEW_CONFIG_NAME}"
source_dir="$(realpath -e -- "$2")" || die "source directory does not exist: $2"
[[ -d "${source_dir}" && ! -L "${source_dir}" ]] || die "not an extension source directory: ${source_dir}"
[[ "${source_dir}" != *$'\t'* && "${source_dir}" != *$'\n'* ]] || die 'SOURCE_DIR cannot contain tabs or newlines'
manifest="${source_dir}/manifest.json"
[[ -f "${manifest}" ]] || die "manifest missing from extension source: ${source_dir}"
[[ "$(manifest_id "${manifest}")" == "${addon_id}" ]] || die 'manifest Gecko ID does not match ADDON_ID'

target_dir="${3:-}"
if [[ -z "${target_dir}" ]]; then
  target_dir="$(find_firefox_dir)" || die 'Firefox installation not found; pass FIREFOX_DIR explicitly'
fi
[[ -f "${target_dir}/application.ini" ]] || die "not a Firefox installation: ${target_dir}"
[[ -f "${target_dir}/${BOOTSTRAP_CONFIG_NAME}" && \
   -f "${target_dir}/defaults/pref/${PREF_NAME}" ]] || \
  die 'install the normal Foxbook AutoConfig first: sudo ./scripts/install.sh'

install -d -o root -g root -m 0755 -- "${REGISTRY_DIR}"
temporary_registry="$(mktemp "${REGISTRY_PATH}.XXXXXX")"
temporary_config=""
trap 'rm -f -- "${temporary_registry}" "${temporary_config}"' EXIT
if [[ -f "${REGISTRY_PATH}" ]]; then
  # Some awk implementations treat `--` as an input filename instead of an
  # option terminator. The registry is an absolute, validated path, so pass it
  # directly for portable filtering.
  awk -F '\t' -v id="${addon_id}" '$1 != id { print }' "${REGISTRY_PATH}" > "${temporary_registry}"
fi
printf '%s\t%s\n' "${addon_id}" "${source_dir}" >> "${temporary_registry}"
install -o root -g root -m 0644 -- "${temporary_registry}" "${REGISTRY_PATH}"

temporary_config="$(mktemp)"
cp -- "${PROJECT_DIR}/autoconfig/${SPLITVIEW_CONFIG_NAME}" "${temporary_config}"
printf '\n' >> "${temporary_config}"
cat -- "${PROJECT_DIR}/autoconfig/${DEV_CONFIG_NAME}" >> "${temporary_config}"

config_target="${target_dir}/${BOOTSTRAP_CONFIG_NAME}"
backup_dir="${target_dir}/foxbook-dev-addon-backup-$(date +%Y%m%d-%H%M%S)"
if [[ -e "${config_target}" ]] && ! cmp -s "${temporary_config}" "${config_target}"; then
  mkdir -p -- "${backup_dir}"
  cp -a -- "${config_target}" "${backup_dir}/${BOOTSTRAP_CONFIG_NAME}"
fi
install -D -o root -g root -m 0644 -- \
  "${temporary_config}" "${config_target}"
printf 'registered development extension: %s\n' "${addon_id}"
printf 'source directory: %s\n' "${source_dir}"
printf 'installed combined development configuration: %s\n' "${config_target}"
[[ -d "${backup_dir}" ]] && printf 'backup: %s\n' "${backup_dir}"
