# ADR-0005: Built from source only

**Status:** accepted

## Context

A downloaded app needs a Developer ID signature and notarization, a paid Apple Developer Program membership, or Gatekeeper blocks it. The Mac App Store sandbox restricts the global key listener and the synthetic Cmd+V Vociare relies on. The development Mac has only the Command Line Tools, no Xcode.

## Decision

No prebuilt release. Vociare is a SwiftPM package with no Xcode project, and `install.sh` builds, signs ([ADR-0004](ADR-0004-stable-self-signed-signing-identity.md)) and installs it. Updating is `git pull` and running the script again.

Rejected:

- **A notarized download**: a yearly fee for a personal project.
- **The Mac App Store**: the sandbox limits above, App Review risk, and it needs Xcode.
- **Auto-updates (Sparkle)**: nothing to update without a binary release.

**Confidence level:** upper-middle

## Consequences

- **[PROS]** No fees, and the whole toolchain is the Command Line Tools.
- **[CONS]** Users need a terminal and Xcode 26 or its Command Line Tools: FluidAudio's package traits need Swift 6.2.
- **[CONS]** SwiftPM's default Swift Build backend fails with only the Command Line Tools, so the build uses the deprecated `--build-system native` ([#18](https://github.com/ecamellini/vociare/issues/18)).
