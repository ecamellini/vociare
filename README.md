# Vociare

*Vociare* (Italian, /voˈtʃaːre/): to chatter, to talk loudly.

Local push-to-talk dictation for macOS. Hold **right Command**, speak, release: the text is pasted where you're typing (**Esc** while holding cancels). It runs entirely on your Mac with NVIDIA's Parakeet model, in 25 European languages; your voice never leaves it. Text goes through the clipboard, which is restored afterwards; a copied password is cleared instead.

From the menu bar icon you can paste a recent dictation again, reduce background noise, keep the output in the Latin alphabet (the model sometimes slips into Cyrillic or Greek), and set word replacements for names it gets wrong (`cloud code -> Claude Code`).

> **AI-assisted code.** Vociare is vibe-coded: written by an AI coding agent, directed, reviewed and tested by a human.

## Install

Needs an Apple Silicon Mac with macOS 14+ and Xcode 26+ or its Command Line Tools (`xcode-select --install`).

```sh
./scripts/install.sh    # also to update, after git pull
```

It builds the app, downloads the model (~600 MB), installs `/Applications/Vociare.app` and starts it. Allow **Microphone** and **Accessibility** when asked; until both are granted, the menu's first line says what's missing.

The app is signed with a self-signed certificate in its own keychain, so rebuilds keep those permissions. That keychain's password is stored in your login keychain: any program running as you could use it to sign itself as Vociare and inherit them.

Upgrading from before late October 2026 downloads the model again. Unless another app uses them, delete the old `parakeet-tdt-0.6b-v3-coreml` folder and `parakeet-tdt-0.6b-v3/Encoder.mlmodelc` in `~/Library/Application Support/FluidAudio/Models`.

## Troubleshooting

- **Holding right Command does nothing**: the menu's first line names what's missing, a permission or a microphone.
- **Menu bar icon hidden behind the notch**: open Vociare again from Spotlight; the menu appears under the pointer.
- **First dictation after a macOS update is slow** (about half a minute): Core ML is preparing the model again.
- **No text arrives**: the dictation is in **Recent**. If it isn't, watch the log (see Development) while dictating.

## Uninstall

```sh
./scripts/uninstall.sh
```

Removes everything Vociare and the install created. It asks before deleting the model, which other FluidAudio apps may share.

## Development

```sh
swift build -c release --build-system native   # native: needed with only the Command Line Tools
/usr/bin/log stream --level info --predicate 'subsystem == "me.ecamel.vociare"'
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
