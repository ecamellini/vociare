# ADR-0007: Word replacements as plain rules

**Status:** accepted

## Context

Parakeet takes no vocabulary, so names come out wrong ("cloud code" for "Claude Code"). Vociare stays local ([ADR-0001](ADR-0001-parakeet-v3-on-core-ml-through-fluidaudio.md)), and a dictation carries no context about its topic.

## Decision

Rules the user writes in a text file, `cloud code, claud code -> Claude Code`: case-insensitive, whole words, applied top to bottom before the text is pasted and kept in Recent. The file is read at every dictation and opened from the menu. `--transcribe` prints the raw model output, so comparing FluidAudio versions isn't masked by someone's rules.

Rejected:

- **A free-text glossary an LLM reads with each dictation**: network and latency on every dictation. It would fix ambiguous cases plain rules can't, but those don't justify the cost here.

**Confidence level:** high

## Consequences

- **[PROS]** Deterministic, instant and offline.
- **[CONS]** A rule rewrites every match, so only unambiguous rules belong in the file: `tt -> DTD` would break every real "TT".
- **[CONS]** A name stays wrong until the user writes its rule.

## Relevant Documents

- [#32: Word replacements](https://github.com/ecamellini/vociare/pull/32)
