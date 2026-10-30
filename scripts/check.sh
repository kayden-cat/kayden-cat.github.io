#!/usr/bin/env bash
# Run all pre-publish checks. Usage: check.sh [-h]. Requires Hugo, Ruby and ffmpeg.
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"
case "${1:-}" in -h|--help) printf 'Usage: check.sh\nRun content, identity and build checks.\n'; exit 0 ;; '') ;; *) die 'Unknown argument.' ;; esac
# Continue after each failure so the final table shows every result.
result=0; statuses=()
for step in check-content check-identity build; do
  info "--- $step ---"
  if "$script_dir/$step.sh"; then statuses+=(PASS); else statuses+=(FAIL); result=1; fi
done
printf '\n%-16s %s\n' 'CHECK' 'RESULT'
printf '%-16s %s\n' content "${statuses[0]}" identity "${statuses[1]}" build "${statuses[2]}"
if ((result)); then fail 'Checks failed.'; else ok 'All checks passed.'; fi
exit "$result"
