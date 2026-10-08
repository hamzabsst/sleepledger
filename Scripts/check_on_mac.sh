#!/bin/sh
set -eu
TASK_PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ "$(uname -s)" != Darwin ]; then
  echo 'This check requires macOS with Xcode and its command-line tools.' >&2
  exit 1
fi
cd "$TASK_PROJECT_DIR/Core"
swift test
cd "$TASK_PROJECT_DIR"
xcodebuild -project SleepLedger.xcodeproj -scheme SleepLedger -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
