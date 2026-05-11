#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
XCODE_PROJECT="$PROJECT_DIR/Sudoku.xcodeproj"
SCHEME="Sudoku"
BUNDLE_ID="com.tomhubert.Sudoku"
DESTINATION_NAME="${SUDOKU_HINT_DEVICE:-iPhone 17}"

TECHNIQUES=(
  "Full house"
  "Naked single"
  "Hidden single"
  "Locked candidates"
  "Naked pair"
  "Hidden pair"
  "Naked triple"
  "Hidden triple"
  "Naked quadruple"
  "Hidden quadruple"
  "X-Wing"
  "Swordfish"
  "Jellyfish"
  "Skyscraper"
  "2-String Kite"
  "XY-Wing"
  "XYZ-Wing"
  "W-Wing"
  "Simple Colors"
  "Finned X-Wing"
  "Finned Swordfish"
  "Finned Jellyfish"
  "Unique Rectangle Type 1"
  "BUG+1"
  "X-Chain"
  "XY-Chain"
  "AIC"
)

run_with_timeout() {
  local limit="$1"
  shift

  "$@" &
  local command_pid=$!

  (
    sleep "$limit"
    if kill "$command_pid" 2>/dev/null; then
      echo "Timed out after ${limit}s: $*" >&2
    fi
  ) &
  local watcher_pid=$!

  if wait "$command_pid" 2>/dev/null; then
    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true
    return 0
  fi

  local status=$?
  kill "$watcher_pid" 2>/dev/null || true
  wait "$watcher_pid" 2>/dev/null || true
  return "$status"
}

usage() {
  echo "Usage: $0 <index>"
  echo
  echo "Techniques:"
  for index in "${!TECHNIQUES[@]}"; do
    printf "  %2d  %s\n" "$index" "${TECHNIQUES[$index]}"
  done
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

INDEX="$1"
if ! [[ "$INDEX" =~ ^[0-9]+$ ]] || (( INDEX < 0 || INDEX >= ${#TECHNIQUES[@]} )); then
  usage
  exit 1
fi

if [[ "$DESTINATION_NAME" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
  DEVICE="$DESTINATION_NAME"
else
  DEVICE="$(
    xcrun simctl list devices available |
      awk -v name="$DESTINATION_NAME" 'index($0, name) > 0 && $0 !~ /unavailable/ {
        match($0, /\([0-9A-F-]+\)/)
        if (RSTART > 0) {
          print substr($0, RSTART + 1, RLENGTH - 2)
          exit
        }
      }'
  )"
fi

if [[ -z "$DEVICE" ]]; then
  echo "No available simulator named '$DESTINATION_NAME'."
  exit 1
fi

cd "$PROJECT_DIR"
echo "Project: $PROJECT_DIR"
echo "Simulator: $DESTINATION_NAME ($DEVICE)"
echo "Technique: ${TECHNIQUES[$INDEX]} ($INDEX)"

echo "Reading build settings..."
BUILD_SETTINGS_FILE="$(mktemp)"
if ! run_with_timeout 30 xcodebuild -project "$XCODE_PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -showBuildSettings >"$BUILD_SETTINGS_FILE"; then
  echo "Xcode did not return build settings. Restart Simulator/Xcode and retry." >&2
  rm -f "$BUILD_SETTINGS_FILE"
  exit 1
fi
BUILD_SETTINGS="$(cat "$BUILD_SETTINGS_FILE")"
rm -f "$BUILD_SETTINGS_FILE"

TARGET_BUILD_DIR="$(awk -F'= ' '/TARGET_BUILD_DIR =/ { print $2; exit }' <<<"$BUILD_SETTINGS")"
WRAPPER_NAME="$(awk -F'= ' '/WRAPPER_NAME =/ { print $2; exit }' <<<"$BUILD_SETTINGS")"
APP_PATH="$TARGET_BUILD_DIR/$WRAPPER_NAME"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App is not built yet. Building..."
  xcodebuild build -project "$XCODE_PROJECT" -scheme "$SCHEME" -destination "platform=iOS Simulator,id=$DEVICE"
fi

echo "Opening Simulator..."
open -a Simulator
xcrun simctl boot "$DEVICE" 2>/dev/null || true
echo "Waiting for simulator boot..."
run_with_timeout 25 xcrun simctl bootstatus "$DEVICE" -b >/dev/null
echo "Installing app..."
if ! run_with_timeout 25 xcrun simctl install "$DEVICE" "$APP_PATH"; then
  echo "Install did not finish. Trying to launch the app already installed on the simulator..." >&2
fi
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true

echo "Launching ${TECHNIQUES[$INDEX]} ($INDEX)"
if ! run_with_timeout 15 xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -HintCatalogIndex "$INDEX"; then
  echo "Launch did not finish. CoreSimulator is stuck; run: killall Simulator; killall -9 com.apple.CoreSimulator.CoreSimulatorService" >&2
  exit 1
fi
