#!/usr/bin/env bash
# Run FastFlowBench cold-start timings (no GUI).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
MODE="${1:-stub}"

if [[ "$MODE" == "stub" ]]; then
  cp Package.stub.swift Package.swift
  echo "Using Package.stub.swift (no FluidAudio)"
elif [[ "$MODE" == "parakeet" ]]; then
  # Ensure default Package.swift (caller should not have left stub in place).
  if ! grep -q FluidAudio Package.swift; then
    echo "Restoring Package.swift with FluidAudio from git or template…"
    git checkout -- Package.swift 2>/dev/null || true
  fi
  echo "Using FluidAudio Package.swift"
  export FASTFLOW_ALLOW_INPROCESS_NETWORK="${FASTFLOW_ALLOW_INPROCESS_NETWORK:-0}"
else
  echo "Usage: $0 [stub|parakeet]"
  exit 2
fi

echo "=== FastFlow cold-start benchmark ($MODE) ==="
echo "See docs/BENCHMARKS.md for acceptance gates."
swift run FastFlowBench
