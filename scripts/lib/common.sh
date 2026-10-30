#!/usr/bin/env bash
# Shared output, dependency and confirmation helpers. Source from a project script.
# Requirements: bash and standard shell utilities.
set -euo pipefail

# Resolve from this file rather than the caller's current directory.
# shellcheck disable=SC2034 # Public variable consumed by sourcing scripts.
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
if [[ -t 1 ]]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; RESET=''
fi
info() { printf '%s\n' "$*"; }
ok() { printf '%s✅ %s%s\n' "$GREEN" "$*" "$RESET"; }
warn() { printf '%s⚠️ %s%s\n' "$YELLOW" "$*" "$RESET" >&2; }
fail() { printf '%s❌ %s%s\n' "$RED" "$*" "$RESET" >&2; }
die() { fail "$*"; exit 1; }
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing $1; install with: brew install $2"
}
confirm() {
  local answer
  [[ "${ASSUME_YES:-0}" == 1 ]] && return 0
  printf '%s [y/N] ' "$1" >&2
  IFS= read -r answer || return 1
  case "$answer" in y|Y|yes|YES|Yes) return 0 ;; *) return 1 ;; esac
}
