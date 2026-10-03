#!/bin/bash
# Package type registry shared by pkg-* commands and rig-drift.
# Maps package types to list files and per-platform backend operations.
# Source AFTER logging.sh + common.sh (uses cmd_exists) and platform.sh.
# Must stay bash 3.2 compatible (macOS /bin/bash): no mapfile, no assoc arrays.

_PACKAGES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# Ensure cargo tools are reachable for rust-type operations
[[ -d "$HOME/.cargo/bin" ]] && export PATH="$HOME/.cargo/bin:$PATH"

pkg_platform() {
  local platform="${RIG_PLATFORM:-}"
  [[ -n "$platform" ]] || platform="$(detect_platform)"
  # Whitelist: RIG_PLATFORM feeds source/exec paths downstream
  case "$platform" in
  fedora | macos) echo "$platform" ;;
  *)
    echo "Invalid platform: '$platform' (expected fedora or macos)" >&2
    return 1
    ;;
  esac
}

# Reject names that backends could parse as flags or that would split into
# multiple list-file entries
pkg_name_valid() {
  case "$1" in
  "" | -* | *$'\n'* | *[[:space:]]*) return 1 ;;
  esac
  return 0
}

pkg_types() {
  if [[ "$(pkg_platform)" == "macos" ]]; then
    echo "brew cask rust"
  else
    echo "base dev tools system flatpak npm rust bloatware"
  fi
}

# Canonical list-file stem for a type (dev is an alias for development)
pkg_type_file() {
  case "$1" in
  dev | development) echo "development" ;;
  *) echo "$1" ;;
  esac
}

pkg_is_valid_type() {
  local t
  for t in $(pkg_types); do
    [[ "$1" == "$t" ]] && return 0
  done
  return 1
}

pkg_packages_dir() {
  echo "${PACKAGES_DIR:-$_PACKAGES_ROOT/unix/$(pkg_platform)/packages}"
}

pkg_file_for_type() {
  echo "$(pkg_packages_dir)/$(pkg_type_file "$1").packages"
}

# Non-comment, non-blank entries from a list file
pkg_list_entries() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$' || true
}

# Is $2 installed via the backend of type $1?
pkg_installed() {
  local type
  type="$(pkg_type_file "$1")"
  local name="$2"
  case "$type" in
  brew) cmd_exists brew && brew list --formula 2>/dev/null | grep -qxF "$name" ;;
  cask) cmd_exists brew && brew list --cask 2>/dev/null | grep -qxF "$name" ;;
  flatpak) cmd_exists flatpak && flatpak list --app --columns=application 2>/dev/null | grep -qxF "$name" ;;
  npm)
    if cmd_exists npm; then
      # Suffix match on parseable paths: exact for plain and scoped (@org/name)
      # names, immune to regex metacharacters in package names
      while IFS= read -r p; do
        [[ "$p" == *"/$name" ]] && return 0
      done < <(npm ls -g --depth=0 --parseable 2>/dev/null)
    fi
    return 1
    ;;
  rust) cmd_exists "$name" || [[ -f "$HOME/.cargo/bin/$name" ]] ;;
  *) rpm -q "$name" &>/dev/null ;;
  esac
}

# Install a single package via the backend of its type. Not idempotent itself;
# callers check pkg_installed first.
pkg_install_one() {
  local type
  type="$(pkg_type_file "$1")"
  local name="$2"
  case "$type" in
  brew) brew install "$name" ;;
  cask) brew install --cask "$name" ;;
  flatpak) flatpak install -y flathub "$name" ;;
  npm) npm install -g "$name" ;;
  rust) cargo install "$name" ;;
  *) sudo dnf install -y "$name" ;;
  esac
}

# Uninstall a single package via the backend of its type.
pkg_remove_one() {
  local type
  type="$(pkg_type_file "$1")"
  local name="$2"
  case "$type" in
  brew) brew uninstall "$name" ;;
  cask) brew uninstall --cask "$name" ;;
  flatpak) flatpak uninstall -y "$name" ;;
  npm) npm uninstall -g "$name" ;;
  rust) cargo uninstall "$name" ;;
  *) sudo dnf remove -y "$name" ;;
  esac
}

# Explicitly installed (user-chosen) packages for a type — dependency noise
# excluded where the manager allows. Best-effort: empty when the manager is
# absent or can't be introspected.
pkg_list_installed() {
  local type p n
  type="$(pkg_type_file "$1")"
  # if-blocks, never bare "cmd_exists x && cmd": an absent manager must not
  # make this function return nonzero (callers run under set -e)
  case "$type" in
  brew)
    if cmd_exists brew; then brew leaves 2>/dev/null; fi # leaves = no deps
    ;;
  cask)
    if cmd_exists brew; then brew list --cask 2>/dev/null; fi
    ;;
  flatpak)
    if cmd_exists flatpak; then flatpak list --app --columns=application 2>/dev/null; fi
    ;;
  npm)
    if cmd_exists npm; then
      while IFS= read -r p; do
        case "$p" in
        */node_modules/*) ;;
        *) continue ;; # global-root line
        esac
        n="${p#*/node_modules/}"
        case "$n" in
        npm | corepack) continue ;; # ship with node itself
        esac
        echo "$n" # keeps @scope/name form
      done < <(npm ls -g --depth=0 --parseable 2>/dev/null)
    fi
    ;;
  rust)
    if cmd_exists cargo; then cargo install --list 2>/dev/null | sed 's/ .*//;s/:$//'; fi
    ;;
  *)
    # rpm world: userinstalled keeps explicit choices, not the dep tree.
    # Strip .arch, then the trailing version-release dash fields.
    if cmd_exists dnf; then
      dnf repoquery --userinstalled 2>/dev/null |
        awk '{sub(/\.[^.]+$/, ""); n = split($0, f, "-"); if ((n) > 2) {s = f[1]; for (i = 2; i < n - 1; i++) s = s "-" f[i]; print s} else print}'
    fi
    ;;
  esac
}

# Setup module (under install/packaging/) that converges this type
pkg_setup_module() {
  case "$(pkg_type_file "$1")" in
  development | tools | system) echo "base" ;;
  *) pkg_type_file "$1" ;;
  esac
}

# Types sharing one backend namespace with $1. rpm-world types all draw from
# the same dnf pool, so a package declared under ANY of them counts as
# declared for each; the others are their own namespace.
pkg_pool_types() {
  case "$(pkg_type_file "$1")" in
  brew | cask | flatpak | npm | rust)
    pkg_type_file "$1"
    ;;
  *)
    local t
    for t in $(pkg_types); do
      case "$(pkg_type_file "$t")" in
      brew | cask | flatpak | npm | rust) ;;
      *) echo "$t" ;;
      esac
    done
    ;;
  esac
}
