unalias gcam 2>/dev/null

gcam() {
  if [[ $# -gt 0 ]]; then
    git commit -am "$*"
  else
    git commit -am
  fi
}
