# ADR-0008: Fit dictations to the text around the cursor

**Status:** accepted

## Context

The model writes whole sentences: a capital, a full stop, no spaces around them. Pasted after existing text, they glue ("Frase.Frase") or capitalize mid-sentence ("Ciao Mario,Come stai?").

## Decision

Before pasting, read the text around the cursor through the Accessibility API, then add a leading space where needed, lowercase the first word mid-sentence (names keep their capital) and add a space before a following word. Where the field exposes nothing, or reports the cursor at 0 (as terminals do), add a trailing space instead.

Rejected:

- **Always a space before and after**: double spaces between consecutive dictations, a leading space in empty fields, and the mid-sentence capital stays.
- **A trailing space only**: fixes the gluing, not the capital.

**Confidence level:** upper-middle

## Consequences

- **[PROS]** Consecutive dictations read as one text in most apps.
- **[CONS]** It depends on what each app exposes; Chrome's address bar strips the spaces anyway.
- **[CONS]** A brand the name detection misses gets lowercased; a [replacement rule](ADR-0007-word-replacements-as-plain-rules.md) fixes it.

## Relevant Documents

- [#33: Fit each dictation to the text around the cursor](https://github.com/ecamellini/vociare/pull/33)
