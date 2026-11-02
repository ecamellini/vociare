# ADR-0006: Voice processing as an option

**Status:** accepted

## Context

macOS voice processing on the microphone brings echo cancellation, noise suppression and Control Center's Mic Mode (Voice Isolation), which help in noisy rooms. But turning it on takes about 1.5 s, which would cut the first words, it ducks other audio, and the input becomes multichannel with the clean voice in channel 0.

## Decision

A **Reduce Background Noise** menu toggle, off by default. When on, the engine is prepared in the background (at launch, on toggle, after a microphone change) and reused, so audio arrives in 130-190 ms; the start chime waits for the first captured audio. Ducking is set to the minimum. A prepared engine keeps neither the microphone nor the output running while idle (checked on Bluetooth earbuds).

Rejected:

- **On by default**: its effect on dictation quality isn't measured, and the first dictation after switching microphone still waits ~1.5 s.
- **A prepared engine without voice processing too**: it saves at most 50-100 ms, and it crashed the app when Bluetooth earbuds switched audio mode.

**Confidence level:** middle

## Consequences

- **[PROS]** With the option on, dictation starts about as fast as without.
- **[CONS]** The first dictation after switching microphone takes ~1.5 s more.
- **[CONS]** The recorder must read channel 0, and refuses input formats where that read would be wrong.

## Relevant Documents

- [#9: Add an option to reduce background noise](https://github.com/ecamellini/vociare/pull/9)
