#!/usr/bin/env bash
set -Eeuo pipefail

DEVICE="${DVD_DEVICE:-/dev/sr0}"
OUTPUT_DIR="${OUTPUT_DIR:-/media}"
WORK_DIR="${WORK_DIR:-/work}"
POLL_SECONDS="${POLL_SECONDS:-5}"
VIDEO_ENCODER="${VIDEO_ENCODER:-h264_vaapi}"
VAAPI_DEVICE="${VAAPI_DEVICE:-/dev/dri/renderD128}"
VAAPI_QP="${VAAPI_QP:-22}"
LOG_DIR="${LOG_DIR:-/work/logs}"

mkdir -p "$OUTPUT_DIR" "$WORK_DIR" "$LOG_DIR"

log() { printf '[%s] %s\n' "$(date -Is)" "$*"; }

safe_name() {
  local s="$1"
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g')"
  [[ -n "$s" ]] || s="dvd"
  printf '%s' "$s"
}

# dvd_drive_status exit code 4 means media is present and the drive is ready.
disc_ready() {
  local status=0
  dvd_drive_status "$DEVICE" >/dev/null 2>&1 || status=$?
  [[ "$status" -eq 4 ]]
}

log "DVD auto-ripper starting; device=$DEVICE output=$OUTPUT_DIR encoder=$VIDEO_ENCODER"

if [[ "$VIDEO_ENCODER" == "h264_vaapi" ]]; then
  if [[ ! -e "$VAAPI_DEVICE" ]]; then
    log "ERROR: VA-API device $VAAPI_DEVICE is missing. Check host /dev/dri and Podman --device mapping."
    exit 2
  fi
  if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q 'h264_vaapi'; then
    log "ERROR: this FFmpeg build does not expose h264_vaapi."
    exit 2
  fi
fi

while true; do
  if ! disc_ready; then
    sleep "$POLL_SECONDS"
    continue
  fi

  # Wait for the drive to finish spinning up / probing.
  sleep 3
  if ! disc_ready; then continue; fi

  stamp="$(date +%Y%m%d-%H%M%S)"
  joblog="$LOG_DIR/$stamp.log"
  exec 9>>"$joblog"
  log "Media detected; probing for DVD-Video."

  if ! dvd_info --id "$DEVICE" >"$WORK_DIR/disc-id.txt" 2>>"$joblog"; then
    log "Media is present but dvd_info could not identify DVD-Video; ignoring until media changes."
    while disc_ready; do sleep "$POLL_SECONDS"; done
    continue
  fi

  disc_id="$(tr -cd '[:alnum:]' < "$WORK_DIR/disc-id.txt" | head -c 32)"
  [[ -n "$disc_id" ]] || disc_id="unknown-$stamp"
  volume="$(dvd_info --volume "$DEVICE" 2>>"$joblog" || true)"
  volume="$(printf '%s' "$volume" | head -n 1 | tr -d '\r')"
  [[ -n "$volume" ]] || volume="DVD-$disc_id"
  folder="$(safe_name "$volume")"
  dest="$OUTPUT_DIR/$folder"

  # Save technical DVD metadata for later inspection. Kodi should do online artwork
  # scraping once the folder/file is named as Movie Title (Year).
  if [[ -e "$dest/movie.mkv" ]]; then
    log "Output already exists at $dest/movie.mkv; skipping duplicate disc ID $disc_id."
  else
    mkdir -p "$dest"
    dvd_info --json "$DEVICE" > "$dest/disc-info.json" 2>>"$joblog" || true
    printf '{"disc_id":"%s","volume":"%s","device":"%s","detected_at":"%s"}\n' \
      "$disc_id" "${volume//\"/\\\"}" "$DEVICE" "$(date -Is)" > "$dest/rip-info.json"

    tmp="$dest/movie.partial.mkv"
    rm -f "$tmp"
    log "DVD-Video detected (ID=$disc_id, volume=$volume); starting rip/encode."
    if dvd_rip-upstream -i "$DEVICE" -o "$tmp" -v "$VIDEO_ENCODER" -y -z >>"$joblog" 2>&1; then
      if [[ -s "$tmp" ]] && ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$tmp" >/dev/null 2>&1; then
        mv "$tmp" "$dest/movie.mkv"
        log "Completed: $dest/movie.mkv"
      else
        log "ERROR: encoder returned success but output did not validate; retaining partial output for diagnosis."
      fi
    else
      log "ERROR: ripping/encoding failed. See $joblog"
    fi
  fi

  # Do not process the same inserted disc repeatedly; wait for eject/removal.
  log "Waiting for disc removal/eject."
  while disc_ready; do sleep "$POLL_SECONDS"; done
  log "Drive is empty; ready for next disc."
done
