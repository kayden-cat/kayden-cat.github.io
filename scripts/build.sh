#!/usr/bin/env bash
# Build the production site. Usage: build.sh [-h]. Requires Hugo.
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"
case "${1:-}" in -h|--help) printf 'Usage: build.sh\nBuild the production site.\n'; exit 0 ;; '') ;; *) die 'Unknown argument.' ;; esac
require_cmd hugo hugo
# Build from the site root so Hugo finds its configuration.
# shellcheck disable=SC2154 # Provided by common.sh.
cd -- "$repo_root"
hugo build --minify --gc
pages="$(find "$repo_root/public" -type f -name '*.html' | wc -l | tr -d ' ')"
size="$(du -sh "$repo_root/public" | cut -f1)"
ok "Built $pages HTML pages; public/ size: $size."
