#!/usr/bin/env bash
# verify-linux.sh: Linux-host verification for the media-forge monorepo.
#
# Usage (from the repo root):
#   scripts/verify-linux.sh                 MediaForge, the root umbrella, then all apps
#   scripts/verify-linux.sh all             same as no arguments
#   scripts/verify-linux.sh package         MediaForge and the root umbrella only
#   scripts/verify-linux.sh <app>           one app: mkvforge, mp4subrip, pgs2srt, or mediaforgecatalog
#
# Apps/<App>/scripts/verify-linux.sh is a wrapper that selects that app and
# forwards every argument here.
#
# Package mode runs the same strict swift test and swift build commands as
# .github/workflows/ci.yml. When swift is not on PATH, it prints those commands
# and exits 0.
#
# An app run regenerates that app's Xcode project with XcodeGen when a binary
# is available (missing xcodegen is not a failure), runs the app's non-Swift
# checks from the app directory, then swift test and swift build. Non-Swift
# checks are Apps/MKVForge/scripts/check-project.sh for MKV Forge, and
# scripts/bump-version.sh <app> --check for every app. When swift is not on
# PATH, the app run prints the swift commands and continues (it does not fail).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

show_help() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  show_help
  exit 0
fi

TARGET="${1:-all}"
if [ "$#" -gt 1 ]; then
  echo "verify-linux: unexpected extra arguments: ${*:2}" >&2
  exit 1
fi

case "$TARGET" in
  all|package|mkvforge|mp4subrip|pgs2srt|mediaforgecatalog) ;;
  *)
    echo "verify-linux: unknown target '$TARGET' (use all, package, mkvforge, mp4subrip, pgs2srt, or mediaforgecatalog)" >&2
    exit 1
    ;;
esac

app_root_for() {
  case "$1" in
    mkvforge) printf '%s\n' "$REPO/Apps/MKVForge" ;;
    mp4subrip) printf '%s\n' "$REPO/Apps/MP4SubRip" ;;
    pgs2srt) printf '%s\n' "$REPO/Apps/PGS2SRT" ;;
    mediaforgecatalog) printf '%s\n' "$REPO/Apps/MediaForgeCatalog" ;;
    *)
      echo "verify-linux: unknown app $1" >&2
      exit 1
      ;;
  esac
}

run_package() {
  (
    cd "$REPO"
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

    echo "verify-linux: MediaForge package tests"
    swift test --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
    echo "verify-linux: MediaForge package build"
    swift build --package-path Packages/MediaForge -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
    echo "verify-linux: root umbrella tests"
    swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
  )
}

verify_app() {
  local app="$1"
  local app_root
  app_root="$(app_root_for "$app")"
  [ -d "$app_root" ] || { echo "verify-linux: missing app directory $app_root" >&2; exit 1; }

  (
    ROOT="$app_root"
    cd "$ROOT"
    echo "verify-linux: $app ($ROOT)"

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

    # Run check-project.sh from the app directory when that app has one.
    # Never run bump-version.sh without --check (that would bump the version).
    if [ -x "$ROOT/scripts/check-project.sh" ]; then
      echo "verify-linux: running scripts/check-project.sh"
      "$ROOT/scripts/check-project.sh"
    fi
    echo "verify-linux: running scripts/bump-version.sh $app --check"
    "$REPO/scripts/bump-version.sh" "$app" --check

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
  )
}

case "$TARGET" in
  package)
    run_package
    ;;
  all)
    run_package
    verify_app mkvforge
    verify_app mp4subrip
    verify_app pgs2srt
    verify_app mediaforgecatalog
    echo "verify-linux: all targets passed"
    ;;
  mkvforge|mp4subrip|pgs2srt|mediaforgecatalog)
    verify_app "$TARGET"
    ;;
esac
