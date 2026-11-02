# Vociare

*Vociare* (Italian, /voˈtʃaːre/): to chatter, to talk loudly.

Local push-to-talk dictation for macOS. Hold **right Command**, speak, release: the text is pasted where you're typing (**Esc** while holding cancels). It runs entirely on your Mac with NVIDIA's Parakeet model, in 25 European languages; your voice never leaves it. From the menu bar icon you can paste a recent dictation again, reduce background noise, and set word replacements for names the model gets wrong (`cloud code -> Claude Code`).

> **AI-assisted code.** Vociare is vibe-coded: written by an AI coding agent, directed, reviewed and tested by a human.

## Install

Needs an Apple Silicon Mac with macOS 14+ and Xcode 26+ or its Command Line Tools (`xcode-select --install`).

```sh
./scripts/install.sh    # also to update, after git pull
```

It builds the app, downloads the model (~600 MB), installs `/Applications/Vociare.app` and starts it. Allow **Microphone** and **Accessibility** when asked; until both are granted, the menu's first line says what's missing.

The app is signed with a self-signed certificate in its own keychain, so rebuilds keep those permissions. That keychain's password is stored in your login keychain: any program running as you could use it to sign itself as Vociare and inherit them.

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
