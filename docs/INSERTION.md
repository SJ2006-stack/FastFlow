# Text insertion

FastFlow inserts transcripts only when focus is **verified**. Ambiguity always surfaces a confirmation panel — never a silent best-effort paste into whatever is focused.

## Trigger context

| Trigger | Confidence | Why |
|---|---|---|
| Hotkey | High | Hands were at the keyboard; user is engaged with the focused app |
| Wake word | Low | Hands-free; focus may be stale or non-text |

`DictationSessionContext` carries `trigger` + `initialFocusSnapshot` (Option A, captured immediately on trigger) through transcription to insertion. The trigger is never discarded.

## Resolution (core — not per-strategy)

Implemented in `InsertionResolver` (`Sources/FastFlowPlugins/Insertion/`):

1. On trigger → capture `FocusSnapshot` (cheap AX query).
2. On transcript ready → re-query focus (Option B).
3. Compare:

| Case | Result |
|---|---|
| Same element, same app, valid text role | `.verified` → auto-insert |
| Different element, **same** app, valid text, **hotkey** | `.verified` |
| Different app, or no valid role | `.ambiguous` / `.unavailable` → confirmation UI |
| **Wake word** + nil/non-text initial focus | always `.ambiguous` |

## Strategy priority

1. App-specific adapter (e.g. `SlackInsertionAdapter`)
2. Default `AXInsertionStrategy` (`AXUIElementSetAttributeValue`)
3. `ClipboardPasteStrategy` (save → Cmd+V → restore)
4. Confirmation panel (`InsertionConfirmationPresenter`) — Copy / Paste now / Dismiss

## Load-bearing rule

**Never silently guess.** Wrong-target cost is high (Terminal, wrong Slack DM, wrong email). Every path ends in verified insert or visible confirmation.

## Privacy note

Accessibility focus probing and synthetic paste require TCC Accessibility (and often Input Monitoring). This is OS-gated for *whether* FastFlow may drive AX — not a guarantee about which field is “correct.” Correctness is the resolver + confirmation UI. See `docs/PRIVACY.md`.

## Extending

Add a `TextInsertionStrategy` for misbehaving apps under `Sources/FastFlow/Insertion/Strategies/` and register it first in `InsertionRouter`. Prefer clipboard fallback when Electron AX trees lie.
