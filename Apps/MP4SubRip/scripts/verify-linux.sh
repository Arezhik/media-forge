#!/usr/bin/env bash
# Wrapper. The implementation is the repo-root scripts/verify-linux.sh.
# From Apps/MP4SubRip: ./scripts/verify-linux.sh
# is ./scripts/verify-linux.sh mp4subrip at the repo root.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
exec "$REPO/scripts/verify-linux.sh" mp4subrip "$@"
