# ASR cold-start benchmarks

Cold start after idle unload is the common case once `IdleUnloadScheduler` tears down the model (~60s). If load is slow, the “instant dictation” promise fails.

## Acceptance criteria (gates)

| Metric | Definition | Target |
|---|---|---|
| **Time-to-ready** | `deactivate` → `activate` complete | **≤ 1500 ms** |
| **Time-to-final** | `activate` done → `transcribe` returns (batch) | **≤ 1000 ms** for ~1s audio |
| **End-to-end after idle** | ready + final (no unload) | **≤ 2500 ms** |

Constants live in code: `ColdStartAcceptance` in `Sources/FastFlowPlugins/Benchmark/ColdStartBenchmark.swift`.

Streaming time-to-first-token is **N/A** for Phase 1 batch Parakeet; when streaming engines land, add a `ttft_ms` column.

## Methodology

1. Build Release (or Debug for stub-only).
2. Run `FastFlowBench` (no GUI).
3. **Cold:** force `deactivate()`, then measure `activate` → `transcribe(1s synthetic PCM)` → `deactivate`.
4. **Warm:** model already active; measure `transcribe` only.
5. Record machine: chip, macOS, whether models were already cached.
6. Idle interaction: app’s 60s idle unload is equivalent to the cold path’s explicit `deactivate()`.

Do **not** count first-ever Hugging Face download in the cold-start gate (that is a one-time setup cost). Gate timings assume **models already on disk**.

## How to run

```bash
cd /Users/shrianshjaiswal/FastFlow

# Full Xcode toolchain required on machines where CLT SPM is broken:
#   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Stub-only (always runnable once SPM works):
cp Package.stub.swift Package.swift
swift run FastFlowBench

# Parakeet (default Package.swift) after models cached:
# First download (debug only — needs network in-process):
FASTFLOW_ALLOW_INPROCESS_NETWORK=1 swift run FastFlowBench
# Subsequent cold starts (offline, main-app policy):
swift run FastFlowBench

# Or:
./scripts/run-cold-start-benchmark.sh stub
./scripts/run-cold-start-benchmark.sh parakeet
```

Dictation also logs `load_ms` / `transcribe_ms` / `e2e_ms` to the system log on each utterance.

## Results table (fill in)

| engine | mode | load_ms | transcribe_ms | unload_ms | total_ms | machine | date | notes |
|---|---|---|---|---|---|---|---|---|
| `asr.stub` | cold | _run me_ | | | | | | |
| `asr.stub` | warm | | _run me_ | | | | | |
| `asr.parakeet.tdt.v3` | cold | _TODO_ | _TODO_ | _TODO_ | _TODO_ | | | models cached |
| `asr.parakeet.tdt.v3` | warm | | _TODO_ | | | | | |

### This environment

SPM/`swift build` failed here: Command Line Tools only (PackageDescription link + SDK/compiler mismatch). **Harness is in-repo; numbers not filled.** Re-run on a Mac with full Xcode and paste rows above.

## Pass / fail

- Stub cold ready should be ≪ 1500 ms (sanity).
- Parakeet cold ready must meet ≤1500 ms on M-series with cached CoreML; if not, revisit idle timeout (keep warm longer) or smaller engine (Moonshine) before shipping the unload UX.
