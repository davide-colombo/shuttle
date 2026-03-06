#!/usr/bin/env bash
# rmt utility helpers

set -euo pipefail

# Cache for detected platform.
_RMT_PLATFORM=""

# util_resolve_script_dir [CALLER_SOURCE]
# Resolve and print the absolute, symlink-resolved directory of the caller script.
# If CALLER_SOURCE is empty/unset, fall back to PWD and warn.
util_resolve_script_dir() {
  local source="${1-}"
  local dir=""

  if [[ -z "${source}" ]]; then
    dir="$(cd -P "${PWD}" >/dev/null 2>&1 && pwd)"
    log_warn "util_resolve_script_dir: empty source path, falling back to PWD (${dir})"
    printf '%s\n' "${dir}"
    return 0
  fi

  while [[ -L "${source}" ]]; do
    dir="$(cd -P "$(dirname "${source}")" >/dev/null 2>&1 && pwd)"
    source="$(readlink "${source}")"
    [[ "${source}" == /* ]] || source="${dir}/${source}"
  done

  dir="$(cd -P "$(dirname "${source}")" >/dev/null 2>&1 && pwd)"
  printf '%s\n' "${dir}"
}

# util_check_deps PROG [PROG ...]
# Ensure all requested programs are available on PATH.
util_check_deps() {
  local missing=""
  local prog=""

  for prog in "$@"; do
    [[ -n "${prog}" ]] || continue
    if ! command -v "${prog}" >/dev/null 2>&1; then
      if [[ -n "${missing}" ]]; then
        missing="${missing} ${prog}"
      else
        missing="${prog}"
      fi
    fi
  done

  if [[ -n "${missing}" ]]; then
    log_die "missing dependencies:${missing}"
  fi

  return 0
}

# util_require_bash_version MIN_MAJOR MIN_MINOR
# Ensure current bash version is at least MIN_MAJOR.MIN_MINOR.
util_require_bash_version() {
  local min_major="${1:-}"
  local min_minor="${2:-}"
  local cur_major="${BASH_VERSINFO[0]:-0}"
  local cur_minor="${BASH_VERSINFO[1]:-0}"

  [[ "${min_major}" =~ ^[0-9]+$ && "${min_minor}" =~ ^[0-9]+$ ]] || {
    log_die "util_require_bash_version requires numeric MIN_MAJOR MIN_MINOR"
  }

  if (( cur_major < min_major )) || (( cur_major == min_major && cur_minor < min_minor )); then
    log_die "bash ${min_major}.${min_minor}+ required; current is ${cur_major}.${cur_minor}"
  fi

  return 0
}

# util_platform
# Print normalized platform (darwin or linux) using OSTYPE.
util_platform() {
  local os="${OSTYPE:-}"

  if [[ -z "${os}" ]]; then
    log_die "OSTYPE is not set"
  fi

  case "${os}" in
    darwin*) printf 'darwin\n' ;;
    linux*)  printf 'linux\n' ;;
    *)       log_die "unsupported platform OSTYPE=${os}" ;;
  esac
}

# util_is_darwin
# Return success on darwin, failure otherwise. Caches platform result.
util_is_darwin() {
  if [[ -z "${_RMT_PLATFORM}" ]]; then
    _RMT_PLATFORM="$(util_platform)"
  fi

  [[ "${_RMT_PLATFORM}" == "darwin" ]]
}

# util_stat_size FILE
# Print file size in bytes using platform-appropriate stat flags.
util_stat_size() {
  local file="${1:-}"
  local size=""

  [[ -n "${file}" ]] || log_die "util_stat_size requires a file path"
  [[ -e "${file}" ]] || log_die "file not found: ${file}"

  if util_is_darwin; then
    if size="$(/usr/bin/stat -f %z "${file}" 2>/dev/null)"; then
      :
    elif size="$(stat -f %z "${file}" 2>/dev/null)"; then
      :
    else
      log_die "failed to read size for ${file}"
    fi
  else
    if size="$(stat -c %s "${file}" 2>/dev/null)"; then
      :
    else
      log_die "failed to read size for ${file}"
    fi
  fi

  printf '%s\n' "${size}"
}

# util_stat_mode FILE
# Print file mode in 4-digit octal form (e.g., 0600).
util_stat_mode() {
  local file="${1:-}"
  local mode=""

  [[ -n "${file}" ]] || log_die "util_stat_mode requires a file path"
  [[ -e "${file}" ]] || log_die "file not found: ${file}"

  if util_is_darwin; then
    if mode="$(/usr/bin/stat -f %Lp "${file}" 2>/dev/null)"; then
      :
    elif mode="$(stat -f %Lp "${file}" 2>/dev/null)"; then
      :
    else
      log_die "failed to read mode for ${file}"
    fi
  else
    if mode="$(stat -c %a "${file}" 2>/dev/null)"; then
      :
    else
      log_die "failed to read mode for ${file}"
    fi
  fi

  printf '0%03d\n' "${mode}"
}
