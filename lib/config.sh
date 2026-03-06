#!/usr/bin/env bash
# shuttle configuration loader and resolver

set -euo pipefail

# Discovery globals.
SHUTTLE_PROJECT_ROOT=""
SHUTTLE_PROJECT_CONF=""

# Global credentials.
SHUTTLE_REMOTE_HOST=""
SHUTTLE_REMOTE_USER=""
SHUTTLE_SSH_PORT="22"
SHUTTLE_SSH_KEY=""

# Flat profile map: section.key -> value.
declare -gA _SHUTTLE_PROFILES=()

# Resolved transfer variables.
SHUTTLE_XFER_HOST=""
SHUTTLE_XFER_PORT=""
SHUTTLE_XFER_KEY=""
SHUTTLE_XFER_REMOTE_ROOT=""
SHUTTLE_XFER_LOCAL_ROOT=""
SHUTTLE_XFER_DIRECTION=""
SHUTTLE_XFER_EXCLUDES=""
SHUTTLE_XFER_INCLUDES=""
SHUTTLE_XFER_EXTRA_FLAGS=""
SHUTTLE_XFER_DELETE="no"
SHUTTLE_XFER_VERIFY="no"

# config_trim VALUE
# Trim leading and trailing whitespace.
config_trim() {
  local value="${1-}"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "${value}"
}

# config_strip_quotes VALUE
# Remove one pair of surrounding single or double quotes.
config_strip_quotes() {
  local value="${1-}"

  if [[ "${value}" =~ ^"(.*)"$ ]]; then
    value="${BASH_REMATCH[1]}"
  elif [[ "${value}" =~ ^\'(.*)\'$ ]]; then
    value="${BASH_REMATCH[1]}"
  fi

  printf '%s\n' "${value}"
}

# config_line_is_unsafe LINE
# Return success if line contains shell-expansion-like tokens.
config_line_is_unsafe() {
  local line="${1-}"

  [[ "${line}" == *'`'* || "${line}" == *'$('* || "${line}" == *'${'* ]]
}

# config_append_colon EXISTING VALUE
# Append VALUE to EXISTING using colon separator.
config_append_colon() {
  local existing="${1-}"
  local value="${2-}"

  if [[ -z "${value}" ]]; then
    printf '%s\n' "${existing}"
  elif [[ -z "${existing}" ]]; then
    printf '%s\n' "${value}"
  else
    printf '%s:%s\n' "${existing}" "${value}"
  fi
}

# config_discover_project
# Walk up from PWD to / searching for .shuttle.conf.
# On success sets SHUTTLE_PROJECT_ROOT and SHUTTLE_PROJECT_CONF and returns 0.
# On failure returns 1 without mutating discovery globals.
config_discover_project() {
  local saved_pwd="${PWD}"
  local cursor="${PWD}"
  local resolved=""
  local candidate=""

  while :; do
    if ! cd -P "${cursor}" >/dev/null 2>&1; then
      break
    fi

    resolved="${PWD}"
    candidate="${resolved}/.shuttle.conf"

    if [[ -f "${candidate}" ]]; then
      SHUTTLE_PROJECT_ROOT="${resolved}"
      SHUTTLE_PROJECT_CONF="${candidate}"
      cd "${saved_pwd}" >/dev/null 2>&1 || true
      return 0
    fi

    if [[ "${resolved}" == "/" ]]; then
      break
    fi

    cursor="$(dirname "${resolved}")"
  done

  cd "${saved_pwd}" >/dev/null 2>&1 || true
  return 1
}

# config_load_global
# Load and validate global credentials file.
config_load_global() {
  local conf_path=""
  local owner_uid=""
  local current_uid=""
  local mode=""
  local raw_line=""
  local line=""
  local key=""
  local value=""

  if [[ -n "${SHUTTLE_GLOBAL_CONF:-}" ]]; then
    conf_path="${SHUTTLE_GLOBAL_CONF}"
  else
    conf_path="${XDG_CONFIG_HOME:-$HOME/.config}/shuttle/credentials.env"
  fi

  [[ -f "${conf_path}" ]] || log_die "global credentials file not found: ${conf_path}"

  current_uid="$(id -u)"
  if util_is_darwin; then
    if owner_uid="$(/usr/bin/stat -f %u "${conf_path}" 2>/dev/null)"; then
      :
    elif owner_uid="$(stat -f %u "${conf_path}" 2>/dev/null)"; then
      :
    else
      log_die "unable to read owner uid for ${conf_path}"
    fi
  else
    if owner_uid="$(stat -c %u "${conf_path}" 2>/dev/null)"; then
      :
    else
      log_die "unable to read owner uid for ${conf_path}"
    fi
  fi

  [[ "${owner_uid}" == "${current_uid}" ]] || {
    log_die "credentials owner uid ${owner_uid} does not match current uid ${current_uid}: ${conf_path}"
  }

  mode="$(util_stat_mode "${conf_path}")"
  [[ "${mode}" == "0600" ]] || log_die "credentials mode must be 0600, got ${mode}: ${conf_path}"

  SHUTTLE_REMOTE_HOST=""
  SHUTTLE_REMOTE_USER=""
  SHUTTLE_SSH_PORT="22"
  SHUTTLE_SSH_KEY=""

  while IFS= read -r raw_line || [[ -n "${raw_line}" ]]; do
    line="$(config_trim "${raw_line}")"

    [[ -n "${line}" ]] || continue
    [[ "${line:0:1}" == "#" ]] && continue

    if config_line_is_unsafe "${line}"; then
      continue
    fi

    if [[ "${line}" =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="$(config_trim "${BASH_REMATCH[2]}")"
      value="$(config_strip_quotes "${value}")"

      case "${key}" in
        REMOTE_HOST) SHUTTLE_REMOTE_HOST="${value}" ;;
        REMOTE_USER) SHUTTLE_REMOTE_USER="${value}" ;;
        SSH_PORT)
          if [[ -n "${value}" ]]; then
            SHUTTLE_SSH_PORT="${value}"
          fi
          ;;
        SSH_KEY) SHUTTLE_SSH_KEY="${value}" ;;
        *)
          log_warn "config_load_global: unknown key '${key}' in ${conf_path}"
          ;;
      esac
    else
      log_warn "config_load_global: ignoring malformed line in ${conf_path}: ${line}"
    fi
  done < "${conf_path}"

  [[ -n "${SHUTTLE_REMOTE_HOST}" ]] || log_die "REMOTE_HOST is required in ${conf_path}"
  [[ -n "${SHUTTLE_REMOTE_USER}" ]] || log_die "REMOTE_USER is required in ${conf_path}"
  [[ "${SHUTTLE_SSH_PORT}" =~ ^[0-9]+$ ]] || log_die "SSH_PORT must be numeric in ${conf_path}"
}

# config_load_project PROFILE_NAME
# Parse all profiles from SHUTTLE_PROJECT_CONF into _SHUTTLE_PROFILES.
config_load_project() {
  local requested_profile="${1:-default}"
  local conf_path="${SHUTTLE_PROJECT_CONF:-}"
  local section=""
  local raw_line=""
  local line=""
  local key=""
  local value=""
  local profile_key=""

  [[ -n "${conf_path}" ]] || log_die "project config path is not set (run config_discover_project first)"
  [[ -f "${conf_path}" ]] || log_die "project config file not found: ${conf_path}"
  [[ -n "${SHUTTLE_PROJECT_ROOT:-}" ]] || log_die "project root is not set (run config_discover_project first)"

  unset _SHUTTLE_PROFILES
  declare -gA _SHUTTLE_PROFILES=()

  while IFS= read -r raw_line || [[ -n "${raw_line}" ]]; do
    line="$(config_trim "${raw_line}")"

    [[ -n "${line}" ]] || continue
    [[ "${line:0:1}" == "#" ]] && continue

    if config_line_is_unsafe "${line}"; then
      continue
    fi

    if [[ "${line}" =~ ^\[([A-Za-z0-9_.-]+)\]$ ]]; then
      section="${BASH_REMATCH[1]}"
      _SHUTTLE_PROFILES["${section}.__exists"]="1"
      _SHUTTLE_PROFILES["${section}.local_root"]="${SHUTTLE_PROJECT_ROOT}"
      _SHUTTLE_PROFILES["${section}.direction"]="both"
      _SHUTTLE_PROFILES["${section}.delete"]="no"
      _SHUTTLE_PROFILES["${section}.verify"]="no"
      _SHUTTLE_PROFILES["${section}.exclude"]=""
      _SHUTTLE_PROFILES["${section}.include"]=""
      _SHUTTLE_PROFILES["${section}.rsync_flags"]=""
      continue
    fi

    if [[ -z "${section}" ]]; then
      log_warn "config_load_project: ignoring line outside any section in ${conf_path}: ${line}"
      continue
    fi

    if [[ "${line}" =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="$(config_trim "${BASH_REMATCH[2]}")"
      value="$(config_strip_quotes "${value}")"
      profile_key="${section}.${key}"

      case "${key}" in
        remote_root)
          _SHUTTLE_PROFILES["${profile_key}"]="${value}"
          ;;
        local_root)
          if [[ -n "${value}" ]]; then
            _SHUTTLE_PROFILES["${profile_key}"]="${value}"
          else
            _SHUTTLE_PROFILES["${profile_key}"]="${SHUTTLE_PROJECT_ROOT}"
          fi
          ;;
        direction)
          case "${value}" in
            up|down|both) _SHUTTLE_PROFILES["${profile_key}"]="${value}" ;;
            *) log_die "invalid direction '${value}' in [${section}] (${conf_path})" ;;
          esac
          ;;
        exclude)
          _SHUTTLE_PROFILES["${section}.exclude"]="$(config_append_colon "${_SHUTTLE_PROFILES[${section}.exclude]:-}" "${value}")"
          ;;
        include)
          _SHUTTLE_PROFILES["${section}.include"]="$(config_append_colon "${_SHUTTLE_PROFILES[${section}.include]:-}" "${value}")"
          ;;
        rsync_flags)
          _SHUTTLE_PROFILES["${profile_key}"]="${value}"
          ;;
        delete)
          case "${value}" in
            yes|no) _SHUTTLE_PROFILES["${profile_key}"]="${value}" ;;
            *) log_die "invalid delete value '${value}' in [${section}] (${conf_path})" ;;
          esac
          ;;
        verify)
          case "${value}" in
            yes|no) _SHUTTLE_PROFILES["${profile_key}"]="${value}" ;;
            *) log_die "invalid verify value '${value}' in [${section}] (${conf_path})" ;;
          esac
          ;;
        *)
          log_warn "config_load_project: unknown key '${key}' in section [${section}]"
          ;;
      esac
    else
      log_warn "config_load_project: ignoring malformed line in ${conf_path}: ${line}"
    fi
  done < "${conf_path}"

  [[ "${_SHUTTLE_PROFILES[default.__exists]:-}" == "1" ]] || {
    log_die "project config must define a [default] section: ${conf_path}"
  }
  [[ -n "${_SHUTTLE_PROFILES[default.remote_root]:-}" ]] || {
    log_die "[default] section must define remote_root: ${conf_path}"
  }

  if [[ -n "${requested_profile}" ]] && [[ "${requested_profile}" != "default" ]]; then
    if [[ "${_SHUTTLE_PROFILES[${requested_profile}.__exists]:-}" != "1" ]]; then
      log_warn "config_load_project: requested profile '${requested_profile}' not found during parse"
    fi
  fi
}

# config_resolve_profile PROFILE_NAME
# Merge global credentials and profile settings into final transfer globals.
config_resolve_profile() {
  local profile="${1:-default}"
  local remote_root=""
  local local_root=""
  local direction=""
  local delete_val=""
  local verify_val=""

  [[ "${_SHUTTLE_PROFILES[${profile}.__exists]:-}" == "1" ]] || {
    log_die "profile '${profile}' not found"
  }

  [[ -n "${SHUTTLE_REMOTE_HOST:-}" ]] || log_die "global REMOTE_HOST is not loaded"
  [[ -n "${SHUTTLE_REMOTE_USER:-}" ]] || log_die "global REMOTE_USER is not loaded"

  remote_root="${_SHUTTLE_PROFILES[${profile}.remote_root]:-}"
  [[ -n "${remote_root}" ]] || log_die "profile '${profile}' is missing remote_root"

  local_root="${_SHUTTLE_PROFILES[${profile}.local_root]:-${SHUTTLE_PROJECT_ROOT}}"
  direction="${_SHUTTLE_PROFILES[${profile}.direction]:-both}"
  delete_val="${_SHUTTLE_PROFILES[${profile}.delete]:-no}"
  verify_val="${_SHUTTLE_PROFILES[${profile}.verify]:-no}"

  case "${direction}" in
    up|down|both) : ;;
    *) log_die "profile '${profile}' has invalid direction '${direction}'" ;;
  esac
  case "${delete_val}" in
    yes|no) : ;;
    *) log_die "profile '${profile}' has invalid delete value '${delete_val}'" ;;
  esac
  case "${verify_val}" in
    yes|no) : ;;
    *) log_die "profile '${profile}' has invalid verify value '${verify_val}'" ;;
  esac

  SHUTTLE_XFER_HOST="${SHUTTLE_REMOTE_USER}@${SHUTTLE_REMOTE_HOST}"
  SHUTTLE_XFER_PORT="${SHUTTLE_SSH_PORT}"
  SHUTTLE_XFER_KEY="${SHUTTLE_SSH_KEY:-}"
  SHUTTLE_XFER_REMOTE_ROOT="${remote_root}"
  SHUTTLE_XFER_LOCAL_ROOT="${local_root}"
  SHUTTLE_XFER_DIRECTION="${direction}"
  SHUTTLE_XFER_EXCLUDES="${_SHUTTLE_PROFILES[${profile}.exclude]:-}"
  SHUTTLE_XFER_INCLUDES="${_SHUTTLE_PROFILES[${profile}.include]:-}"
  SHUTTLE_XFER_EXTRA_FLAGS="${_SHUTTLE_PROFILES[${profile}.rsync_flags]:-}"
  SHUTTLE_XFER_DELETE="${delete_val}"
  SHUTTLE_XFER_VERIFY="${verify_val}"
}
