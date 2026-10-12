#!/usr/bin/env bash
# Screenshot gallery pages by sidebar title: tools/shoot-pages.sh <prefix> "Title 1" "Title 2" ...
prefix="$1"; shift
cd "$(dirname "$0")/.."
for title in "$@"; do
  coords=""
  for attempt in 1 2 3 4 5 6; do
    coords=$(tools/dev.sh find "^${title}\$" | head -1 | cut -f1)
    x=${coords%% *}
    if [ -n "$coords" ] && [ "$x" -lt 600 ]; then break; fi
    coords=""
    if [ $attempt -le 3 ]; then tools/dev.sh swipe 300 1500 300 600; else tools/dev.sh swipe 300 600 300 1500; fi
    sleep 0.8
  done
  if [ -z "$coords" ]; then echo "not found: $title"; continue; fi
  tools/dev.sh tap $coords; sleep 1.6
  slug=$(echo "$title" | tr 'A-Z &' 'a-z--' | tr -s '-')
  tools/dev.sh shot "docs/screenshots/${prefix}-${slug}.png" > /dev/null && echo "shot $title"
done
