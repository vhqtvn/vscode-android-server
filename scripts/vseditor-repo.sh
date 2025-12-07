#!/usr/bin/env bash
set -euo pipefail

# Manage Termux-style packages for VS Editor prefix.
# Repository: https://vsc.vhn.vn/termux-packages-24
# Prefix:     /data/data/vn.vhn.vsc/files/usr

PREFIX_BASE="/data/data/vn.vhn.vsc"
PREFIX="$PREFIX_BASE/files/usr"
ARCH_FILE="$PREFIX/.current-arch"
REPO_URL="https://vsc.vhn.vn/termux-packages-24"
KEY_URL="https://raw.githubusercontent.com/vhqtvn/VHEditor-Android/refs/heads/master/app/src/main/res/raw/vhnvn.gpg"
SUPPORTED_ARCHES=("aarch64" "arm" "i686" "x86_64")
REMAP_ARCHES=([x86]="i686")
KEY_ID="40BBE8394CCCDE8F"
KEYSERVER="hkps://keyserver.ubuntu.com"


BUILDING_USER=$(ls -n /vscode/dev.sh | awk '{print $3}')
if [ "$EUID" -ne 0 ]; then
  USERRUN=
else
  BUILDING_USER=$(ls -n /vscode/dev.sh | awk '{print $3}')
  BUILDING_GROUP=$(ls -n /vscode/dev.sh | awk '{print $4}')
  USERRUN="sudo -E -H -u #$BUILDING_USER"
fi

usage() {
  cat <<'EOF'
Usage:
  vseditor-repo.sh activate <arch>
  vseditor-repo.sh install <package>
  vseditor-repo.sh load

Commands:
  activate   Switch the active root to the given arch, restoring an existing
             backup if present or creating a fresh root.
  install    Install a package into the currently active root using the repo.
  load       Print environment exports for using headers/libs (no PATH change).
EOF
}

err() {
  echo "error: $*" >&2
  exit 1
}

info() {
  echo "[+] $*"
}

require_arch() {
  local arch="$1"
  local ok=1
  for a in "${SUPPORTED_ARCHES[@]}"; do
    [[ "$a" == "$arch" ]] && ok=0 && break
  done
  (( ok == 0 )) || err "unsupported arch '$arch' (supported: ${SUPPORTED_ARCHES[*]})"
}

current_arch() {
  [[ -f "$ARCH_FILE" ]] || err "missing $ARCH_FILE; activate an arch first"
  tr -d '[:space:]' <"$ARCH_FILE"
}

apt_opts() {
  local arch="$1"
  printf '%s\n' \
    "-o" "Dir=$PREFIX" \
    "-o" "Dir::Etc::sourcelist=$PREFIX/etc/apt/sources.list" \
    "-o" "Dir::Etc::trusted=$PREFIX/etc/apt/trusted.gpg" \
    "-o" "Dir::Etc::trustedparts=$PREFIX/etc/apt/trusted.gpg.d" \
    "-o" "Dir::Etc::sourceparts=-" \
    "-o" "Dir::State=$PREFIX/var/lib/apt" \
    "-o" "Dir::Cache=$PREFIX/var/cache/apt" \
    "-o" "APT::Architecture=$arch" \
    "-o" "Acquire::AllowInsecureRepositories=true" \
    "-o" "Acquire::AllowDowngradeToInsecureRepositories=true" \
    "-o" "DPkg::Options::=--force-not-root" \
    "-o" "DPkg::Options::=--admindir=$PREFIX/var/lib/dpkg" \
    "-o" "DPkg::Options::=--force-architecture" \
    "-o" "DPkg::Options::=--force-depends"
}

ensure_dirs() {
  local arch="$1"
  mkdir -p "$PREFIX"
  local curr="$PREFIX"
  while [[ "$curr" != "/" ]]; do
    if ! $USERRUN test -r "$curr"; then
      chmod +rx "$curr"
    fi
    curr="$(dirname "$curr")"
  done

  chown -R $BUILDING_USER "$PREFIX"

  $USERRUN mkdir -p \
    "$PREFIX/etc/apt" \
    "$PREFIX/etc/apt/preferences.d" \
    "$PREFIX/etc/apt/trusted.gpg.d" \
    "$PREFIX/var/lib/apt/lists/partial" \
    "$PREFIX/var/cache/apt/archives/partial" \
    "$PREFIX/var/log/apt" \
    "$PREFIX/var/lib/dpkg"

  # Minimal dpkg state so apt can operate.
  $USERRUN touch "$PREFIX/var/lib/dpkg/status"
  $USERRUN touch "$PREFIX/var/lib/dpkg/available"

  echo "deb [arch=$arch] $REPO_URL stable main" | $USERRUN tee "$PREFIX/etc/apt/sources.list"
  import_repo_key
  echo "$arch" | $USERRUN tee "$ARCH_FILE"
}

import_repo_key() {
  command -v gpg >/dev/null 2>&1 || err "gpg is required to import repository key"
  if $USERRUN gpg --no-default-keyring --keyring "$PREFIX/etc/apt/trusted.gpg" --list-keys "$KEY_ID" >/dev/null 2>&1; then
    info "repository key $KEY_ID already present"
    return
  fi
  command -v curl >/dev/null 2>&1 || err "curl is required to download repository key"
  info "fetching repository key from $KEY_URL"
  local tmp
  tmp="$($USERRUN mktemp)"
  $USERRUN curl -fsSL "$KEY_URL" -o "$tmp"
  info "importing repository key $KEY_ID from downloaded file"
  $USERRUN gpg --no-default-keyring --keyring "$PREFIX/etc/apt/trusted.gpg" --import "$tmp"
  $USERRUN rm -f "$tmp"
}

move_with_suffix_if_exists() {
  local src="$1"
  local dest="$2"
  if [[ -e "$dest" ]]; then
    local ts
    ts="$(date +%s)"
    local alt="${dest}.${ts}"
    info "destination $dest exists; moving it to $alt"
    mv "$dest" "$alt"
  fi
  mv "$src" "$dest"
}

activate() {
  local arch="$1"
  if [[ -n "${REMAP_ARCHES[$arch]}" ]]; then
    arch="${REMAP_ARCHES[$arch]}"
  fi
  require_arch "$arch"

  if [[ -d "$PREFIX_BASE" && -f "$ARCH_FILE" ]]; then
    local curr
    curr="$(current_arch)"
    if [[ "$curr" == "$arch" ]]; then
      info "arch '$arch' already active"
      return 0
    fi
    local backup_curr="${PREFIX_BASE}.bk-${curr}"
    info "moving current root ($curr) to $backup_curr"
    move_with_suffix_if_exists "$PREFIX_BASE" "$backup_curr"
  elif [[ -d "$PREFIX_BASE" ]]; then
    err "found $PREFIX_BASE without $ARCH_FILE; refusing to proceed"
  fi

  local backup_target="${PREFIX_BASE}.bk-${arch}"
  if [[ -d "$backup_target" ]]; then
    info "restoring backup for arch '$arch' from $backup_target"
    move_with_suffix_if_exists "$backup_target" "$PREFIX_BASE"
  else
    info "creating fresh root for arch '$arch'"
    ensure_dirs "$arch"
  fi

  info "updating package lists for '$arch'"
  local opts
  mapfile -t opts < <(apt_opts "$arch")
  $USERRUN apt-get "${opts[@]}" update >/dev/null 2>&1
  info "activation complete for arch '$arch'"
}

install_pkg() {
  local pkg="$1"
  local arch
  arch="$(current_arch)"
  local opts
  mapfile -t opts < <(apt_opts "$arch")
  info "updating package lists for '$arch'"
  $USERRUN apt-get "${opts[@]}" update
  info "installing '$pkg' into $PREFIX (arch: $arch)"
  $USERRUN apt-get "${opts[@]}" install -y "$pkg"
}

run_env() {
  local arch
  arch="$(current_arch)"
  local inc_flag="-I$PREFIX/include"
  local ld_flag="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"
  local pc_libdir="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"

  [[ "${CPPFLAGS:-}" == *"$inc_flag"* ]] || CPPFLAGS="${CPPFLAGS:+$CPPFLAGS }$inc_flag"
  [[ "${LDFLAGS:-}" == *"$ld_flag"* ]] || LDFLAGS="${LDFLAGS:+$LDFLAGS }$ld_flag"

  case ":${PKG_CONFIG_LIBDIR:-}:" in
    *":$PREFIX/lib/pkgconfig:"*) : ;;
    *) PKG_CONFIG_LIBDIR="${PKG_CONFIG_LIBDIR:+$PKG_CONFIG_LIBDIR:}$PREFIX/lib/pkgconfig" ;;
  esac
  case ":${PKG_CONFIG_LIBDIR:-}:" in
    *":$PREFIX/share/pkgconfig:"*) : ;;
    *) PKG_CONFIG_LIBDIR="${PKG_CONFIG_LIBDIR:+$PKG_CONFIG_LIBDIR:}$PREFIX/share/pkgconfig" ;;
  esac
  PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"

  CFLAGS="${CFLAGS:-}"
  [[ "$CFLAGS" == *"$inc_flag"* ]] || CFLAGS="${CFLAGS:+$CFLAGS }$inc_flag"
  CXXFLAGS="${CXXFLAGS:-}"
  [[ "$CXXFLAGS" == *"$inc_flag"* ]] || CXXFLAGS="${CXXFLAGS:+$CXXFLAGS }$inc_flag"

  export CPPFLAGS LDFLAGS PKG_CONFIG_LIBDIR PKG_CONFIG_PATH CFLAGS CXXFLAGS

  echo "Running in vh editor root: $@" >/dev/stderr
  "$@"
}

main() {
  [[ $# -lt 1 ]] && { usage; exit 1; }
  local cmd="$1"; shift
  case "$cmd" in
    activate)
      [[ $# -eq 1 ]] || err "activate requires <arch>"
      activate "$1"
      ;;
    install)
      [[ $# -eq 1 ]] || err "install requires <package>"
      install_pkg "$1"
      ;;
    env)
      run_env "$@"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"