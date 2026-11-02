# Vociare

*Vociare* (Italian, /voˈtʃaːre/): to chatter, to talk loudly.

Local push-to-talk dictation for macOS. Hold **right Command**, speak, release: the text is pasted where you're typing. Voice and text never leave your Mac; the only download is the model.

> **AI-assisted code.** Vociare is vibe-coded: written by an AI coding agent, directed, reviewed and tested by a human. Keep that in mind before relying on it.

## How it works

- Transcription runs on the Neural Engine with NVIDIA's [Parakeet TDT 0.6B v3](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml) (25 European languages, auto-detected) through [FluidAudio](https://github.com/FluidInference/FluidAudio). The model loads when you dictate (about a second, overlapping your speech) and unloads after 10 idle minutes. After a macOS update the first dictation can take half a minute while Core ML re-prepares it.
- Dictation starts only when right Command is held alone for 250 ms, so taps, shortcuts and Command+click work as usual. **Esc** while holding cancels.
- Each dictation fits the text around the cursor: a space unless it follows a space or an opening bracket or quote, a lowercase first word after a word or a comma (names keep their capital), a space before a word right after the cursor. Where the app hides its text (terminals, some Electron apps), a trailing space is added instead.
- Text is pasted through the clipboard, which comes back half a second later unless you copied something meanwhile. A copied password is cleared instead of restored.
- Switched apps or no field focused? Pick **Paste Last Dictation** or **Recent** in the menu. The last 10 dictations are kept in memory only.

Menu options:

- **Reduce Background Noise**: macOS voice processing (echo cancellation, noise suppression, and Control Center's Mic Mode, where you can pick Voice Isolation). The first dictation after switching microphone takes about a second more: wait for the chime.
- **Latin Alphabet Only**: stops the model drifting into Cyrillic or Greek with Latin-script languages like Italian. Leave it off for Russian, Ukrainian or Bulgarian.
- **Edit Replacements…**: opens `~/Library/Application Support/Vociare/replacements.txt` for words the model gets wrong. One rule per line, e.g. `cloud code, claud code -> Claude Code` or `google -> Google`; case-insensitive, whole words, applied top to bottom from the next dictation on, Recent included.

## Requirements

- Apple Silicon Mac, macOS 14 or later.
- Xcode 26+ or its Command Line Tools (`xcode-select --install`): FluidAudio's package traits need Swift 6.2.
- No prebuilt release: build from source.

## Install and update

```sh
./scripts/install.sh                # update: git pull && ./scripts/install.sh
```

It builds Vociare, downloads the model once (~600 MB, into `~/Library/Application Support/FluidAudio/Models`), installs `/Applications/Vociare.app` (replacing and relaunching any running copy) and starts it. Grant **Microphone** (to record) at the prompt and **Accessibility** (to detect the key and paste) in System Settings → Privacy & Security; no relaunch needed. The menu's first line names any missing permission.

**Signing.** macOS ties these permissions to the app's signature, so the script signs with a self-signed certificate (non-exportable key) and rebuilds keep your grants. On first run it creates a dedicated keychain, `~/Library/Keychains/vociare-signing.keychain-db`, stores its random password in your login keychain (item `vociare-signing`) and adds it to the keychain search list for `codesign`. It relocks after signing, after 5 minutes or on sleep. The trade-off: any program running as you could read that password and sign itself as Vociare, inheriting its permissions, as with any developer certificate usable without a prompt.

**Upgrading from before late October 2026** downloads the model again, into `parakeet-tdt-0.6b-v3` with the more accurate `Encoder_v2.mlmodelc`. Unless another app uses them, delete the old `parakeet-tdt-0.6b-v3-coreml` folder and `parakeet-tdt-0.6b-v3/Encoder.mlmodelc`.

## Troubleshooting

- **Holding right Command does nothing**: the menu's first line names a missing permission.
- **Menu bar icon hidden behind the notch**: open Vociare again from Spotlight; the menu appears under the pointer.
- **Overlay shows but no text arrives**: check **Recent**. If it's empty, watch the log while dictating:
  ```sh
  /usr/bin/log stream --level info --predicate 'subsystem == "me.ecamel.vociare"'
  ```
- **No microphone connected**: recording doesn't start. Connect one or pick it in System Settings → Sound → Input.

## Uninstall

```sh
./scripts/uninstall.sh
```

Removes the app, its login item, the signing keychain (with search list entry and stored password), caches, settings, replacement rules and privacy permissions. It asks before deleting the model, since other FluidAudio apps may share it; without a terminal, the model is kept.

## Development

```sh
swift build -c release --build-system native   # native: needed with only the Command Line Tools
```

- `Vociare --download-model`: download the model if missing and load it once.
- `Vociare --transcribe <audio file>`: print the text with cold and warm timings.
- `Vociare --render-icon <dir>.iconset`: render the icon, drawn in `VociareIcon.swift`.
- `Vociare --unregister-login-item`: remove the login item (`uninstall.sh` runs it).

## Credits

- [FluidAudio](https://github.com/FluidInference/FluidAudio) by FluidInference, Apache License 2.0.
- [Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) by NVIDIA, in the [Core ML conversion](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml) by FluidInference, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Downloaded from Hugging Face at install time, not redistributed here.

## License

[MIT](LICENSE)
