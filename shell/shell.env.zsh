# Shell helper functions, git shortcuts, and command aliases for interactive Zsh sessions.

_local_bin="${HOME}/.local/bin"
if [[ -d "$_local_bin" ]] && [[ ":${path[*]}:" != *":${_local_bin}:"* ]]; then
  path=("$_local_bin" $path)
fi
unset _local_bin

unalias gcam ssh ls gss gssb glo 2>/dev/null || true

# Enhanced ls command providing detailed directory listing format.
# Inputs: $@ - Directory/file arguments passed to ls
# Outputs: Formatted directory listing
ls() {
  command ls -la "$@"
}

# SSH wrapper ensuring standard terminal capability environment.
# Inputs: $@ - Host and SSH connection parameters
# Outputs: Interactive SSH session
ssh() {
  TERM=xterm command ssh "$@"
}

# Git status shortcut with concise status reporting.
# Inputs: $@ - Arguments passed to git status
# Outputs: Short git status output
gss() {
  git status --short "$@"
}

gssb() {
  git status --short --branch "$@"
}

# Git log shortcut displaying the latest ten commits formatted on one line.
# Inputs: $@ - Arguments passed to git log
# Outputs: Git log commit history
glo() {
  git log --oneline -10 "$@"
}

# Git commit shortcut providing automatic staging and commit message handling with dry-run support.
# Inputs: [--amend] [--dry-run] <commit message>
# Outputs: Executes git commit or prints planned action
gcam() {
  local dry_run=0
  local amend=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run)
        dry_run=1
        shift
        ;;
      --amend)
        amend=1
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        print -u2 -r -- "gcam: unknown option: $1"
        return 1
        ;;
      *)
        break
        ;;
    esac
  done

  if [[ $# -eq 0 ]]; then
    print -u2 -r -- "usage: gcam [--amend] [--dry-run] <commit message>"
    return 1
  fi

  local msg="$*"

  if [[ "$dry_run" == 1 ]]; then
    if [[ "$amend" == 1 ]]; then
      print -r -- ">>> would run: git commit --amend -m \"$msg\""
    else
      print -r -- ">>> would run: git commit -am \"$msg\""
    fi
    return 0
  fi

  if [[ "$amend" == 1 ]]; then
    git commit --amend -m "$msg"
  else
    git commit -am "$msg"
  fi
}