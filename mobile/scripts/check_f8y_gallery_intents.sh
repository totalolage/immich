#!/usr/bin/env bash

set -euo pipefail

adb_bin="${ADB:-adb}"
serial="${1:-${ANDROID_SERIAL:-}}"
package_id="${PACKAGE_ID:-dev.f8y.immich}"
adb=("$adb_bin")
[[ -z $serial ]] || adb+=(-s "$serial")

query() {
  local action=$1 mime_type=$2 uri=${3:-}
  local args=(shell cmd package query-activities --brief --components -a "$action" -t "$mime_type")
  [[ -z $uri ]] || args+=(-d "$uri")
  "${adb[@]}" "${args[@]}" | tr -d '\r'
}

require_match() {
  local label=$1 action=$2 mime_type=$3 uri=${4:-} output
  output="$(query "$action" "$mime_type" "$uri")"
  printf '%-24s %s\n' "$label" "$output"
  [[ $output == *"$package_id/"* ]] || return 1
}

require_absent() {
  local label=$1 action=$2 mime_type=$3 uri=${4:-} output
  output="$(query "$action" "$mime_type" "$uri")"
  printf '%-24s %s\n' "$label" "$output"
  [[ $output != *"$package_id/"* ]] || return 1
}

"${adb[@]}" get-state >/dev/null
"${adb[@]}" shell dumpsys package "$package_id" \
  | tr -d '\r' \
  | sed -n -e 's/^[[:space:]]*versionName=/versionName=/p' -e 's/^[[:space:]]*versionCode=/versionCode=/p' \
  | head -2

require_match "BSG discovery" android.intent.action.PICK image/jpeg
require_match "BSG photo review" com.android.camera.action.REVIEW image/jpeg content://media/external/images/media/1
require_match "BSG video review" com.android.camera.action.REVIEW video/mp4 content://media/external/video/media/1
require_match "Existing photo view" android.intent.action.VIEW image/jpeg content://media/external/images/media/1
require_absent "Secure review excluded" android.provider.action.REVIEW_SECURE image/jpeg content://media/external/images/media/1
