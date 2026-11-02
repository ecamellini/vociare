# ADR-0004: Stable self-signed signing identity

**Status:** accepted

## Context

macOS ties the Microphone and Accessibility grants to the app's code signature. An ad-hoc signature changes at every build, so each rebuild would ask for both again. Vociare is built from source ([ADR-0005](ADR-0005-built-from-source-only.md)), with no Apple Developer account.

## Decision

`install.sh` signs with a self-signed certificate, its key non-exportable, in a dedicated keychain. The keychain's random password is stored in the login keychain, so installs sign without a prompt. The keychain locks right after signing, after 5 minutes and on sleep.

Rejected:

- **Ad-hoc signing**: the grants are lost at every rebuild.
- **Developer ID**: a paid Apple Developer Program membership, needed only to distribute builds.
- **A fixed keychain password in the script**: public with the repo.
- **Asking for the keychain password at each install**: a password the user never chose.

**Confidence level:** high

## Consequences

- **[PROS]** Rebuilds keep the grants, and installs need no prompt.
- **[CONS]** Any program running as the user can read the stored password and sign itself as Vociare, inheriting its grants, as with any developer certificate usable without a prompt.
