#!/usr/bin/env bash

ENV_SETUP_VERBOSE="${ENV_SETUP_VERBOSE:-0}"

log_info() {
  echo "[env-setup:brew] INFO $*" >&2
}

log_warn() {
  echo "[env-setup:brew] WARN $*" >&2
}

log_error() {
  echo "[env-setup:brew] ERROR $*" >&2
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
