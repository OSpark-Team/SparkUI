#!/usr/bin/env bash
# Run Hypium local unit tests of a module (default: library) and print the summary.
# Usage: tools/unit-test.sh [module]
set -e
MODULE="${1:-library}"
STUDIO="${DEVECO_STUDIO_HOME:-C:/Program Files/Huawei/DevEco Studio}"
export DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-$STUDIO/sdk}"
cd "$(dirname "$0")/.."
rm -f "$MODULE/.test/default/intermediates/test/coverage_data/test_result.txt"
"$STUDIO/tools/node/node.exe" "$STUDIO/tools/hvigor/bin/hvigorw.js" --mode module \
  -p "module=$MODULE@default" -p product=default test --no-daemon > /dev/null 2>&1 || true
RESULT="$MODULE/.test/default/intermediates/test/coverage_data/test_result.txt"
if [ ! -f "$RESULT" ] || [ "$(find "$RESULT" -mmin -10 | wc -l)" = "0" ]; then
  echo "unit tests did not run (compile error?) — re-run hvigor test without output redirection to see it"
  exit 1
fi
grep -B1 -A3 "^Error in" "$RESULT" || true
tail -1 "$RESULT"
