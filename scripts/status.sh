#!/usr/bin/env bash
# Show local status and optionally check the live site. Usage: status.sh [-h].
# SITE_URL overrides the URL derived from the origin remote. Requires git and curl.
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"
case "${1:-}" in -h|--help) printf 'Usage: status.sh\nShow identity, changes, content TODOs and site status.\n'; exit 0 ;; '') ;; *) die 'Unknown argument.' ;; esac
require_cmd git git
require_cmd curl curl
remote=''; site="${SITE_URL:-}"
# shellcheck disable=SC2154 # Provided by common.sh.
if [[ -d "$repo_root/.git" || -f "$repo_root/.git" ]]; then
  name="$(git -C "$repo_root" config --local --get user.name || true)"
  email="$(git -C "$repo_root" config --local --get user.email || true)"
  remote="$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)"
  changes="$(git -C "$repo_root" status --porcelain | wc -l | tr -d ' ')"
  info "Local identity: ${name:-unset} <${email:-unset}>"
  info "Remote: ${remote:-not set}; uncommitted changes: $changes"
else warn 'not a git repo yet'; fi
# Never initiate authentication just to display status.
if [[ -x "$script_dir/gh.sh" && -d "$HOME/.config/gh-portfolio-student" ]]; then
  "$script_dir/gh.sh" auth status || warn 'Student GitHub authentication unavailable.'
else info 'Student GitHub status: not configured; skipped.'; fi
if [[ -z "$site" && "$remote" =~ [:/]([A-Za-z0-9-]+)/([A-Za-z0-9-]+)\.github\.io(\.git)?$ ]]; then
  owner="${BASH_REMATCH[1]}"; repo_owner="${BASH_REMATCH[2]}"
  if [[ "$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')" == "$(printf '%s' "$repo_owner" | tr '[:upper:]' '[:lower:]')" ]]; then site="https://$repo_owner.github.io/"; fi
fi
if [[ -n "$site" ]]; then
  code="$(curl -L -sS -o /dev/null -w '%{http_code}' --max-time 15 "$site")" || code=000
  if [[ "$code" =~ ^2[0-9][0-9]$ ]]; then ok "Live site: HTTP $code ($site)"; else warn "Live site: HTTP $code ($site)"; fi
else info 'Live site: no URL configured; skipped.'; fi
# The content checker is the single source for its TODO count.
content_output="$("$script_dir/check-content.sh" 2>/dev/null)" || true
count="$(printf '%s\n' "$content_output" | awk '/^TODO warnings: / {print $3}')"
info "Content TODOs: ${count:-unavailable}"
