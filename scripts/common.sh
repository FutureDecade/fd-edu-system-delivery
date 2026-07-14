#!/usr/bin/env bash

load_env_file() {
  local env_file="$1"
  local line=""
  local key=""
  local value=""

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# || "${line}" != *=* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    export "${key}=${value}"
  done < "${env_file}"
}

set_env_value() {
  local env_file="$1"
  local key="$2"
  local value="$3"
  local tmp_file=""

  if [[ "${value}" == *$'\n'* || "${value}" == *$'\r'* ]]; then
    echo "Environment value for ${key} must not contain newlines."
    return 1
  fi

  touch "${env_file}"
  tmp_file="$(mktemp "${env_file}.XXXXXX")"
  awk -v key="${key}" -v value="${value}" '
    BEGIN { updated = 0 }
    $0 ~ ("^" key "=") { if (!updated) { print key "=" value; updated = 1 }; next }
    { print }
    END { if (!updated) print key "=" value }
  ' "${env_file}" > "${tmp_file}"
  mv "${tmp_file}" "${env_file}"
}

get_env_value() {
  local env_file="$1"
  local key="$2"
  [[ -f "${env_file}" ]] || return 0
  awk -v key="${key}" '$0 ~ ("^" key "=") { sub("^" key "=", ""); print; exit }' "${env_file}"
}

unset_env_value() {
  local env_file="$1"
  local key="$2"
  local tmp_file=""
  [[ -f "${env_file}" ]] || return 0
  tmp_file="$(mktemp "${env_file}.XXXXXX")"
  awk -v key="${key}" '$0 !~ ("^" key "=") { print }' "${env_file}" > "${tmp_file}"
  mv "${tmp_file}" "${env_file}"
}

generate_secret() {
  openssl rand -hex "${1:-32}"
}

require_value() {
  local key="$1"
  if [[ -z "${!key:-}" ]]; then
    echo "Missing required deployment value: ${key}"
    return 1
  fi
}

detect_registry_host() {
  local image="$1"
  local first_segment="${image%%/*}"
  if [[ "${image}" == */* && ( "${first_segment}" == *.* || "${first_segment}" == *:* || "${first_segment}" == "localhost" ) ]]; then
    printf '%s\n' "${first_segment}"
  fi
}
