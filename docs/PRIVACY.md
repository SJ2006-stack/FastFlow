# Privacy boundaries (honest)

This document separates **OS-enforced** controls from **software policy** in FastFlow. Do not treat software policy as a security boundary against a malicious or buggy in-process plug-in.

## OS-enforced today

| Control | Mechanism | What it actually guarantees |
|---|---|---|
| Microphone access | TCC (`NSMicrophoneUsageDescription` + user grant) | The process cannot read the mic until the user allows this app (or a helper with its own TCC identity). |
| Screen capture (when enabled) | TCC Screen Recording | Same process-level gate for ScreenCaptureKit / CGWindow APIs. |
| Accessibility / input monitoring | TCC | Required for global hotkey and synthetic paste; user-visible in System Settings. |
| Outbound network (ship path) | **App Sandbox** without `com.apple.security.network.client` on the main app (`entitlements/FastFlow.entitlements`) | Code in the **main** process cannot open client sockets, even if a plug-in sets `requiresNetwork = false`. |

Networked work is intended only in a helper signed with `entitlements/FastFlowNetworkPluginHost.entitlements` (Phase 2 XPC; Phase 1 has the policy + stub host + entitlement files).

**Debug builds** may use `entitlements/FastFlow.debug.entitlements` (sandbox off) so PTT + first-run downloads still work. That profile does **not** provide OS network isolation.

## Software policy only (not OS guarantees)

These are core conventions and can be bypassed by a compromised or buggy plug-in **loaded in the same process**:

| Policy | Where | Limit |
|---|---|---|
| `requiresNetwork` on manifests | `PluginManifest` | **Advisory for UI warnings.** Enforcement for loading is `PluginCapabilityEnforcer` + sandbox entitlements, not the flag alone. |
| Refuse networked plug-ins in main | `PluginCapabilityEnforcer` | In-process check; a malicious plug-in already executing in main could still attempt syscalls — **sandbox** is what stops sockets. |
| Idle unload of models | `IdleUnloadScheduler` | RAM hygiene; not a privacy boundary. |
| Privacy indicator (mic/screen) | `PrivacyIndicator` | UX; plug-ins are not supposed to suppress it, but in-process code could ignore conventions. |
| Raw audio retention | `RawMediaRetentionPolicy` | Core discards utterance PCM after paste; an in-process ASR plug-in could copy samples before return. |
| Raw frame retention | `RawMediaRetentionPolicy` + `ScreenContextParser` | **See screen capture below.** |

## Screen capture — current / Phase 1–3 boundary

**Today:** `ScreenContextParser` is a stub. No ScreenCaptureKit pipeline ships yet.

**Planned in-process design (unless upgraded):** core captures a frame → passes `CapturedFrame` (including pixel buffers) into a plug-in in the **same process** → expects structured `ScreenContext` back → core drops the frame.

### What that does *not* guarantee

- A buggy or malicious `ScreenContextParser` **can retain pixel data** (copy to memory, write to disk if sandbox allows file access, etc.).
- Software “discard after parse” is a **convention**, not kernel enforcement.
- TCC Screen Recording only answers “may this app capture?” — not “may this plug-in keep the bitmap?”

### What would make screen capture closer to OS-enforced

1. Capture **and** parse inside a dedicated XPC service.
2. Return **only** `ScreenContext` (structured fields) over XPC — **no raw-frame return API**.
3. Sign that service with minimal entitlements; no general file write; short-lived memory; audit logging optional.
4. Main app never receives `CapturedFrame` bytes.

Until that exists, marketing or docs must not claim “OS-enforced privacy for screen contents against plug-ins.”

## Text insertion / focus

Accessibility lets FastFlow **read focus** and **synthesize paste**. TCC gates whether that is allowed — not whether the chosen field is the one the user meant.

**Software policy:** `InsertionResolver` + confirmation UI (`docs/INSERTION.md`) refuse auto-insert when focus is ambiguous. That is not OS enforcement; a buggy strategy could still call paste APIs. Core keeps resolution non-pluggable for that reason.

## Threat model (short)

| Adversary | Mitigated by |
|---|---|
| Random website / other apps reading mic | TCC + no always-on mic without PTT |
| Plug-in that lies `requiresNetwork=false` and phones home | Main-app **sandbox without network** (ship entitlement) |
| Plug-in that keeps screen pixels | **Not mitigated in-process** — needs XPC parse-only boundary |
| Plug-in that keeps audio samples | **Not fully mitigated in-process** — prefer engine in XPC with PCM streaming and no persistence API |

## Related files

- `entitlements/FastFlow.entitlements` — sandboxed main, no network
- `entitlements/FastFlowNetworkPluginHost.entitlements` — networked helper only
- `entitlements/FastFlow.debug.entitlements` — local MVP, sandbox off
- `Sources/FastFlowPlugins/Registry/PluginCapabilityEnforcer.swift`
- `docs/ARCHITECTURE.md`
