#!/usr/bin/env bash
# rmt logging utilities

set -euo pipefail

log_info() {
  printf '[rmt] INFO %s\n' "$*" >&2
}

log_warn() {
  printf '[rmt] WARN %s\n' "$*" >&2
}

log_error() {
  printf '[rmt] ERROR %s\n' "$*" >&2
}

log_debug() {
  [[ "${RMT_VERBOSE:-0}" == "1" ]] || return 0
  printf '[rmt] DEBUG %s\n' "$*" >&2
}
