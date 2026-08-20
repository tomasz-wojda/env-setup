#!/usr/bin/env bash

resolve_groovy_dir() {
  local src="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
  while [[ -L "$src" ]]; do
    local dir
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")/.." && pwd
}

load_java_config() {
  local java_config
  if [[ -n "${JAVA_SCRIPT_DIR:-}" ]]; then
    java_config="$JAVA_SCRIPT_DIR/config.defaults"
  elif [[ -n "${GROOVY_SCRIPT_DIR:-}" ]]; then
    java_config="$GROOVY_SCRIPT_DIR/../java/config.defaults"
  else
    java_config="$(resolve_groovy_dir)/../java/config.defaults"
  fi
  if [[ ! -f "$java_config" ]]; then
    die_preflight "Missing java config: $java_config"
  fi
  # shellcheck source=/dev/null
  source "$java_config"
}

load_config() {
  if [[ -z "${GROOVY_SCRIPT_DIR:-}" ]]; then
    GROOVY_SCRIPT_DIR="$(resolve_groovy_dir)"
  fi
  load_java_config
  # shellcheck source=/dev/null
  source "$GROOVY_SCRIPT_DIR/config.defaults"
  local os
  os="$(detect_os)"
  if [[ -f "$GROOVY_SCRIPT_DIR/config.$os.sh" ]]; then
    # shellcheck source=/dev/null
    source "$GROOVY_SCRIPT_DIR/config.$os.sh"
  fi
  if [[ -f "$GROOVY_SCRIPT_DIR/config.local.sh" ]]; then
    # shellcheck source=/dev/null
    source "$GROOVY_SCRIPT_DIR/config.local.sh"
  fi
  [[ -n "${ENV_SETUP_JAVA_ROOT:-}" ]] && JAVA_ROOT="$ENV_SETUP_JAVA_ROOT"
  [[ -n "${ENV_SETUP_GROOVY_ROOT:-}" ]] && GROOVY_ROOT="$ENV_SETUP_GROOVY_ROOT"
    if [[ -f "$GROOVY_SCRIPT_DIR/versions.conf" ]]; then
    # shellcheck source=/dev/null
    source "$GROOVY_SCRIPT_DIR/versions.conf"
  fi
}

detect_os() {
  local u
  u="$(uname -s)"
  case "$u" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

ensure_dir() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    return 0
  fi
  if mkdir -p "$dir" 2>/dev/null; then
    return 0
  fi
  die_preflight "Cannot create directory: $dir (try: sudo mkdir -p $dir && sudo chown $(whoami) $dir)"
}

link_current() {
  local root="$1"
  local target="$2"
  local name
  name="$(basename "$target")"
  rm -f "$root/current"
  ln -sfn "$target" "$root/current"
  log_debug "linked $root/current -> $target"
}

java_home_for_id() {
  echo "$JAVA_ROOT/$1"
}

jdk_brew_package() {
  local jdk_id="$1"
  case "$jdk_id" in
    openjdk-17) echo "openjdk@17" ;;
    openjdk-21) echo "openjdk@21" ;;
    openjdk-25) echo "openjdk@25" ;;
    openjdk-26) echo "openjdk" ;;
    *) die_usage "Unknown JDK id: $jdk_id" ;;
  esac
}

brew_jdk_home() {
  local pkg
  pkg="$(jdk_brew_package "$1")"
  echo "$(brew --prefix "$pkg" 2>/dev/null)/libexec/openjdk.jdk/Contents/Home"
}

validate_java_home() {
  local home="$1"
  if [[ ! -x "$home/bin/java" ]]; then
    die_validate "Invalid JAVA_HOME (missing bin/java): $home"
  fi
  if [[ ! -d "$home/lib" ]]; then
    die_validate "Invalid JAVA_HOME (missing lib/): $home"
  fi
}

is_valid_java_home() {
  local home="$1"
  [[ -x "$home/bin/java" && -d "$home/lib" ]]
}

validate_groovy_home() {
  local home="$1"
  if [[ ! -d "$home/bin" || ! -d "$home/conf" || ! -d "$home/lib" ]]; then
    die_validate "Invalid GROOVY_HOME (need bin, conf, lib): $home"
  fi
  local jar
  jar="$(find "$home/lib" -maxdepth 1 -name 'groovy-*.jar' 2>/dev/null | head -1)"
  if [[ -z "$jar" ]]; then
    die_validate "Invalid GROOVY_HOME (no lib/groovy-*.jar): $home"
  fi
}

is_valid_groovy_home() {
  local home="$1"
  [[ -d "$home/bin" && -d "$home/conf" && -d "$home/lib" ]] || return 1
  find "$home/lib" -maxdepth 1 -name 'groovy-*.jar' 2>/dev/null | grep -q .
}

java_version_string() {
  local home="$1"
  if [[ -x "$home/bin/java" ]]; then
    "$home/bin/java" -version 2>&1 | head -1
  else
    echo "not installed"
  fi
}

brew_jdk_installed() {
  local pkg="$1"
  brew list "$pkg" >/dev/null 2>&1
}

symlink_jdk_from_brew() {
  local jdk_id="$1"
  local pkg dest src
  pkg="$(jdk_brew_package "$jdk_id")"
  dest="$JAVA_ROOT/$jdk_id"
  if ! brew_jdk_installed "$pkg"; then
    return 1
  fi
  src="$(brew_jdk_home "$jdk_id")"
  if [[ ! -x "$src/bin/java" ]]; then
    return 1
  fi
  ensure_dir "$JAVA_ROOT"
  ln -sfn "$src" "$dest"
  validate_java_home "$dest"
}

ensure_jdk() {
  local jdk_id="$1"
  local home
  home="$(java_home_for_id "$jdk_id")"
  if [[ -d "$home" ]] && [[ -x "$home/bin/java" ]] && [[ -d "$home/lib" ]]; then
    validate_java_home "$home"
    log_info "JDK already valid: $home"
    return 0
  fi
  local os
  os="$(detect_os)"
  case "$os" in
    darwin)
      if [[ "${JAVA_INSTALL_BACKEND:-homebrew}" != "homebrew" ]]; then
        die_preflight "Unsupported JAVA_INSTALL_BACKEND on macOS: $JAVA_INSTALL_BACKEND"
      fi
      if ! command -v brew >/dev/null 2>&1; then
        die_preflight "Homebrew required for JDK install (brew not found)"
      fi
      local pkg
      pkg="$(jdk_brew_package "$jdk_id")"
      if brew_jdk_installed "$pkg"; then
        log_info "Linking existing Homebrew $pkg to $home"
        symlink_jdk_from_brew "$jdk_id"
      else
        log_info "Installing $pkg via Homebrew..."
        if ! brew install "$pkg"; then
          die_install "brew install $pkg failed"
        fi
        symlink_jdk_from_brew "$jdk_id"
      fi
      ;;
    linux)
      die_preflight "Linux JDK install not yet implemented (planned: Adoptium backend)"
      ;;
    *)
      die_preflight "Unsupported OS: $os"
      ;;
  esac
  log_info "JDK ready: $home ($("$home/bin/java" -version 2>&1 | head -1))"
}

set_current_java() {
  local jdk_id="$1"
  link_current "$JAVA_ROOT" "$JAVA_ROOT/$jdk_id"
}

write_java_versions_conf() {
  local conf
  if [[ -n "${JAVA_SCRIPT_DIR:-}" ]]; then
    conf="$JAVA_SCRIPT_DIR/versions.conf"
  else
    conf="$GROOVY_SCRIPT_DIR/../java/versions.conf"
  fi
  local tmp="${conf}.tmp.$$"
  {
    echo "# generated by env-setup"
    for id in $JAVA_IDS; do
      local home v
      home="$(java_home_for_id "$id")"
      v="$(java_version_string "$home")"
      echo "JAVA_${id//-/_}_VERSION=\"$v\""
    done
    echo "JAVA_DEFAULT_MAJOR=${JAVA_DEFAULT_MAJOR}"
  } > "$tmp"
  mv "$tmp" "$conf"
}

highest_groovy_major_for_jdk() {
  local jdk_id="$1"
  local major result=""
  for major in $GROOVY_INITIAL_MAJORS; do
    local var="GROOVY_JDK_$major"
    if [[ "${!var}" == "$jdk_id" ]]; then
      result="$major"
    fi
  done
  if [[ -z "$result" ]]; then
    return 1
  fi
  echo "$result"
}

java_switch_hint_for_jdk() {
  local jdk_id="$1"
  local major suffix
  suffix="${jdk_id#openjdk-}"
  if major="$(highest_groovy_major_for_jdk "$jdk_id")"; then
    echo "java${suffix} or groovy${major}"
  else
    echo "java${suffix}"
  fi
}

update_jdk() {
  local jdk_id="$1"
  local force="${2:-0}"
  local dry_run="${3:-0}"
  local home old new
  home="$(java_home_for_id "$jdk_id")"
  old="$(java_version_string "$home")"
  local os
  os="$(detect_os)"
  if [[ "$os" != "darwin" ]]; then
    die_preflight "update_jdk not yet implemented on: $os"
  fi
  if ! command -v brew >/dev/null 2>&1; then
    die_preflight "Homebrew required for JDK update"
  fi
  local pkg
  pkg="$(jdk_brew_package "$jdk_id")"
  if [[ "$dry_run" == "1" ]]; then
    log_info "[dry-run] would upgrade $pkg and refresh symlink $home"
    return 0
  fi
  log_info "Upgrading $pkg..."
  brew update >/dev/null 2>&1 || log_warn "brew update skipped or failed (continuing)"
  if brew_jdk_installed "$pkg"; then
    brew upgrade "$pkg" 2>/dev/null || {
      if [[ "$force" != "1" ]]; then
        log_info "$pkg already at latest (or upgrade skipped)"
      else
        brew install "$pkg" || die_install "brew upgrade/install $pkg failed"
      fi
    }
  else
    brew install "$pkg" || die_install "brew install $pkg failed"
  fi
  symlink_jdk_from_brew "$jdk_id"
  new="$(java_version_string "$home")"
  if [[ "$old" == "$new" && "$force" != "1" ]]; then
    log_info "$jdk_id already at latest: $new"
  else
    log_info "Upgraded $jdk_id: $old -> $new"
  fi
  log_info "JAVA_HOME path unchanged: $home"
  write_java_versions_conf
  log_info "Re-run in your shell: $(java_switch_hint_for_jdk "$jdk_id")"
}

update_jdk_all() {
  local force="$1" dry="$2"
  for id in $JAVA_IDS; do
    update_jdk "$id" "$force" "$dry"
  done
}

jdk_for_major() {
  local major="$1"
  local var="GROOVY_JDK_$major"
  echo "$JAVA_ROOT/${!var}"
}

jdk_id_for_major() {
  local major="$1"
  local var="GROOVY_JDK_$major"
  echo "${!var}"
}
