#!/usr/bin/env bash
# Wrapper. The implementation is the repo-root scripts/verify-linux.sh.
# From Apps/MKVForge: ./scripts/verify-linux.sh
# is ./scripts/verify-linux.sh mkvforge at the repo root.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
exec "$REPO/scripts/verify-linux.sh" mkvforge "$@"
