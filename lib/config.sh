#!/usr/bin/env bash
# rmt config scaffolding
# Intended responsibilities:
# - Discover project config (.rmt.conf)
# - Load global credentials from XDG config path
# - Parse project INI profiles
# - Resolve effective runtime config for selected profile

set -euo pipefail

# Project-level discovery outputs.
RMT_PROJECT_ROOT=""
RMT_PROJECT_CONF=""

# Global credentials outputs.
RMT_REMOTE_HOST=""
RMT_REMOTE_USER=""
RMT_SSH_PORT="22"
RMT_SSH_KEY=""

# Profile-scoped settings (associative arrays keyed by profile name).
declare -gA RMT_PROFILE_REMOTE_ROOT=()
declare -gA RMT_PROFILE_LOCAL_ROOT=()
declare -gA RMT_PROFILE_DIRECTION=()
declare -gA RMT_PROFILE_DELETE=()
declare -gA RMT_PROFILE_VERIFY=()
declare -gA RMT_PROFILE_RSYNC_FLAGS=()
declare -gA RMT_PROFILE_EXCLUDES=()
declare -gA RMT_PROFILE_INCLUDES=()

# Resolved transfer settings after profile merge.
RMT_EFFECTIVE_PROFILE="default"
RMT_EFFECTIVE_REMOTE_ROOT=""
RMT_EFFECTIVE_LOCAL_ROOT=""
RMT_EFFECTIVE_DIRECTION=""
RMT_EFFECTIVE_DELETE="no"
RMT_EFFECTIVE_VERIFY="no"

# config_discover_project
# Walk upward from $PWD to locate .rmt.conf.
# On success set:
# - RMT_PROJECT_ROOT
# - RMT_PROJECT_CONF
# Return 0 on success, 1 if no project config is found.
config_discover_project() {
  # TODO: implement upward directory walk and discovery logic.
  return 1
}

# config_load_global
# Load global credentials from:
#   ${XDG_CONFIG_HOME:-$HOME/.config}/rmt/credentials.env
# Validate ownership and mode (must be owned by current UID and mode 600).
# Parse KEY=VALUE manually (no source), ignoring comments/blank lines.
# Populate:
# - RMT_REMOTE_HOST
# - RMT_REMOTE_USER
# - RMT_SSH_PORT (default 22)
# - RMT_SSH_KEY (optional)
config_load_global() {
  # TODO: implement secure credentials loading and validation.
  return 0
}

# config_load_project
# Parse .rmt.conf (INI-like) with sections [default] and named profiles.
# Recognized keys per section:
# - remote_root
# - local_root (default: project root)
# - direction (up|down|both)
# - exclude (repeatable)
# - include (repeatable)
# - rsync_flags
# - delete (yes|no, default no)
# - verify (yes|no, default no; yes implies --append-verify behavior)
# Populate associative arrays keyed by profile name.
config_load_project() {
  # TODO: implement INI parser and profile population.
  return 0
}

# config_resolve_profile
# Merge global credentials and selected profile (default: "default") into
# final transfer variables consumed by transfer builders/executors.
config_resolve_profile() {
  local profile="${1:-default}"

  # TODO: implement profile resolution and default fallback behavior.
  RMT_EFFECTIVE_PROFILE="$profile"
  return 0
}
