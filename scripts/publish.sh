#!/usr/bin/env bash
# Publish an update. Usage: publish.sh [--yes] "message"
# Requirements: git, ffmpeg, Hugo and the configured student identity.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
cd -- "$repo_root"
message=''
ASSUME_Y=0
while (( $# )); do
  case "$1" in
    -h|--help) printf 'Usage: publish.sh [--yes] "message"\n'; exit 0 ;;
    --yes) ASSUME_Y=1 ;;
    -*) die "Unknown option: $1" ;;
    *) [[ -z "$message" ]] || die 'Provide exactly one commit message.'; message="$1" ;;
  esac
  shift
done
[[ -n "$message" ]] || die 'A commit message is required.'
# Prevent accidental tool or co-author attribution in public history.
if printf '%s\n' "$message" | grep -Eiq '^[[:space:]]*(co-authored-by|generated-by|signed-off-by):'; then
  die 'Commit message must not contain attribution trailers.'
fi
require_cmd git git
[[ "$(git rev-parse --show-toplevel 2>/dev/null || true)" == "$repo_root" ]] || die 'Project is not a git repository.'
[[ "$(git branch --show-current)" == main ]] || die 'The current branch must be main.'
remote="$(git config --local --get remote.origin.url || true)"
[[ "$remote" == git@github.com-ohyun:* ]] || die 'Origin must use git@github.com-ohyun:.'
"$SCRIPT_DIR/setup-identity.sh" --verify
email="$(git config --local --get user.email || true)"
[[ "$email" == *@users.noreply.github.com ]] || die 'Local user.email must be a student GitHub noreply address.'
# Checks and optimization happen before staging, so failures do not create a commit.
"$SCRIPT_DIR/optimize-media.sh"
"$SCRIPT_DIR/check.sh"
git status --short
if (( ASSUME_Y )); then export ASSUME_YES=1; else unset ASSUME_YES; fi
confirm 'Commit and push these changes?' || { warn 'Stopped before commit.'; exit 0; }
git add -A
git commit -m "$message"
identity="$(git log -1 --format='%an <%ae> | %cn <%ce>')"
info "Last commit: $identity"
[[ "$identity" == "Ohyun Kwon <$email> | Ohyun Kwon <$email>" ]] || die 'Commit author or committer is not the student; do not push.'
# Check the committed message too, because a Git hook could modify it.
if git log -1 --format=%B | grep -Eiq '^[[:space:]]*(co-authored-by|generated-by|signed-off-by):'; then
  die 'Commit contains an attribution trailer; do not push.'
fi
git push
repo="${remote#git@github.com-ohyun:}"
repo="${repo%.git}"
ok "Actions: https://github.com/$repo/actions"
