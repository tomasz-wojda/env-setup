#!/usr/bin/env bash
# Platform-specific OS detection, JDK packaging backends, directory resolution, and architecture mappings.

# Resolves the directory path containing the Groovy toolchain scripts.
# Inputs: None
# Outputs: Echoes canonical directory path
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

# Loads default Java configurations from config.defaults.
# Inputs: None
# Outputs: None (sources configuration)
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

# Loads layered toolchain configurations including defaults, OS overrides, and local settings.
# Inputs: None
# Outputs: None (sources configurations and sets environment variables)
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

# Detects host operating system kernel and normalizes the OS name.
# Inputs: None (reads uname -s)
# Outputs: Echoes normalized OS identifier ('darwin', 'linux', 'windows', 'unknown')
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

# Detects host CPU architecture and maps to Adoptium naming conventions.
# Inputs: None (reads uname -m)
# Outputs: Echoes architecture identifier ('x64', 'aarch64', etc.)
detect_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) echo "x64" ;;
    aarch64|arm64) echo "aarch64" ;;
    *) echo "$arch" ;;
  esac
}

# Ensures a target directory exists, attempting creation if absent.
# Inputs: $1 - Directory path
# Outputs: None. Exits on failure.
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

# Creates or updates an atomic symbolic link to point current version pointer to target.
# Inputs: $1 - Parent root directory path, $2 - Target destination path
# Outputs: None
link_current() {
  local root="$1"
  local target="$2"
  rm -f "$root/current"
  ln -sfn "$target" "$root/current"
  log_debug "linked $root/current -> $target"
}

# Resolves the installation path for a specific JDK identifier.
# Inputs: $1 - JDK identifier (e.g. "openjdk-17")
# Outputs: Echoes full path to JDK home
java_home_for_id() {
  echo "$JAVA_ROOT/$1"
}

# Maps an internal JDK identifier to the corresponding Homebrew package formula name.
# Inputs: $1 - JDK identifier (e.g. "openjdk-17")
# Outputs: Echoes Homebrew formula name
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

# Resolves Homebrew installation home directory path for a JDK identifier.
# Inputs: $1 - JDK identifier
# Outputs: Echoes path to Java Home inside Homebrew cellars
brew_jdk_home() {
  local pkg
  pkg="$(jdk_brew_package "$1")"
  echo "$(brew --prefix "$pkg" 2>/dev/null)/libexec/openjdk.jdk/Contents/Home"
}

# Validates that a directory path satisfies minimum criteria for a valid JAVA_HOME.
# Inputs: $1 - Directory path to validate
# Outputs: None. Exits on validation failure.
validate_java_home() {
  local home="$1"
  if [[ ! -x "$home/bin/java" ]]; then
    die_validate "Invalid JAVA_HOME (missing bin/java): $home"
  fi
  if [[ ! -d "$home/lib" ]]; then
    die_validate "Invalid JAVA_HOME (missing lib/): $home"
  fi
}

# Checks whether a directory is a valid JAVA_HOME.
# Inputs: $1 - Directory path to check
# Outputs: Returns 0 if valid, 1 otherwise
is_valid_java_home() {
  local home="$1"
  [[ -x "$home/bin/java" && -d "$home/lib" ]]
}

# Validates that a directory path satisfies minimum criteria for a valid GROOVY_HOME.
# Inputs: $1 - Directory path to validate
# Outputs: None. Exits on validation failure.
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

# Checks whether a directory is a valid GROOVY_HOME.
# Inputs: $1 - Directory path to check
# Outputs: Returns 0 if valid, 1 otherwise
is_valid_groovy_home() {
  local home="$1"
  [[ -d "$home/bin" && -d "$home/conf" && -d "$home/lib" ]] || return 1
  find "$home/lib" -maxdepth 1 -name 'groovy-*.jar' 2>/dev/null | grep -q .
}

# Retrieves the formatted version string output of a java binary in a JAVA_HOME.
# Inputs: $1 - Java home directory path
# Outputs: Echoes first line of java -version output or 'not installed'
java_version_string() {
  local home="$1"
  if [[ -x "$home/bin/java" ]]; then
    "$home/bin/java" -version 2>&1 | head -1
  else
    echo "not installed"
  fi
}

# Checks if a Homebrew package is currently installed.
# Inputs: $1 - Homebrew package name
# Outputs: Returns 0 if installed, 1 otherwise
brew_jdk_installed() {
  local pkg="$1"
  brew list "$pkg" >/dev/null 2>&1
}

# Links a Homebrew-installed JDK into the JAVA_ROOT hierarchy.
# Inputs: $1 - JDK identifier (e.g. "openjdk-17")
# Outputs: Returns 0 on success, 1 on failure
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

# Constructs the Adoptium binary download URL for a JDK major version.
# Inputs: $1 - Major version number (e.g. "17", "21", "25", "26")
# Outputs: Echoes full download URL
adoptium_download_url() {
  local major="$1"
  local arch
  arch="$(detect_arch)"
  local base="${ADOPTIUM_API_BASE_URL:-https://api.adoptium.net/v3/binary/latest}"
  echo "${base}/${major}/ga/linux/${arch}/jdk/hotspot/normal/eclipse?project=jdk"
}

# Downloads and installs an Adoptium JDK package on Linux into the JAVA_ROOT hierarchy.
# Inputs: $1 - JDK identifier (e.g. "openjdk-17")
# Outputs: None
install_jdk_adoptium() {
  local jdk_id="$1"
  local major="${jdk_id#openjdk-}"
  local dest="$JAVA_ROOT/$jdk_id"
  local url tmp_dir tarball extracted_dir

  url="$(adoptium_download_url "$major")"
  log_info "Downloading Adoptium JDK $major from $url..."

  tmp_dir="$(mktemp -d)"
  tarball="$tmp_dir/jdk.tar.gz"

  # Curl call: download tarball archive following redirects
  if ! curl -fsSL --retry 3 --retry-delay 2 -o "$tarball" "$url"; then
    rm -rf "$tmp_dir"
    die_install "Failed to download Adoptium JDK $major from $url"
  fi

  if [[ ! -s "$tarball" ]]; then
    rm -rf "$tmp_dir"
    die_install "Downloaded Adoptium JDK archive is empty: $url"
  fi

  log_info "Extracting JDK archive for $jdk_id..."
  # Tar call: unpack archive
  if ! tar -xzf "$tarball" -C "$tmp_dir"; then
    rm -rf "$tmp_dir"
    die_install "Failed to extract Adoptium JDK archive"
  fi

  extracted_dir="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | head -1)"
  if [[ -z "$extracted_dir" || ! -x "$extracted_dir/bin/java" ]]; then
    rm -rf "$tmp_dir"
    die_install "Adoptium archive does not contain a valid JDK structure"
  fi

  ensure_dir "$JAVA_ROOT"
  rm -rf "$dest"
  mv "$extracted_dir" "$dest"
  rm -rf "$tmp_dir"

  validate_java_home "$dest"
  log_info "Adoptium JDK $major installed successfully at $dest"
}

# Updates or refreshes an Adoptium JDK installation on Linux.
# Inputs: $1 - JDK identifier, $2 - Force flag (0 or 1), $3 - Dry run flag (0 or 1)
# Outputs: None
update_jdk_adoptium() {
  local jdk_id="$1"
  local force="${2:-0}"
  local dry_run="${3:-0}"
  local home old new major url
  home="$(java_home_for_id "$jdk_id")"
  old="$(java_version_string "$home")"
  major="${jdk_id#openjdk-}"
  url="$(adoptium_download_url "$major")"

  if [[ "$dry_run" == "1" ]]; then
    log_info "[dry-run] would fetch latest Adoptium JDK $major from $url and refresh $home"
    return 0
  fi

  log_info "Updating Adoptium JDK $major..."
  install_jdk_adoptium "$jdk_id"
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

# Verifies that a JDK is present and valid, installing it via platform backend if absent.
# Inputs: $1 - JDK identifier (e.g. "openjdk-17")
# Outputs: None
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
      if [[ "${JAVA_INSTALL_BACKEND:-adoptium}" != "adoptium" ]]; then
        die_preflight "Unsupported JAVA_INSTALL_BACKEND on Linux: $JAVA_INSTALL_BACKEND"
      fi
      log_info "Installing $jdk_id via Adoptium..."
      install_jdk_adoptium "$jdk_id"
      ;;
    *)
      die_preflight "Unsupported OS: $os"
      ;;
  esac
  log_info "JDK ready: $home ($("$home/bin/java" -version 2>&1 | head -1))"
}

# Updates the 'current' symlink under JAVA_ROOT to point to the designated JDK identifier.
# Inputs: $1 - JDK identifier (e.g. "openjdk-26")
# Outputs: None
set_current_java() {
  local jdk_id="$1"
  link_current "$JAVA_ROOT" "$JAVA_ROOT/$jdk_id"
}

# Writes the versions.conf configuration file recording detected Java versions.
# Inputs: None
# Outputs: Updates versions.conf
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

# Determines highest configured Groovy major mapped to a given JDK identifier.
# Inputs: $1 - JDK identifier
# Outputs: Echoes Groovy major number or returns 1 if not mapped
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

# Constructs shell switch helper hint for switching to a given JDK version.
# Inputs: $1 - JDK identifier
# Outputs: Echoes switch command hint string
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

# Upgrades or refreshes a JDK installation across supported platform backends.
# Inputs: $1 - JDK identifier, $2 - Force flag (0 or 1), $3 - Dry run flag (0 or 1)
# Outputs: None
update_jdk() {
  local jdk_id="$1"
  local force="${2:-0}"
  local dry_run="${3:-0}"
  local home old new
  home="$(java_home_for_id "$jdk_id")"
  old="$(java_version_string "$home")"
  local os
  os="$(detect_os)"
  case "$os" in
    darwin)
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
      ;;
    linux)
      if [[ "${JAVA_INSTALL_BACKEND:-adoptium}" != "adoptium" ]]; then
        die_preflight "Unsupported JAVA_INSTALL_BACKEND on Linux: $JAVA_INSTALL_BACKEND"
      fi
      update_jdk_adoptium "$jdk_id" "$force" "$dry_run"
      ;;
    *)
      die_preflight "update_jdk not yet implemented on: $os"
      ;;
  esac
}

# Updates all configured JDK identifiers sequentially.
# Inputs: $1 - Force flag, $2 - Dry run flag
# Outputs: None
update_jdk_all() {
  local force="$1" dry="$2"
  for id in $JAVA_IDS; do
    update_jdk "$id" "$force" "$dry"
  done
}

# Returns JAVA_HOME directory for a specified Groovy major version.
# Inputs: $1 - Groovy major number
# Outputs: Echoes path to JAVA_HOME
jdk_for_major() {
  local major="$1"
  local var="GROOVY_JDK_$major"
  echo "$JAVA_ROOT/${!var}"
}

# Returns the JDK identifier configured for a specified Groovy major version.
# Inputs: $1 - Groovy major number
# Outputs: Echoes JDK identifier
jdk_id_for_major() {
  local major="$1"
  local var="GROOVY_JDK_$major"
  echo "${!var}"
}