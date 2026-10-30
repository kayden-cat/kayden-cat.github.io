#!/usr/bin/env bash
# Start local preview. Usage: dev.sh [-h]. Requires Hugo.
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"
case "${1:-}" in -h|--help) printf 'Usage: dev.sh\nPreview at http://localhost:1313.\n'; exit 0 ;; '') ;; *) die 'Unknown argument.' ;; esac
require_cmd hugo hugo
# Hugo must load this site's configuration regardless of the caller's directory.
# shellcheck disable=SC2154 # Provided by common.sh.
cd -- "$repo_root"
info 'Preview: http://localhost:1313'
exec hugo server -D --navigateToChanged
