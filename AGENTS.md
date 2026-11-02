# Vociare

Menu-bar push-to-talk dictation app (Swift, SwiftPM, no Xcode project). See README for what it does.

- Build with `swift build -c release --build-system native`: the default Swift Build backend fails with only the Command Line Tools installed.
- Install with `./scripts/install.sh`; it signs with a stable self-signed identity so Microphone/Accessibility grants survive rebuilds. Never switch to ad-hoc signing.
- `./scripts/uninstall.sh` must undo everything `install.sh` and the app create (the shared FluidAudio model only when the user agrees); update both together.
- `Vociare --transcribe <audio file>` exercises the model without the microphone; `Vociare --download-model` prefetches it (install.sh runs it); `Vociare --render-icon <dir>.iconset` renders the icon.
- Logs: `/usr/bin/log stream --level info --predicate 'subsystem == "me.ecamel.vociare"'` (in zsh, plain `log` is a builtin).
- The README states the code is AI-assisted; keep that note.
- Todos are GitHub issues: `gh issue list`.

## ADRs

Design decisions are Nygard-style ADRs in `docs/adr/`. Read the relevant ones before a tech or design choice.

- A significant decision (a library or model, an approach, a divergence from the obvious option, an alternative tried and rejected) gets an ADR in the same PR as the code. A decision that changes an earlier one sets the old ADR's status to `superseded by <link>` instead of contradicting it.
- Files are `ADR-NNNN-kebab-case-title.md`, numbered in merge order; titles are `# ADR-NNNN: Title`. No dates: Git has them.
- Sections, as in the existing ADRs: **Status** (accepted | deprecated | superseded by …); **Context** (the situation and the constraints that rule options out); **Decision** (what was chosen, then a `Rejected:` list with each alternative's reason), followed by **Confidence level** (high | upper-middle | middle | lower-middle | low); **Consequences** (bullets prefixed **[PROS]**, **[CONS]** or **[TRADE-OFFS]**); **Relevant Documents** (links, if any).
- An ADR records what the code can't show: constraints, decision, rejected alternatives, measurements. The how stays in the code: if a refactor that keeps the decision would make a sentence false, the sentence belongs in the code.
- List only alternatives that are a different decision, not another way to implement the chosen one. A rule that spans several components is one ADR, not one per component.
- Length follows the decision's impact, not the amount of code: a few short paragraphs, like the existing ones.
