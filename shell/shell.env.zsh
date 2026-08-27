unalias gcam ssh ls gss glo 2>/dev/null

ls() {
  command ls -la "$@"
}

ssh() {
  TERM=xterm command ssh "$@"
}

gss() {
  git status --short "$@"
}

glo() {
  git log --oneline -10 "$@"
}

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
