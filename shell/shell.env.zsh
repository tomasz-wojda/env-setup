unalias gcam ssh 2>/dev/null

alias ssh='TERM=xterm ssh'

gcam() {
  local dry_run=0

  if [[ $# -gt 0 && ( "$1" == "-n" || "$1" == "--dry-run" ) ]]; then
    dry_run=1
    shift
  fi

  if [[ "$dry_run" == 1 ]]; then
    if [[ $# -gt 0 ]]; then
      print -r -- ">>> would run: git commit -am \"$*\""
    else
      print -r -- ">>> would run: git commit -am"
    fi
    return 0
  fi

  if [[ $# -gt 0 ]]; then
    git commit -am "$*"
  else
    git commit -am
  fi
}
