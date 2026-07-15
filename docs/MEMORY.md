# Memory budgets

## Targets

| State | RSS target | Notes |
|---|---|---|
| Idle (menu bar only, models unloaded) | **50–80 MB** | Mandatory after XPC phase |
| Active dictation (model warm) | **250–400 MB** | Parakeet may sit near upper bound |
| Fail gate | Active **>500 MB** sustained | Switch to Moonshine Tiny / smaller CoreML |

Phase 1 MVP may miss the idle target (model can stay warm in-process). `IdleUnloadScheduler` (60s) calls `ASREngine.deactivate()` as a soft rehearsal for XPC unload.

## Plugin footprint reporting

Every `PluginManifest.approxActiveMemoryMB` is an **estimate** for Settings / Model Zoo. Update these when Instruments shows real numbers.

| Plugin ID | approxActiveMemoryMB (declared) | Measured RSS delta | Date | Machine |
|---|---|---|---|---|
| `asr.stub` | 5 | _TBD_ | | |
| `asr.parakeet.tdt.v3` | 350 | _TBD_ | | |
| `asr.moonshine` | 120 | stub | | |
| `asr.whispercpp` | 300 | stub | | |
| `vad.energy` | 1 | _TBD_ | | |
| `vad.silero` | 25 | stub | | |
| `wake.openwakeword` | 15 | stub | | |
| `wake.porcupine` | 20 | stub | | |
| `screen.vlm.quantized` | 200 | stub | | |
| `bias.memory` / `bias.sqlite` | 1–2 | _TBD_ | | |

## Instruments checklist

1. Build **Release**: `swift build -c release` (or Xcode Archive).
2. Open **Instruments → Allocations** (or Activity Monitor for coarse RSS).
3. Launch FastFlow; wait **60s** with no dictation and model unloaded → record **Idle RSS**.
4. **Warm Up Model** (Parakeet); wait until ready → record **Warm idle RSS**.
5. Hold hotkey, speak ~10s, release → record **Peak active RSS** during transcribe.
6. Wait for idle unload (60s) → confirm RSS drops toward idle.
7. Paste numbers into the table above; if active >500 MB sustained, prioritize Moonshine.

## Placeholders (fill after first measurement)

- Idle RSS (unloaded): `___ MB`
- Warm idle RSS (Parakeet loaded): `___ MB`
- Peak active RSS: `___ MB`
- macOS / chip: `___`

## Related

Cold-start latency after unload: see [BENCHMARKS.md](BENCHMARKS.md).  
Privacy / sandbox: see [PRIVACY.md](PRIVACY.md).
