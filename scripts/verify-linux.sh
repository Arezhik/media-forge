#!/usr/bin/env bash
# Phase 0 Linux gate for MediaForge and the root umbrella.
# When swift is on PATH, run the same strict test and build commands as CI.
# When swift is absent, print those commands and exit 0.
# This script does not run the three app packages.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v swift >/dev/null 2>&1; then
  cat <<'EOF'
swift is not on PATH.
GitHub Actions Linux (swift:6.2.4) and macOS jobs will run:
  swift test --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
  swift build --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
  swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
EOF
  exit 0
fi

swift test --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift build --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
