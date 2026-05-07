#!/usr/bin/env bash
# shuttle transfer engine

set -euo pipefail

# Built rsync argv.
declare -ga _SHUTTLE_RSYNC_CMD=()

# transfer_join_cmd_for_log
# Join command elements for debug logging.
transfer_join_cmd_for_log() {
  local out=""
  local arg=""
  for arg in "$@"; do
    if [[ -z "$out" ]]; then
      out="$arg"
    else
      out="$out $arg"
    fi
  done
  printf '%s\n' "$out"
}

# transfer_append_colon_patterns FLAG LIST
# Convert colon-separated patterns to repeated --flag=pattern elements.
transfer_append_colon_patterns() {
  local flag="${1:-}"
  local list="${2:-}"
  local item=""

  [[ -n "$flag" ]] || return 0
  [[ -n "$list" ]] || return 0

  while [[ -n "$list" ]]; do
    if [[ "$list" == *:* ]]; then
      item="${list%%:*}"
      list="${list#*:}"
    else
      item="$list"
      list=""
    fi

    [[ -n "$item" ]] || continue
    _SHUTTLE_RSYNC_CMD+=( "--${flag}=${item}" )
  done
}

# transfer_rsync_code_hint CODE
# Print a short explanation for known rsync exit codes.
transfer_rsync_code_hint() {
  local code="${1:-0}"
  case "$code" in
    0)  printf 'success\n' ;;
    5)  printf 'permission denied\n' ;;
    10) printf 'socket error\n' ;;
    11) printf 'file I/O error\n' ;;
    12) printf 'protocol stream error\n' ;;
    23) printf 'partial transfer\n' ;;
    24) printf 'vanished source files\n' ;;
    30) printf 'send/receive timeout\n' ;;
    *)  printf 'unclassified error\n' ;;
  esac
}

# transfer_build_cmd DIRECTION
# Build _SHUTTLE_RSYNC_CMD from resolved profile variables.
transfer_build_cmd() {
  local direction="${1:-}"
  local key_part=""
  local transport=""
  local src=""
  local dst=""
  local extra=""
  local part=""
  local had_noglob=0

  [[ -n "${SHUTTLE_XFER_HOST:-}" ]] || log_die "transfer_build_cmd: SHUTTLE_XFER_HOST is empty"
  [[ -n "${SHUTTLE_XFER_PORT:-}" ]] || log_die "transfer_build_cmd: SHUTTLE_XFER_PORT is empty"
  [[ -n "${SHUTTLE_XFER_REMOTE_ROOT:-}" ]] || log_die "transfer_build_cmd: SHUTTLE_XFER_REMOTE_ROOT is empty"
  [[ -n "${SHUTTLE_XFER_LOCAL_ROOT:-}" ]] || log_die "transfer_build_cmd: SHUTTLE_XFER_LOCAL_ROOT is empty"

  _SHUTTLE_RSYNC_CMD=( rsync )

  if [[ "${SHUTTLE_XFER_VERIFY:-no}" == "yes" ]]; then
    _SHUTTLE_RSYNC_CMD+=( --archive --human-readable --info=progress2 --append-verify )
  else
    _SHUTTLE_RSYNC_CMD+=( --archive --human-readable --info=progress2 --partial --partial-dir=.rsync-partial )
  fi

  if [[ "${SHUTTLE_XFER_DELETE:-no}" == "yes" ]]; then
    _SHUTTLE_RSYNC_CMD+=( --delete )
  fi

  # Symlink handling is explicit for clarity even though --archive implies --links.
  if [[ "${SHUTTLE_XFER_FOLLOW_LINKS:-no}" == "yes" ]]; then
    _SHUTTLE_RSYNC_CMD+=( --copy-links )
  else
    _SHUTTLE_RSYNC_CMD+=( --links )
  fi

  if [[ "${SHUTTLE_DRY_RUN:-0}" == "1" ]]; then
    _SHUTTLE_RSYNC_CMD+=( --dry-run )
  fi

  if [[ -n "${SHUTTLE_XFER_KEY:-}" ]]; then
    key_part=" -i ${SHUTTLE_XFER_KEY}"
  fi
  transport="ssh -p ${SHUTTLE_XFER_PORT}${key_part}"
  _SHUTTLE_RSYNC_CMD+=( "-e" "${transport}" )

  transfer_append_colon_patterns "include" "${SHUTTLE_XFER_INCLUDES:-}"
  transfer_append_colon_patterns "exclude" "${SHUTTLE_XFER_EXCLUDES:-}"

  if [[ -n "${SHUTTLE_XFER_EXTRA_FLAGS:-}" ]]; then
    extra="${SHUTTLE_XFER_EXTRA_FLAGS}"
    case "$-" in
      *f*) had_noglob=1 ;;
      *) had_noglob=0 ;;
    esac
    set -f
    # Intentionally word-split extra flags using default IFS.
    # shellcheck disable=SC2086
    for part in ${extra}; do
      _SHUTTLE_RSYNC_CMD+=( "${part}" )
    done
    if (( had_noglob == 0 )); then
      set +f
    fi
  fi

  case "$direction" in
    up)
      src="${SHUTTLE_XFER_LOCAL_ROOT}/"
      dst="${SHUTTLE_XFER_HOST}:${SHUTTLE_XFER_REMOTE_ROOT}/"
      ;;
    down)
      src="${SHUTTLE_XFER_HOST}:${SHUTTLE_XFER_REMOTE_ROOT}/"
      dst="${SHUTTLE_XFER_LOCAL_ROOT}/"
      ;;
    *)
      log_die "transfer_build_cmd: invalid direction '$direction'"
      ;;
  esac

  _SHUTTLE_RSYNC_CMD+=( "$src" "$dst" )
  log_debug "rsync command: $(transfer_join_cmd_for_log "${_SHUTTLE_RSYNC_CMD[@]}")"
}

# transfer_exec
# Execute _SHUTTLE_RSYNC_CMD and return rsync exit code.
transfer_exec() {
  local rc=0
  local hint=""

  set +e
  "${_SHUTTLE_RSYNC_CMD[@]}"
  rc=$?
  set -e

  if (( rc != 0 )); then
    hint="$(transfer_rsync_code_hint "$rc")"
    log_error "rsync exited with code ${rc} (${hint})"
  fi

  return "$rc"
}

# transfer_status
# Run rsync dry status mode and summarize planned changes.
transfer_status() {
  local direction="${1:-}"
  local summary=""
  local send_count=0
  local delete_count=0
  local total_count=0
  local rc=0

  transfer_build_cmd "$direction"
  _SHUTTLE_RSYNC_CMD+=( --dry-run --itemize-changes )

  set +e
  summary="$("${_SHUTTLE_RSYNC_CMD[@]}" | awk '
    BEGIN { send=0; del=0; }
    /^\*deleting / { del++; next; }
    /^[<>ch\.][^[:space:]]*[[:space:]]/ { send++; next; }
    END { printf "%d %d %d\n", send, del, send + del; }
  ')"
  rc=$?
  set -e

  if [[ -n "$summary" ]]; then
    send_count="${summary%% *}"
    summary="${summary#* }"
    delete_count="${summary%% *}"
    total_count="${summary##* }"
  fi

  log_info "status summary: files_to_send=${send_count} files_to_delete=${delete_count} total=${total_count}"
  return "$rc"
}
