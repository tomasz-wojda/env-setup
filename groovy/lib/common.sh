#!/usr/bin/env bash
# Common utility functions, helpers, and workflow procedures for Groovy and Java environment management.

GROOVY_TEMP_DIR=""

# Cleans up temporary working directories created during archive extraction.
# Inputs: None (reads $GROOVY_TEMP_DIR)
# Outputs: None
cleanup_temp() {
  if [[ -n "$GROOVY_TEMP_DIR" && -d "$GROOVY_TEMP_DIR" ]]; then
    rm -rf "$GROOVY_TEMP_DIR"
    GROOVY_TEMP_DIR=""
  fi
}

# Initializes common subsystem libraries, error trapping, and logging.
# Inputs: None
# Outputs: None
init_common() {
  # shellcheck source=logging.sh
  source "$GROOVY_SCRIPT_DIR/lib/logging.sh"
  # shellcheck source=platform.sh
  source "$GROOVY_SCRIPT_DIR/lib/platform.sh"
  trap cleanup_temp EXIT INT TERM
}

# Returns the target installation directory for a given Groovy version.
# Inputs: $1 - Version string (e.g. "4.0.33")
# Outputs: Echoes full path to Groovy directory
groovy_dir_for_version() {
  echo "$GROOVY_ROOT/groovy-$1"
}

# Resolves the configured default pinned version for a Groovy major.
# Inputs: $1 - Major number ("3", "4", "5", "6")
# Outputs: Echoes pinned version string
pinned_version_for_major() {
  local major="$1"
  local var="GROOVY_VERSION_${major}_PIN"
  echo "${!var}"
}

# Resolves the active version for a Groovy major from versions.conf or fallback to pin.
# Inputs: $1 - Major number ("3", "4", "5", "6")
# Outputs: Echoes active version string
version_for_major() {
  local major="$1"
  local var="GROOVY_VERSION_$major"
  if [[ -n "${!var:-}" ]]; then
    echo "${!var}"
  else
    pinned_version_for_major "$major"
  fi
}

# Fetches directory listing HTML from the JFrog Groovy archive repository.
# Inputs: None
# Outputs: Echoes HTML response body
fetch_groovy_listing() {
  # External call: curl to fetch archive listing
  curl -fsSL --retry 3 --retry-delay 2 "$GROOVY_ZIPS_URL"
}

# Parses and lists available Groovy versions on JFrog for a given major.
# Inputs: $1 - Major number ("3", "4", "5", "6")
# Outputs: Echoes newline-delimited sorted version strings
list_jfrog_versions() {
  local major="$1"
  fetch_groovy_listing | grep -oE "${GROOVY_ZIP_PREFIX}-${major}[^\"]+\.zip" \
    | sed "s/${GROOVY_ZIP_PREFIX}-//;s/\.zip//" \
    | sort -V
}

# Retrieves the latest available Groovy release for a given major.
# Inputs: $1 - Major number ("3", "4", "5", "6")
# Outputs: Echoes latest version string
latest_groovy_version() {
  local major="$1"
  list_jfrog_versions "$major" | tail -1
}

# Identifies the preceding published Groovy release for rollback operations.
# Inputs: $1 - Major number, $2 - Current version string
# Outputs: Echoes previous version string, returns 1 if none found
previous_jfrog_version() {
  local major="$1"
  local current="$2"
  local versions v prev=""
  versions="$(list_jfrog_versions "$major")"
  while IFS= read -r v; do
    [[ -z "$v" ]] && continue
    if [[ "$v" == "$current" ]]; then
      if [[ -n "$prev" ]]; then
        echo "$prev"
        return 0
      fi
      return 1
    fi
    prev="$v"
  done <<< "$versions"
  return 1
}

# Constructs the download URL for a specific Groovy version zip archive.
# Inputs: $1 - Groovy version string
# Outputs: Echoes URL string
groovy_zip_url() {
  echo "${GROOVY_ZIPS_URL}${GROOVY_ZIP_PREFIX}-$1.zip"
}

# Downloads a Groovy zip archive to a local target path.
# Inputs: $1 - Groovy version string, $2 - Target destination file path
# Outputs: None
download_groovy_zip() {
  local version="$1"
  local dest="$2"
  local url
  url="$(groovy_zip_url "$version")"
  log_debug "Downloading $url"
  # External call: curl to download archive
  curl -fsSL --retry 3 --retry-delay 2 -o "$dest" "$url" || die_install "Download failed: $url"
  if [[ ! -s "$dest" ]]; then
    die_install "Downloaded zip is empty: $url"
  fi
}

# Unpacks and installs a Groovy archive into the GROOVY_ROOT directory structure.
# Inputs: $1 - Path to zip archive, $2 - Staging directory
# Outputs: Echoes installed version string
install_groovy_zip() {
  local zipfile="$1"
  local staging="$2"
  # External call: unzip archive to staging location
  unzip -q "$zipfile" -d "$staging" || die_install "unzip failed: $zipfile"
  local dir
  dir="$(find "$staging" -maxdepth 1 -type d -name 'groovy-*' | head -1)"
  if [[ -z "$dir" ]]; then
    die_install "No groovy-* directory in zip"
  fi
  validate_groovy_home "$dir"
  local version dest
  version="$(basename "$dir" | sed 's/^groovy-//')"
  dest="$(groovy_dir_for_version "$version")"
  if [[ -d "$dest" ]]; then
    log_info "Groovy already installed: $dest"
  else
    mv "$dir" "$dest"
    log_info "Installed Groovy $version at $dest"
  fi
  echo "$version"
}

# Orchestrates downloading and installing a specified Groovy version.
# Inputs: $1 - Groovy version string
# Outputs: Echoes installed version string
install_groovy_version() {
  local version="$1"
  local dest
  dest="$(groovy_dir_for_version "$version")"
  if [[ -d "$dest" ]]; then
    validate_groovy_home "$dest"
    log_info "Groovy $version already present: $dest"
    echo "$version"
    return 0
  fi
  GROOVY_TEMP_DIR="$(mktemp -d)"
  local zip="$GROOVY_TEMP_DIR/groovy.zip"
  download_groovy_zip "$version" "$zip"
  install_groovy_zip "$zip" "$GROOVY_TEMP_DIR"
}

# Updates the 'current' symlink under GROOVY_ROOT to the specified version.
# Inputs: $1 - Version string
# Outputs: None
set_current_groovy() {
  local version="$1"
  link_current "$GROOVY_ROOT" "$(groovy_dir_for_version "$version")"
}

# Writes the versions.conf configuration file recording active Groovy versions.
# Inputs: None
# Outputs: Updates versions.conf
write_versions_conf() {
  local tmp="$GROOVY_SCRIPT_DIR/versions.conf.tmp.$$"
  {
    echo "# generated by env-setup"
    for major in $GROOVY_INITIAL_MAJORS; do
      local var="GROOVY_VERSION_$major"
      local val
      val="$(version_for_major "$major")"
      echo "${var}=${val}"
    done
    echo "GROOVY_DEFAULT_MAJOR=${GROOVY_DEFAULT_MAJOR}"
  } > "$tmp"
  mv "$tmp" "$GROOVY_SCRIPT_DIR/versions.conf"
}

# Lists all installed Groovy versions found on disk for a given major.
# Inputs: $1 - Major number ("3", "4", "5", "6")
# Outputs: Echoes newline-delimited version strings
installed_groovy_versions() {
  local major="$1"
  local d v
  shopt -s nullglob
  for d in "$GROOVY_ROOT"/groovy-"$major"*; do
    [[ -d "$d" ]] || continue
    v="$(basename "$d" | sed 's/^groovy-//')"
    echo "$v"
  done | sort -V
  shopt -u nullglob
}

# Resolves the active version string pointed to by the 'current' symlink.
# Inputs: None
# Outputs: Echoes current active version string or empty
resolve_current_groovy_version() {
  if [[ -L "$GROOVY_ROOT/current" ]]; then
    basename "$(readlink "$GROOVY_ROOT/current")" | sed 's/^groovy-//'
  fi
}

# Removes older unused installations of a Groovy major version.
# Inputs: $1 - Major number
# Outputs: None
clean_groovy_major() {
  local major="$1"
  local active current_target
  active="$(version_for_major "$major")"
  current_target=""
  if [[ -L "$GROOVY_ROOT/current" ]]; then
    current_target="$(readlink "$GROOVY_ROOT/current")"
  fi
  local v dir
  while IFS= read -r v; do
    [[ -z "$v" ]] && continue
    [[ "$v" == "$active" ]] && continue
    dir="$(groovy_dir_for_version "$v")"
    if [[ -n "$current_target" && "$dir" == "$current_target" ]]; then
      log_warn "Skipping delete (current symlink): $dir"
      continue
    fi
    log_info "Removing $dir"
    rm -rf "$dir"
  done < <(installed_groovy_versions "$major")
}

# Cleans superseded versions across all configured Groovy majors.
# Inputs: None
# Outputs: None
clean_groovy_all() {
  local major
  for major in $GROOVY_INITIAL_MAJORS; do
    clean_groovy_major "$major"
  done
}

# Rolls back a Groovy major to the preceding release version.
# Inputs: $1 - Major number, $2 - Dry run flag (0 or 1)
# Outputs: None
rollback_groovy_major() {
  local major="$1"
  local dry_run="${2:-0}"
  local current active target source="local"
  current="$(version_for_major "$major")"
  active="$current"
  local candidates v
  candidates="$(list_jfrog_versions "$major")"
  target=""
  local -a before_current=()
  while IFS= read -r v; do
    [[ -z "$v" ]] && continue
    if [[ "$v" == "$current" ]]; then
      break
    fi
    before_current+=("$v")
  done <<< "$candidates"
  local i v
  for (( i=${#before_current[@]}-1; i>=0; i-- )); do
    v="${before_current[i]}"
    if [[ -d "$(groovy_dir_for_version "$v")" ]]; then
      target="$v"
      break
    fi
  done
  if [[ -z "$target" ]]; then
    if ! target="$(previous_jfrog_version "$major" "$current")"; then
      die_usage "Already at oldest published version for major $major"
    fi
    source="downloaded"
    if [[ "$dry_run" == "1" ]]; then
      log_info "[dry-run] would download and switch to $target"
      return 0
    fi
    if [[ ! -d "$(groovy_dir_for_version "$target")" ]]; then
      install_groovy_version "$target" >/dev/null
    fi
  else
    if [[ "$dry_run" == "1" ]]; then
      log_info "[dry-run] would switch to local $target"
      return 0
    fi
  fi
  local var="GROOVY_VERSION_$major"
  printf -v "$var" '%s' "$target"
  write_versions_conf
  local default_ver
  default_ver="$(version_for_major "$GROOVY_DEFAULT_MAJOR")"
  if [[ "$major" == "$GROOVY_DEFAULT_MAJOR" ]] || [[ "$(resolve_current_groovy_version)" == "$current" ]]; then
    set_current_groovy "$target"
  fi
  log_info "Rolled back major $major: $current -> $target ($source)"
  log_info "Run: groovy$major or source ~/.zshrc"
}

# Upgrades a Groovy major version to its latest published release.
# Inputs: $1 - Major number, $2 - Clean flag (0 or 1), $3 - Force flag (0 or 1), $4 - Dry run flag (0 or 1)
# Outputs: None
update_groovy_major() {
  local major="$1"
  local clean="${2:-0}"
  local force="${3:-0}"
  local dry_run="${4:-0}"
  local latest current
  latest="$(latest_groovy_version "$major")"
  [[ -z "$latest" ]] && die_install "No versions found on JFrog for major $major"
  current="$(version_for_major "$major")"
  if [[ "$latest" == "$current" && "$force" != "1" ]]; then
    log_info "Major $major already at latest: $current"
    if [[ "$clean" == "1" ]]; then
      clean_groovy_major "$major"
    fi
    return 0
  fi
  if [[ "$dry_run" == "1" ]]; then
    log_info "[dry-run] would update major $major: $current -> $latest"
    return 0
  fi
  install_groovy_version "$latest" >/dev/null
  local var="GROOVY_VERSION_$major"
  printf -v "$var" '%s' "$latest"
  write_versions_conf
  if [[ "$major" == "$GROOVY_DEFAULT_MAJOR" ]] || [[ "$(resolve_current_groovy_version)" == "$current" ]]; then
    set_current_groovy "$latest"
  fi
  log_info "Updated major $major: $current -> $latest"
  if [[ "$clean" == "1" ]]; then
    clean_groovy_major "$major"
  fi
  log_info "Run: groovy$major or source ~/.zshrc"
}

# Displays usage help text for the main Groovy setup script.
# Inputs: None
# Outputs: Prints help text to stdout
show_setup_help() {
  cat << 'EOF'
Usage: setup.sh [options]

Bootstrap Groovy multi-version environment under /opt/groovy and /opt/java.

Options:
  -h, --help           Show this help and exit
      --skip-jdk       Do not install JDKs via Homebrew
      --skip-download  Skip Groovy archive downloads
      --major N        Limit install to major version N (3, 4, 5, or 6)
      --verbose        Enable debug logging

Examples:
  ./setup.sh
  ./setup.sh --major 6
  ./setup.sh --skip-jdk --skip-download

Related:
  ./update-groovy.sh --help
  ./verify.sh
  ../java/setup.sh --help
  source ~/.zshrc && groovy6
EOF
}

# Displays usage help text for the Java setup script.
# Inputs: None
# Outputs: Prints help text to stdout
show_java_setup_help() {
  cat << 'EOF'
Usage: setup.sh [options]

Bootstrap JDK multi-version environment under /opt/java.

Options:
  -h, --help       Show this help and exit
      --major N    Limit install to JDK major N (17, 21, 25, or 26)
      --verbose    Enable debug logging

Examples:
  ./setup.sh
  ./setup.sh --major 26

Related:
  ./verify.sh
  ./update-java.sh --help
  ../groovy/setup.sh --help
EOF
}

# Displays usage help text for the Java verification script.
# Inputs: None
# Outputs: Prints help text to stdout
show_java_verify_help() {
  cat << 'EOF'
Usage: verify.sh [options]

Verify JDK installations under /opt/java.

Options:
  -h, --help       Show this help and exit
      --major N    Limit checks to JDK major N (17, 21, 25, or 26)
      --verbose    Enable debug logging

Related:
  ./setup.sh --help
  ../groovy/verify.sh
EOF
}

# Displays usage help text for the Groovy update script.
# Inputs: None
# Outputs: Prints help text to stdout
show_update_groovy_help() {
  cat << 'EOF'
Usage: update-groovy.sh [major] [options]
       update-groovy.sh --all [options]
       update-groovy.sh --clean-all
       update-groovy.sh --help

Fetch latest Groovy release(s) from JFrog and install under /opt/groovy.

Arguments:
  major                Major Groovy version: 3, 4, 5, or 6

Options:
  -h, --help           Show this help and exit
      --all            Update all configured majors
      --clean          Remove superseded installs after update
      --clean-only     Clean one major only (no download); requires major
      --clean-all      Clean all majors only (no download)
      --dry-run        Show target version(s) without installing
      --force          Reinstall even if already at latest
      --rollback       Roll back within major (local-first, else download)
      --verbose        Enable debug logging

Examples:
  ./update-groovy.sh 6
  ./update-groovy.sh 6 --clean
  ./update-groovy.sh 6 --rollback
  ./update-groovy.sh --all --clean
  ./update-groovy.sh 6 --clean-only
  ./update-groovy.sh --clean-all

Related:
  ./setup.sh --help
  ../java/update-java.sh --help
  groovy3 / groovy4 / groovy5 / groovy6
EOF
}

# Displays usage help text for the Java update script.
# Inputs: None
# Outputs: Prints help text to stdout
show_update_java_help() {
  cat << 'EOF'
Usage: update-java.sh [17|21|25|26] [options]
       update-java.sh --all [options]
       update-java.sh --help

Upgrade JDK installations under /opt/java.

Arguments:
  17|21|25|26         JDK major to upgrade (maps to openjdk-17 / openjdk-21 / openjdk-25 / openjdk-26)

Options:
  -h, --help           Show this help and exit
      --all            Upgrade all configured JDK majors
      --dry-run        Show planned actions only
      --force          Force refresh even if version unchanged
      --verbose        Enable debug logging

Examples:
  ./update-java.sh 26
  ./update-java.sh 17
  ./update-java.sh --all
  ./update-java.sh 25 --dry-run

Related:
  ./setup.sh --help
  ../groovy/setup.sh --help
  Re-run java17, java21, java25, or java26 after JDK upgrade
EOF
}

# Verifies prerequisite commands, system dependencies, directory paths, and network connectivity.
# Inputs: $1 - Skip network flag (0 or 1), $2 - Skip JDK flag (0 or 1)
# Outputs: None. Exits on failure.
preflight_common() {
  local skip_network="${1:-0}"
  local skip_jdk="${2:-0}"
  if [[ "${BASH_VERSINFO[0]:-0}" -lt 3 ]]; then
    die_preflight "bash 3.2+ required"
  fi
  # Verify availability of core CLI utilities
  for cmd in curl unzip sort ln mkdir tar gzip; do
    command -v "$cmd" >/dev/null 2>&1 || die_preflight "Required command not found: $cmd"
  done
  if [[ "$skip_jdk" != "1" ]] && [[ "$(detect_os)" == "darwin" ]]; then
    command -v brew >/dev/null 2>&1 || die_preflight "Homebrew required (brew not found)"
  fi
  ensure_dir "$GROOVY_ROOT"
  ensure_dir "$JAVA_ROOT"
  if [[ "$skip_network" != "1" ]]; then
    curl -fsSL --head "$GROOVY_ZIPS_URL" >/dev/null 2>&1 || die_preflight "Cannot reach JFrog: $GROOVY_ZIPS_URL"
  fi
}