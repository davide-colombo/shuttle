#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

# shellcheck source=/dev/null
source "${repo_root}/lib/log.sh"
# shellcheck source=/dev/null
source "${repo_root}/lib/transfer.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  [[ "${expected}" == "${actual}" ]] || fail "${message}: expected '${expected}', got '${actual}'"
}

arg_index() {
  local needle="$1"
  local i=0

  for i in "${!_SHUTTLE_RSYNC_CMD[@]}"; do
    if [[ "${_SHUTTLE_RSYNC_CMD[$i]}" == "${needle}" ]]; then
      printf '%s\n' "${i}"
      return 0
    fi
  done

  printf '%s\n' "-1"
}

assert_arg_present() {
  local needle="$1"
  local idx=""

  idx="$(arg_index "${needle}")"
  (( idx >= 0 )) || fail "missing arg '${needle}'"
}

assert_before() {
  local left="$1"
  local right="$2"
  local left_idx=""
  local right_idx=""

  left_idx="$(arg_index "${left}")"
  right_idx="$(arg_index "${right}")"

  (( left_idx >= 0 )) || fail "missing arg '${left}'"
  (( right_idx >= 0 )) || fail "missing arg '${right}'"
  (( left_idx < right_idx )) || fail "expected '${left}' before '${right}'"
}

reset_transfer_vars() {
  SHUTTLE_XFER_HOST="user@example.test"
  SHUTTLE_XFER_PORT="2222"
  SHUTTLE_XFER_KEY=""
  SHUTTLE_XFER_REMOTE_ROOT="/remote/root"
  SHUTTLE_XFER_LOCAL_ROOT="/local/root"
  SHUTTLE_XFER_VERIFY="no"
  SHUTTLE_XFER_DELETE="no"
  SHUTTLE_XFER_FOLLOW_LINKS="no"
  SHUTTLE_DRY_RUN="0"
  SHUTTLE_XFER_INCLUDES=""
  SHUTTLE_XFER_EXCLUDES=""
  SHUTTLE_XFER_EXTRA_FLAGS=""
}

test_whitelist_ordering() {
  reset_transfer_vars
  SHUTTLE_XFER_INCLUDES="/foo/:/foo/*.tsv"
  SHUTTLE_XFER_EXCLUDES="*"

  transfer_build_cmd down

  assert_before "--include=/foo/" "--include=/foo/*.tsv"
  assert_before "--include=/foo/*.tsv" "--exclude=*"
}

test_repeated_include_order() {
  reset_transfer_vars
  SHUTTLE_XFER_INCLUDES="/first/:/second/:/third/*.txt"

  transfer_build_cmd down

  assert_before "--include=/first/" "--include=/second/"
  assert_before "--include=/second/" "--include=/third/*.txt"
}

test_repeated_exclude_order() {
  reset_transfer_vars
  SHUTTLE_XFER_EXCLUDES="*.bam:*.fq.gz:tmp/"

  transfer_build_cmd down

  assert_before "--exclude=*.bam" "--exclude=*.fq.gz"
  assert_before "--exclude=*.fq.gz" "--exclude=tmp/"
}

test_exclude_only_profile() {
  reset_transfer_vars
  SHUTTLE_XFER_EXCLUDES=".git/:__pycache__/"

  transfer_build_cmd down

  assert_arg_present "--exclude=.git/"
  assert_arg_present "--exclude=__pycache__/"
  assert_before "--exclude=.git/" "--exclude=__pycache__/"
}

test_rsync_flags_position() {
  reset_transfer_vars
  SHUTTLE_XFER_INCLUDES="/foo/"
  SHUTTLE_XFER_EXCLUDES="*"
  SHUTTLE_XFER_EXTRA_FLAGS="--compress --checksum"

  transfer_build_cmd down

  assert_before "--include=/foo/" "--exclude=*"
  assert_before "--exclude=*" "--compress"
  assert_before "--compress" "user@example.test:/remote/root/"
  assert_before "--checksum" "/local/root/"
}

test_dry_run_delete_and_links() {
  reset_transfer_vars
  SHUTTLE_XFER_DELETE="yes"
  SHUTTLE_DRY_RUN="1"

  transfer_build_cmd down

  assert_arg_present "--delete"
  assert_arg_present "--dry-run"
  assert_arg_present "--links"
  assert_before "--delete" "--links"
  assert_before "--links" "--dry-run"
}

test_copy_links() {
  reset_transfer_vars
  SHUTTLE_XFER_FOLLOW_LINKS="yes"

  transfer_build_cmd down

  assert_arg_present "--copy-links"
  assert_eq "-1" "$(arg_index "--links")" "--links should not be emitted when follow_links=yes"
}

test_whitelist_ordering
test_repeated_include_order
test_repeated_exclude_order
test_exclude_only_profile
test_rsync_flags_position
test_dry_run_delete_and_links
test_copy_links

printf 'PASS: transfer_build_cmd tests\n'
