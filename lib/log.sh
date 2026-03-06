#!/usr/bin/env bash
# shuttle logging utilities

set -euo pipefail

# log_info MSG
# Print an informational message to stderr.
log_info() {
  printf '[shuttle] INFO  %s\n' "$*" >&2
}

# log_warn MSG
# Print a warning message to stderr.
log_warn() {
  printf '[shuttle] WARN  %s\n' "$*" >&2
}

# log_error MSG
# Print an error message to stderr.
log_error() {
  printf '[shuttle] ERROR %s\n' "$*" >&2
}

# log_debug MSG
# Print a debug message to stderr only when SHUTTLE_VERBOSE=1.
log_debug() {
  [[ "${SHUTTLE_VERBOSE:-0}" == "1" ]] || return 0
  printf '[shuttle] DEBUG %s\n' "$*" >&2
}

# log_die MSG [EXIT_CODE]
# Print an error and terminate with EXIT_CODE (default 1).
log_die() {
  local msg="${1:-fatal error}"
  local code="${2:-1}"

  log_error "$msg"
  exit "$code"
}
