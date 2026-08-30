# Unified entrypoint for env-setup environment loading in Zsh.
# Sources Groovy, Java, and Shell interactive utilities and functions.

if [[ -z "${ZSH_VERSION:-}" ]]; then
  echo "env-setup: env-setup.env.zsh must be sourced from zsh (current shell is not zsh)" >&2
  return 1 2>/dev/null || exit 1
fi

_env_setup_dir="${0:A:h}"
# shellcheck source=groovy/groovy.env.zsh
source "$_env_setup_dir/groovy/groovy.env.zsh"
# shellcheck source=shell/shell.env.zsh
source "$_env_setup_dir/shell/shell.env.zsh"