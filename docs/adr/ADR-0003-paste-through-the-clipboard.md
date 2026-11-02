# ADR-0003: Paste through the clipboard

**Status:** accepted

## Context

The text must land in whatever field has focus: native apps, browsers, Electron apps, terminals.

## Decision

Put the text on the clipboard, post Cmd+V, and put the previous clipboard back half a second later, unless the user copied something in the meantime. The text is marked transient and current-host only, so clipboard managers skip it and Universal Clipboard doesn't send it to other devices. A copied password is cleared instead of restored, so its password manager still clears it on schedule. If the frontmost app changed during transcription, nothing is pasted and the text waits in Recent.

Rejected:

- **Typing the text as key events**: slow, and it can trigger autocomplete.
- **Setting the field's value through the Accessibility API**: fails in browsers and Electron apps.

**Confidence level:** high

## Consequences

- **[PROS]** One path for every kind of app.
- **[CONS]** The clipboard is overwritten for half a second; a clipboard manager that ignores the transient marker records the text.
- **[CONS]** Secure input fields and apps that ignore synthetic key presses are untested ([#3](https://github.com/ecamellini/vociare/issues/3)).
