#!/usr/bin/env bash
# Wrapper. The implementation is the repo-root scripts/bump-version.sh.
# From Apps/MKVForge: scripts/bump-version.sh <args...>
# is scripts/bump-version.sh mkvforge <args...> at the repo root.
set -eu
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
exec "$REPO/scripts/bump-version.sh" mkvforge "$@"
