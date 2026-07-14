#!/usr/bin/env bash

resolve_stack_exchange_url() {
  if [[ -n "${FD_STACK_EXCHANGE_URL:-}" ]]; then
    printf '%s\n' "${FD_STACK_EXCHANGE_URL}"
  elif [[ -n "${FD_STACK_PUBLIC_BASE_URL:-}" ]]; then
    printf '%s/v1/deployments/bootstrap/exchange\n' "${FD_STACK_PUBLIC_BASE_URL%/}"
  else
    return 1
  fi
}

apply_stack_bootstrap_defaults() {
  local bootstrap_json="$1"
  local key=""
  local value=""

  export FD_STACK_BOOTSTRAP_JSON="${bootstrap_json}"
  while IFS=$'\t' read -r key value; do
    [[ -n "${key}" ]] && export "${key}=${value}"
  done < <(printf '%s' "${bootstrap_json}" | jq -r '.bootstrap.envDefaults // {} | to_entries[] | [.key, (.value | tostring)] | @tsv')
}

exchange_stack_bootstrap() {
  local exchange_url=""
  local response=""
  require_value FD_STACK_DEPLOY_TOKEN
  exchange_url="$(resolve_stack_exchange_url)"
  response="$(curl -fsSL -X POST "${exchange_url}" -H 'content-type: application/json' -d "{\"token\":\"${FD_STACK_DEPLOY_TOKEN}\"}")"
  apply_stack_bootstrap_defaults "${response}"
}

load_stack_bootstrap() {
  if [[ -n "${FD_STACK_BOOTSTRAP_JSON:-}" ]]; then
    apply_stack_bootstrap_defaults "${FD_STACK_BOOTSTRAP_JSON}"
  else
    exchange_stack_bootstrap
  fi
}

