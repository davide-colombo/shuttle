#!/usr/bin/env bash
# rmt utility scaffolding

set -euo pipefail

# util_resolve_script_dir
# Resolve the real directory of the calling script, following symlinks.
util_resolve_script_dir() {
  # TODO: implement symlink-aware script directory resolution.
  return 0
}

# util_check_deps
# Verify required commands are present on PATH:
# - rsync
# - ssh
# - awk
# Die with a message listing missing dependencies.
util_check_deps() {
  # TODO: implement dependency checks and unified error reporting.
  return 0
}

# util_require_bash_version
# Ensure Bash version is >= 4.2.
# Die on unsupported versions.
util_require_bash_version() {
  # TODO: implement BASH_VERSINFO guard.
  return 0
}

# util_platform
# Print one of: darwin, linux.
# Die on unsupported OS values.
util_platform() {
  # TODO: implement platform detection.
  return 0
}
