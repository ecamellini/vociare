# ADR-0002: The int8-v2 encoder

**Status:** accepted

## Context

FluidAudio's default Parakeet encoder (`Encoder.mlmodelc`, 6-bit) corrupts words in some contexts ([FluidAudio #760](https://github.com/FluidInference/FluidAudio/issues/760)). FluidAudio also ships an `int8V2` encoder (`Encoder_v2.mlmodelc`).

## Decision

Load the `int8V2` encoder. On a real 3-minute Italian meeting, same segments for both, it fixed 7 words the default got wrong ("Querfetto" → "Quel perfetto", "tuo balletto" → "tovagliato") and got 1 wrong that the default had right. Another app measured 7.9% of words different from MLX against 9.6%, on 692 sentences. Warm timings are the same.

Rejected:

- **The default encoder**: a smaller download (~470 MB against ~600 MB for a fresh install), already on disk for earlier versions.

**Confidence level:** upper-middle

## Consequences

- **[PROS]** Fewer corrupted words.
- **[CONS]** A bigger download, and ~570 MB once for users upgrading. The old `Encoder.mlmodelc` stays in the shared folder, since other FluidAudio apps may load it.
- **[CONS]** A slightly slower cold load: 0.68-0.78 s against 0.54-0.67 s, with 13 s of audio.

## Relevant Documents

- [#16: Use FluidAudio's int8-v2 encoder](https://github.com/ecamellini/vociare/pull/16)
