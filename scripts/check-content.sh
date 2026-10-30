#!/usr/bin/env bash
# Validate portfolio sources. Usage: check-content.sh [--strict].
# Requirements: awk, Ruby (included on macOS). CONTENT_DIR overrides content/ for fixtures.
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"
strict=0
while (($#)); do
  case "$1" in -h|--help) printf 'Usage: check-content.sh [--strict]\nWarn about incomplete fields; --strict fails on TODOs.\n'; exit 0 ;; --strict) strict=1 ;; *) die "Unknown argument: $1" ;; esac
  shift
done
require_cmd ruby ruby
require_cmd awk gawk
content="${CONTENT_DIR:-$repo_root/content}"
errors=0; warnings=0; todos=0
error() { fail "$1"; errors=$((errors + 1)); }
warning() { warn "$1"; warnings=$((warnings + 1)); }
todo() { warning "$1"; todos=$((todos + 1)); }
# Read only the YAML front matter, removing simple quotes and inline comments.
field() {
  awk -v key="$2" 'NR==1 { if ($0 != "---") exit; next } /^---[[:space:]]*$/ { exit } $0 ~ "^" key ":[[:space:]]*" { sub("^[^:]*:[[:space:]]*", ""); sub(/[[:space:]]+#.*/, ""); gsub(/^[[:space:]\"\047]+|[[:space:]\"\047]+$/, ""); print; exit }' "$1"
}
front_valid() {
  # Awk extracts only front matter; Ruby catches malformed YAML before Hugo does.
  awk 'NR==1 {if ($0 != "---") exit 1; next} /^---[[:space:]]*$/ {found=1; exit} {print} END {if (!found) exit 1}' "$1" |
    ruby -ryaml -e 'value = YAML.safe_load(STDIN.read); exit(value.is_a?(Hash) ? 0 : 1)' >/dev/null 2>&1
}
[[ -d "$content/works" ]] || die 'Missing content/works directory.'
for category in paintings-drawings multimedia digital-graphics; do
  dir="$content/works/$category"; count=0; before=$warnings
  if [[ ! -f "$dir/_index.md" ]]; then error "$category: missing category index"; continue; fi
  if ! front_valid "$dir/_index.md"; then error "$category: invalid front matter"; continue; fi
  cover="$(field "$dir/_index.md" cover)"
  if [[ ! "$cover" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ || ! -f "$dir/$cover/index.md" ]]; then error "$category: invalid cover"; fi
  for bundle in "$dir"/*/; do
    [[ -d "$bundle" ]] || continue
    slug="$(basename "$bundle")"; count=$((count + 1))
    [[ "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || error "$category/$slug: invalid bundle name"
    index="${bundle}index.md"
    if [[ ! -f "$index" ]]; then error "$category/$slug: missing index.md"; continue; fi
    if ! front_valid "$index"; then error "$category/$slug: invalid front matter"; continue; fi
    for key in title weight; do [[ -n "$(field "$index" "$key")" ]] || error "$category/$slug: missing $key"; done
    for key in year medium dimensions; do [[ -n "$(field "$index" "$key")" ]] || todo "$category/$slug: missing $key"; done
    if ! awk 'BEGIN{n=0} /^---[[:space:]]*$/ {n++; next} n>=2 && $0 !~ /^[[:space:]]*(#.*)?$/ {found=1} END{exit !found}' "$index"; then todo "$category/$slug: missing description"; fi
    media=0
    for file in "${bundle}image.jpg" "${bundle}image.jpeg" "${bundle}image.png" "${bundle}image.webp" "${bundle}video.mp4"; do [[ ! -f "$file" ]] || media=$((media + 1)); done
    ((media == 1)) || error "$category/$slug: expected exactly one image or video"
    if [[ -f "${bundle}video.mp4" && ! -f "${bundle}poster.jpg" ]]; then error "$category/$slug: missing poster; run optimize-media.sh"; fi
    while IFS= read -r -d '' file; do
      name="$(basename "$file")"
      [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*(\.[a-z0-9]+)?$ ]] || error "$category/$slug: invalid filename $name"
      bytes="$(wc -c < "$file" | tr -d ' ')"
      if ((bytes >= 100000000)); then error "$category/$slug/$name: at least 100 MB"; elif ((bytes >= 50000000)); then warning "$category/$slug/$name: at least 50 MB; do not commit"; fi
    done < <(find "$bundle" -type f -print0)
    # Standard missing-field markers are already counted; report other TODOs separately.
    while IFS= read -r marker; do
      [[ -n "$marker" ]] || continue
      todo "$category/$slug: $marker"
    done < <(grep -i 'TODO' "$index" | grep -Eiv '^[[:space:]]*(year|medium|dimensions):[[:space:]]*(""|\047\047)?[[:space:]]*#[[:space:]]*TODO(:[[:space:]]*(year|medium|dimensions))?[[:space:]]*$|^[[:space:]]*#[[:space:]]*TODO:[[:space:]]*description[[:space:]]*$' || true)
  done
  printf '%-22s %3s works  %3s warnings\n' "$category" "$count" "$((warnings - before))"
done
[[ -f "$repo_root/static/ohyun-kwon-resume.pdf" ]] || error 'Missing static/ohyun-kwon-resume.pdf'
# Ruby ships with macOS and validates YAML without adding a project dependency.
if [[ ! -f "$repo_root/data/ec.yaml" ]] || ! ruby -ryaml -e 'YAML.load_file(ARGV.fetch(0))' "$repo_root/data/ec.yaml" >/dev/null 2>&1; then error 'Missing or invalid data/ec.yaml'; fi
about="$content/about/index.md"
if [[ ! -f "$about" ]]; then error 'Missing about/index.md'; elif ! front_valid "$about"; then error 'About: invalid front matter'; else
  profile="$(field "$about" profile_work)"
  if [[ ! "$profile" =~ ^[a-z0-9-]+/[a-z0-9-]+$ ]]; then error 'Invalid About profile_work'; else
    found=0; for file in "$content/works/$profile"/image.{jpg,jpeg,png,webp} "$content/works/$profile/poster.jpg"; do [[ ! -f "$file" ]] || found=1; done
    ((found)) || error 'About profile image does not resolve'
  fi
fi
printf 'TODO warnings: %s\n' "$todos"
printf 'Summary: %s errors, %s warnings\n' "$errors" "$warnings"
if ((errors || (strict && todos))); then exit 1; fi
ok 'Content checks passed.'
