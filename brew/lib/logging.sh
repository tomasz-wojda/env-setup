#!/usr/bin/env bash

ENV_SETUP_VERBOSE="${ENV_SETUP_VERBOSE:-0}"

_env_setup_color_enabled() {
  [[ -t 2 ]] && [[ -z "${NO_COLOR:-}${ENV_SETUP_NO_COLOR:-}" ]]
}

log_info() {
  local msg="$*"
  if _env_setup_color_enabled; then
    if [[ "$msg" == OK:* ]]; then
      printf '[env-setup:brew] \033[32mINFO OK:\033[0m %s\n' "${msg#OK: }" >&2
    else
      printf '[env-setup:brew] \033[32mINFO\033[0m %s\n' "$msg" >&2
    fi
  else
    echo "[env-setup:brew] INFO $msg" >&2
  fi
}

log_info_brew_item_ok() {
  local name="$1"
  local suffix="${2:-installed}"
  if _env_setup_color_enabled; then
    printf '[env-setup:brew] \033[32mINFO OK:\033[0m ' >&2
    printf '\033[38;5;208m%s\033[0m' "$name" >&2
    printf ' %s\n' "$suffix" >&2
  else
    echo "[env-setup:brew] INFO OK: $name $suffix" >&2
  fi
}

log_warn() {
  echo "[env-setup:brew] WARN $*" >&2
}

log_error() {
  local msg="$*"
  if _env_setup_color_enabled; then
    if [[ "$msg" == FAIL:* ]]; then
      printf '[env-setup:brew] \033[31mERROR FAIL:\033[0m %s\n' "${msg#FAIL: }" >&2
    else
      printf '[env-setup:brew] \033[31mERROR\033[0m %s\n' "$msg" >&2
    fi
  else
    echo "[env-setup:brew] ERROR $msg" >&2
  fi
}

log_error_brew_item_fail() {
  local name="$1"
  local suffix="${2:-not installed}"
  if _env_setup_color_enabled; then
    printf '[env-setup:brew] \033[31mERROR FAIL:\033[0m ' >&2
    printf '\033[38;5;208m%s\033[0m' "$name" >&2
    printf ' %s\n' "$suffix" >&2
  else
    echo "[env-setup:brew] ERROR FAIL: $name $suffix" >&2
  fi
}

log_debug() {
  if [[ "$ENV_SETUP_VERBOSE" == "1" ]]; then
    echo "[env-setup:brew] DEBUG $*" >&2
  fi
}

die_usage() {
  log_error "$1"
  exit 1
}

die_preflight() {
  log_error "$1"
  exit 2
}

die_install() {
  log_error "$1"
  exit 3
}

die_validate() {
  log_error "$1"
  exit 4
}
