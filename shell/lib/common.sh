#!/usr/bin/env bash

resolve_env_setup_root() {
  local src="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
  while [[ -L "$src" ]]; do
    local dir
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")/.." && pwd
}

init_shell_common() {
  if [[ -z "${SHELL_SCRIPT_DIR:-}" ]]; then
    SHELL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
  if [[ -z "${ENV_SETUP_ROOT:-}" ]]; then
    ENV_SETUP_ROOT="$(resolve_env_setup_root)"
  fi
  # shellcheck source=../groovy/lib/logging.sh
  source "$ENV_SETUP_ROOT/groovy/lib/logging.sh"
  load_shell_config
}

load_shell_config() {
  # shellcheck source=../config.defaults
  source "$SHELL_SCRIPT_DIR/config.defaults"
}

strip_zshrc_env_hooks() {
  local zshrc="$1"
  local tmp="${zshrc}.env-setup-strip.$$"
  awk '
    /# >>> env-setup >>>/ { skip=1; next }
    /# <<< env-setup >>>/ { skip=0; next }
    /# >>> env-setup groovy >>>/ { skip=1; next }
    /# <<< env-setup groovy >>>/ { skip=0; next }
    !skip { print }
  ' "$zshrc" > "$tmp"
  mv "$tmp" "$zshrc"
}

ensure_zshrc_hook() {
  local env_file="$ENV_SETUP_ROOT/env-setup.env.zsh"
  local zshrc="${HOME}/.zshrc"
  if [[ ! -f "$env_file" ]]; then
    die_preflight "Missing unified env file: $env_file"
  fi
  if [[ ! -f "$zshrc" ]]; then
    touch "$zshrc"
  fi
  strip_zshrc_env_hooks "$zshrc"
  {
    echo ""
    echo "$ZSHRC_HOOK_BEGIN"
    echo "source \"$env_file\""
    echo "$ZSHRC_HOOK_END"
  } >> "$zshrc"
  log_info "Updated ~/.zshrc env-setup hook"
  if grep -qE 'openjdk(@[0-9]+)?/bin' "$zshrc" 2>/dev/null; then
    log_warn "Consider removing bare openjdk PATH lines from ~/.zshrc (now managed by switchGroovy/switchJava)"
  fi
}

show_shell_setup_help() {
  cat << 'EOF'
Usage: setup.sh [options]

Install unified env-setup shell hook in ~/.zshrc.

Options:
  -h, --help       Show this help and exit
      --verbose    Enable debug logging

Examples:
  ./setup.sh

Related:
  ./verify.sh
  ../env-setup.env.zsh
EOF
}

show_shell_verify_help() {
  cat << 'EOF'
Usage: verify.sh [options]

Verify ~/.zshrc hook and shell functions load in zsh.

Options:
  -h, --help       Show this help and exit
      --verbose    Enable debug logging
EOF
}

preflight_shell() {
  if [[ ! -f "$ENV_SETUP_ROOT/env-setup.env.zsh" ]]; then
    die_preflight "Missing env-setup.env.zsh at repo root"
  fi
  if [[ ! -f "$SHELL_SCRIPT_DIR/shell.env.zsh" ]]; then
    die_preflight "Missing shell/shell.env.zsh"
  fi
}
