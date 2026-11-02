# ADR-0009: Dictation key from the right-hand modifiers

**Status:** accepted

## Context

Right Command was the only dictation key, and some keyboards have none, or their user needs it for something else. The key is read by a listen-only event tap, so the app in front sees it too: held alone, it must type nothing there.

## Decision

A **Dictation Key** menu with right Command (the default), right Option and right Control, each held alone for 250 ms. The model's idle unload stays fixed at 10 minutes.

Rejected:

- **fn/Globe**: released alone, it triggers macOS's own Globe action (emoji picker, input source or dictation).
- **Any key, recorded as a shortcut**: a non-modifier held down types and repeats in the app in front.
- **Left modifiers**: in constant use for shortcuts, so a pause while holding one would start a dictation.
- **A configurable idle timeout**: reloading takes under a second and the loaded model holds little memory in the process, so the setting would change little.

**Confidence level:** upper-middle

## Consequences

- **[PROS]** Keyboards without right Command can dictate, with no change to how a dictation starts, stops or cancels.
- **[CONS]** MacBook keyboards have no right Control, so they get two choices.
