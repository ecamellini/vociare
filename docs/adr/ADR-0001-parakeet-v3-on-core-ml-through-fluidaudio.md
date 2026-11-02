# ADR-0001: Parakeet v3 on Core ML through FluidAudio

**Status:** accepted

## Context

Dictation must run entirely on the Mac, at least in Italian and English, fast enough that the text is ready when the key is released, from a menu-bar app with no runtime to install alongside it.

## Decision

NVIDIA's Parakeet TDT 0.6B v3 (25 European languages, detected automatically), in FluidInference's Core ML conversion, run on the Neural Engine by the FluidAudio Swift package. Its output is pasted as it comes, with no LLM pass.

Rejected:

- **Parakeet on MLX or NeMo, in a Python process**: a Python setup and a background server. On FLEURS (50 utterances per language) MLX is as accurate (Italian 2.45% WER for both, English 5.48% against 5.30%), but about 2.5x slower warm, seconds to load instead of ~0.3 s, 3-4 GB of memory instead of ~0.5 GB, and on 5 minutes of English it dropped whole sentences (33% WER against 8.4%).
- **Converting Parakeet to Core ML ourselves**: days of work for what FluidAudio already ships.
- **Whisper Large v3 Turbo**: slower, and it tends to invent text in silence. Not measured.
- **Parakeet v2**: English only.
- **An LLM cleanup pass** (Apple Foundation Models, or a cloud model): more latency, and a cloud one sends the text off the Mac.

**Confidence level:** high

## Consequences

- **[PROS]** No network after the model download and no Python; the model loads while the user speaks.
- **[CONS]** A ~600 MB download, and after each macOS update Core ML prepares the model again, so the first dictation takes about half a minute.
- **[CONS]** Parakeet takes no vocabulary: names it gets wrong need [replacement rules](ADR-0007-word-replacements-as-plain-rules.md).
- **[TRADE-OFFS]** The model lives in FluidAudio's shared folder, which other FluidAudio apps may use: uninstall asks before deleting it.

## Relevant Documents

- [FluidAudio](https://github.com/FluidInference/FluidAudio)
- [Parakeet TDT 0.6B v3, Core ML conversion](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml)
