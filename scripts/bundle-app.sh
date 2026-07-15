#!/usr/bin/env bash
# Deprecated wrapper — use make-slim-release.sh for distributable zips.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/scripts/make-slim-release.sh" "${1:-debug}"
