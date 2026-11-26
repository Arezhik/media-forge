#!/usr/bin/env bash
# Wrapper. The implementation is the repo-root scripts/bump-version.sh.
# From Apps/PGS2SRT: scripts/bump-version.sh <args...>
# is scripts/bump-version.sh pgs2srt <args...> at the repo root.
# PGS2SRT has no CHANGELOG.md. The root script treats that file as optional.
set -eu
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
exec "$REPO/scripts/bump-version.sh" pgs2srt "$@"
