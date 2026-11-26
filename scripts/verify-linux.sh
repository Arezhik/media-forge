#!/usr/bin/env bash
# Phase 0 Linux gate. This VM often has no Swift toolchain.
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
