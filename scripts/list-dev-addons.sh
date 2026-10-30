#!/usr/bin/env bash
set -euo pipefail

readonly REGISTRY_PATH="/etc/foxbook/dev-addons.tsv"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 0 ]] || die 'usage: list-dev-addons.sh'

if [[ ! -e "${REGISTRY_PATH}" ]]; then
  printf '%s\n' 'No development extensions are registered.' >&2
  exit 0
fi

[[ -f "${REGISTRY_PATH}" && ! -L "${REGISTRY_PATH}" ]] || \
  die "registry is not a regular file: ${REGISTRY_PATH}"

registry_metadata="$(stat -c '%u %a' -- "${REGISTRY_PATH}")" || \
  die "could not inspect registry: ${REGISTRY_PATH}"
read -r registry_owner registry_mode <<<"${registry_metadata}"
[[ "${registry_owner}" == "0" ]] || \
  die "registry is not owned by root: ${REGISTRY_PATH}"
(( (8#${registry_mode} & 8#022) == 0 )) || \
  die "registry is writable by a non-root user: ${REGISTRY_PATH}"

declare -A source_by_id=()
declare -A listed_id=()
declare -a ids=()
line_number=0
while IFS= read -r line || [[ -n "${line}" ]]; do
  ((++line_number))
  [[ -z "${line}" ]] && continue
  addon_id="${line%%$'\t'*}"
  source_dir="${line#*$'\t'}"
  if [[ "${line}" != *$'\t'* || "${source_dir}" == *$'\t'* || \
        ! "${addon_id}" =~ ^[A-Za-z0-9._@{}-]+$ || \
        -z "${source_dir}" || "${source_dir}" != /* ]]; then
    printf 'warning: ignored invalid registry entry at line %d\n' "${line_number}" >&2
    continue
  fi
  if [[ -z "${listed_id[${addon_id}]+x}" ]]; then
    ids+=("${addon_id}")
    listed_id["${addon_id}"]=1
  fi
  # Match the AutoConfig loader: a later entry for an ID replaces its source.
  source_by_id["${addon_id}"]="${source_dir}"
done < "${REGISTRY_PATH}"

if [[ ${#ids[@]} -eq 0 ]]; then
  printf '%s\n' 'No development extensions are registered.' >&2
  exit 0
fi

for addon_id in "${ids[@]}"; do
  printf '%s\t%s\n' "${addon_id}" "${source_by_id[${addon_id}]}"
done
