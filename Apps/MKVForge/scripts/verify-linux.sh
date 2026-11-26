#!/usr/bin/env bash
# verify-linux.sh: Linux-host verification for this repo.
# Always regenerate the Xcode project with XcodeGen when a project.yml exists
# and an xcodegen binary is available. Then run this repo's existing non-Swift
# check scripts. When swift is on PATH, also run swift test and swift build
# with the same strict flags as CI. When swift is absent, print those commands
# and continue (do not fail).
set -euo pipefail

# App root is the parent of this script (Apps/MKVForge in the monorepo).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEFAULT_XCODEGEN="/workspace/macos-dev-test/projects/mkv-forge/icon/tools/XcodeGen-2.48.0/.build/x86_64-unknown-linux-gnu/release/xcodegen"

# Honor XCODEGEN when it is set and executable. Otherwise use xcodegen on PATH,
# then the default Linux binary. Missing xcodegen is not a failure: GitHub
# Actions Linux containers do not have this binary.
XCODEGEN_BIN=""
if [ -n "${XCODEGEN:-}" ] && [ -x "${XCODEGEN}" ]; then
  XCODEGEN_BIN="$XCODEGEN"
elif command -v xcodegen >/dev/null 2>&1; then
  XCODEGEN_BIN="$(command -v xcodegen)"
elif [ -x "$DEFAULT_XCODEGEN" ]; then
  XCODEGEN_BIN="$DEFAULT_XCODEGEN"
fi

SPEC=""
if [ -f "$ROOT/App/project.yml" ]; then
  SPEC="$ROOT/App/project.yml"
elif [ -f "$ROOT/project.yml" ]; then
  SPEC="$ROOT/project.yml"
fi

if [ -n "$SPEC" ]; then
  if [ -n "$XCODEGEN_BIN" ]; then
    echo "verify-linux: generating Xcode project from $SPEC"
    SPEC_DIR="$(cd "$(dirname "$SPEC")" && pwd)"
    (
      cd "$SPEC_DIR"
      "$XCODEGEN_BIN" generate --spec "$SPEC"
    )
  else
    echo "verify-linux: xcodegen not found; skipping XcodeGen." >&2
    echo "verify-linux: set XCODEGEN to an executable binary, or install xcodegen on PATH." >&2
    echo "verify-linux: GitHub Actions Linux containers do not have xcodegen; continuing." >&2
  fi
else
  echo "verify-linux: no project.yml found; skipping XcodeGen"
fi

ran_any=0
# Run existing check scripts exactly as intended. Never run bump-version.sh
# without --check (that would bump the version). Skip this script itself.
if [ -x "$ROOT/scripts/check-project.sh" ]; then
  echo "verify-linux: running scripts/check-project.sh"
  "$ROOT/scripts/check-project.sh"
  ran_any=1
fi
if [ -x "$ROOT/scripts/bump-version.sh" ]; then
  echo "verify-linux: running scripts/bump-version.sh --check"
  "$ROOT/scripts/bump-version.sh" --check
  ran_any=1
fi

if [ "$ran_any" -eq 0 ]; then
  echo "verify-linux: no existing non-Swift check scripts in scripts/"
fi

if command -v swift >/dev/null 2>&1; then
  echo "verify-linux: running swift test"
  swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
  echo "verify-linux: running swift build"
  swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
else
  cat <<'EOF'
verify-linux: swift is not on PATH.
GitHub Actions will run these commands from this app directory:
  swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
  swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
EOF
fi

echo "verify-linux: all checks passed"
