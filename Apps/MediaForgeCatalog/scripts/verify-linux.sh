#!/usr/bin/env bash
# Wrapper. The implementation is the repo-root scripts/verify-linux.sh.
# From Apps/MediaForgeCatalog: ./scripts/verify-linux.sh
# is ./scripts/verify-linux.sh mediaforgecatalog at the repo root.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
exec "$REPO/scripts/verify-linux.sh" mediaforgecatalog "$@"
