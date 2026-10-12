#!/usr/bin/env bash
# Device helpers for on-device verification (wireless hdc drops now and then).
# Usage: tools/dev.sh <cmd> [args]
#   connect | restart | shot <file> | find <regex> | tap <x> <y> | back | swipe x1 y1 x2 y2
#   press <x> <y> <file.jpeg>   (screenshot taken while the point is held down — checks pressed styles)
set -e
export MSYS_NO_PATHCONV=1
DEV="${SPARK_DEVICE:-172.15.125.54:5555}"
HDC="${HDC:-C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ensure() {
  if ! "$HDC" list targets -v | grep -q "$DEV.*Connected"; then
    "$HDC" tconn "$DEV" > /dev/null
    sleep 1
  fi
}
cmd="$1"; shift || true
ensure
case "$cmd" in
  connect) "$HDC" list targets -v ;;
  restart)
    "$HDC" -t "$DEV" shell aa force-stop com.example.sparkui > /dev/null
    "$HDC" -t "$DEV" shell aa start -a EntryAbility -b com.example.sparkui > /dev/null
    sleep 2 ;;
  shot) rm -f "$1"; devecocli ui screenshot --device "$DEV" --path "$1" > /dev/null 2>&1; ls "$1" ;;
  find)
    tmp="$(mktemp)"; devecocli ui layout --device "$DEV" --format json 2>/dev/null > "$tmp"
    node "$(cygpath -w "$ROOT/tools/ui-find.mjs")" "$1" < "$tmp"; rm -f "$tmp" ;;
  tap) devecocli ui click "$1" "$2" --device "$DEV" > /dev/null 2>&1 ;;
  back) "$HDC" -t "$DEV" shell uitest uiInput keyEvent Back > /dev/null ;;
  swipe) devecocli ui swipe "$1" "$2" "$3" "$4" --speed 1500 --device "$DEV" > /dev/null 2>&1 ;;
  press)
    "$HDC" -t "$DEV" shell "uitest uiInput drag $1 $2 $(( $1 + 4 )) $2 200 & sleep 0.6; snapshot_display -f /data/local/tmp/spark_press.jpeg; wait" > /dev/null 2>&1
    rm -f "$3"; "$HDC" -t "$DEV" file recv /data/local/tmp/spark_press.jpeg "$(cygpath -w "$3")" > /dev/null; ls "$3" ;;
  *) echo "unknown command $cmd"; exit 1 ;;
esac
