#!/usr/bin/env bash
# Prepare bundle media for the web, preserving originals in .archive.
# Usage: optimize-media.sh [--dry-run] [path ...]
# Requirements: ffmpeg and ffprobe (brew install ffmpeg).
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"
# shellcheck disable=SC2154 # Defined by common.sh.
cd -- "$repo_root"

dry_run=0
paths=()
while (($#)); do
  case "$1" in
    -h|--help) printf 'Usage: optimize-media.sh [--dry-run] [path ...]\nOptimize images and MP4s under content, or under the supplied paths.\n'; exit 0 ;;
    --dry-run) dry_run=1 ;;
    --) shift; while (($#)); do paths+=("$1"); shift; done; break ;;
    -*) die "Unknown option: $1" ;;
    *) paths+=("$1") ;;
  esac
  shift
done
if ((${#paths[@]} == 0)); then
  if [[ ! -d content ]]; then ok 'Nothing to do: content/ does not exist.'; exit 0; fi
  paths=(content)
fi
require_cmd ffmpeg ffmpeg
require_cmd ffprobe ffmpeg
require_cmd perl perl

processed=0
before_total=0
after_total=0
stamp="$(date +%Y%m%d-%H%M%S)-$$"

# Ignore container and codec bookkeeping tags that ffmpeg itself must write.
has_metadata() {
  local tags
  tags="$(ffprobe -v error -show_entries format_tags:stream_tags -of default=noprint_wrappers=1 "$1")" || die "Cannot inspect metadata: $2"
  printf '%s\n' "$tags" | grep -Eiv '^(TAG:)?(major_brand|minor_version|compatible_brands|encoder|handler_name|vendor_id|language)=|^$' | grep -q .
}
size_of() { wc -c < "$1" | tr -d ' '; }

# Read MP4 box headers, not arbitrary byte matches inside media data.
has_faststart() {
  perl -e '
    use strict; use warnings;
    open my $fh, "<:raw", $ARGV[0] or exit 1;
    while (read($fh, my $header, 8) == 8) {
      my ($size, $type) = unpack("Na4", $header);
      exit 0 if $type eq "moov";
      exit 1 if $type eq "mdat" || $size == 0;
      my $header_size = 8;
      if ($size == 1) {
        read($fh, my $extended, 8) == 8 or exit 1;
        $size = unpack("Q>", $extended); $header_size = 16;
      }
      $size >= $header_size or exit 1;
      seek($fh, $size - $header_size, 1) or exit 1;
    }
    exit 1;
  ' "$1"
}

video_compliant() {
  local file="$1" relative="$2" height="$3" video audio
  video="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,pix_fmt -of csv=p=0 "$file")" || die "Cannot inspect video: $relative"
  audio="$(ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 "$file")" || die "Cannot inspect audio: $relative"
  [[ "$video" == h264,yuv420p && "$height" -le 1080 ]] || return 1
  if [[ -n "$audio" ]] && printf '%s\n' "$audio" | grep -qvx 'aac'; then return 1; fi
  has_faststart "$file" || return 1
  ! has_metadata "$file" "$relative"
}

# Temp output is built beside the source; archive before replacing it.
replace_original() {
  local source="$1" temp="$2" relative="$3" archive
  archive="$repo_root/.archive/media-originals/$stamp/$relative"
  mkdir -p -- "$(dirname -- "$archive")"
  [[ ! -e "$archive" ]] || die "Archive already exists: $relative"
  mv -- "$source" "$archive"
  if ! mv -- "$temp" "$source"; then
    mv -- "$archive" "$source" || warn "Restore manually from .archive/media-originals/$stamp/$relative"
    die "Could not replace $relative"
  fi
}

process_file() {
  local file="$1" relative="${1#"$repo_root"/}" ext dims width height bytes temp new_size poster
  ext="${file##*.}"; ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  dims="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$file")" || die "Cannot inspect: $relative"
  width="${dims%%x*}"; height="${dims#*x}"
  [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || die "Invalid dimensions: $relative"
  bytes="$(size_of "$file")"
  if [[ "$ext" == mp4 ]]; then
    if ! video_compliant "$file" "$relative" "$height"; then
      info "Video: $relative ($bytes bytes before)"
      if ((dry_run)); then info '  Would encode video.'; else
        temp="$(mktemp "${file%/*}/.optimize.XXXXXX.mp4")"
        ffmpeg -nostdin -v error -y -i "$file" -map_metadata -1 -map_metadata:s -1 -vf "scale=-2:'min(1080,ih)'" -c:v libx264 -crf 26 -preset slow -c:a aac -b:a 128k -movflags +faststart -pix_fmt yuv420p "$temp" || die "Encoding failed; temporary file retained: $relative"
        new_size="$(size_of "$temp")"
        if ((new_size > 45000000)); then
          warn "Video exceeds 45 MB; retrying at CRF 30: $relative"
          ffmpeg -nostdin -v error -y -i "$file" -map_metadata -1 -map_metadata:s -1 -vf "scale=-2:'min(1080,ih)'" -c:v libx264 -crf 30 -preset slow -c:a aac -b:a 128k -movflags +faststart -pix_fmt yuv420p "$temp" || die "Encoding failed: $relative"
          new_size="$(size_of "$temp")"
        fi
        ((new_size < 50000000)) || die "Video remains at least 50 MB; original unchanged: $relative"
        replace_original "$file" "$temp" "$relative"
        ((new_size <= 20000000)) || warn "Video exceeds 20 MB target: $relative ($new_size bytes)"
        info "  $bytes -> $new_size bytes"
        processed=$((processed + 1)); before_total=$((before_total + bytes)); after_total=$((after_total + new_size))
      fi
    fi
    poster="${file%/*}/poster.jpg"
    if [[ ! -e "$poster" && "${file##*/}" == video.mp4 ]]; then
      info "Poster: ${relative%/*}/poster.jpg"
      if ((dry_run)); then info '  Would create poster.'; else
        temp="$(mktemp "${file%/*}/.poster.XXXXXX.jpg")"
        ffmpeg -nostdin -v error -y -ss 1 -i "$file" -frames:v 1 -vf "scale='min(1920,iw)':'min(1920,ih)':force_original_aspect_ratio=decrease" -map_metadata -1 -q:v 3 "$temp" || die "Poster extraction failed: $relative"
        mv -- "$temp" "$poster"
        new_size="$(size_of "$poster")"; processed=$((processed + 1)); after_total=$((after_total + new_size))
      fi
    fi
  elif ((width > 3000 || height > 3000)) || has_metadata "$file" "$relative"; then
    info "Image: $relative ($bytes bytes before)"
    if ((dry_run)); then info '  Would optimize image.'; else
      temp="$(mktemp "${file%/*}/.optimize.XXXXXX.$ext")"
      ffmpeg -nostdin -v error -y -i "$file" -frames:v 1 -vf "scale='min(3000,iw)':'min(3000,ih)':force_original_aspect_ratio=decrease" -map_metadata -1 -q:v 3 "$temp" || die "Image encoding failed: $relative"
      new_size="$(size_of "$temp")"
      replace_original "$file" "$temp" "$relative"
      info "  $bytes -> $new_size bytes"
      processed=$((processed + 1)); before_total=$((before_total + bytes)); after_total=$((after_total + new_size))
    fi
  fi
}

# Restrict traversal to this project, never original sources or the archive of originals.
for path in "${paths[@]}"; do
  [[ -e "$path" ]] || die "Path not found: $path"
  if [[ -d "$path" ]]; then resolved="$(cd -- "$path" && pwd -P)"; else resolved="$(cd -- "$(dirname -- "$path")" && pwd -P)/$(basename -- "$path")"; fi
  case "$resolved" in
    "$repo_root/content"|"$repo_root/content/"*|"$repo_root/.archive/test-scratch/media"|"$repo_root/.archive/test-scratch/media/"*) ;;
    *) die 'Targets must be inside content/ or .archive/test-scratch/media/.' ;;
  esac
  while IFS= read -r -d '' file; do process_file "$file"; done < <(find "$resolved" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.mp4' \) -print0)
done
if ((processed == 0 && ! dry_run)); then ok 'Already optimized; no changes.'; fi
ok "Summary: $processed files processed; $before_total -> $after_total bytes."
