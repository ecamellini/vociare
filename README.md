# Vociare

*Vociare* (Italian, /voˈtʃaːre/): to chatter, to talk loudly.

Local push-to-talk dictation for macOS. Hold **right Command**, speak, release: the text is typed into the focused app. Your voice and text never leave your Mac; the only download is the model.

> **AI-assisted code.** Vociare is a vibe-coded app: its code was written by an AI coding agent, directed, reviewed and tested by a human. Read it with that in mind before relying on it.

- Transcription runs on-device with NVIDIA's [Parakeet TDT 0.6B v3](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml) (25 European languages) through [FluidAudio](https://github.com/FluidInference/FluidAudio), on the Apple Neural Engine.
- The model loads on the first dictation and unloads after 10 idle minutes. Reloading from the local cache takes about a second and overlaps with your speech.
- A quick tap, a Command+key combo or a Command+click keeps working as normal: dictation starts after a 250 ms hold.
- Text is pasted through the clipboard, which is restored right after. If it landed nowhere (no text field focused), click into the field and use **Paste Last Dictation** or **Recent** in the menu bar. The last 10 dictations are kept in memory only.

## Requirements

- Apple Silicon Mac, macOS 14 or later.
- Xcode or the Command Line Tools (`xcode-select --install`).
- No prebuilt release: Vociare is built from source.

## Install

```sh
./scripts/install.sh
```

It builds Vociare, downloads the model (~470 MB, into `~/Library/Application Support/FluidAudio/Models`; skipped when already there), installs the app as `/Applications/Vociare.app` (replacing and relaunching any running copy) and starts it. Then grant **Microphone** and **Accessibility** in System Settings → Privacy & Security.

On the first run the script also sets up code signing, because macOS ties the Microphone and Accessibility permissions to the app's signature and an unsigned rebuild would lose them:

- it creates a self-signed certificate with a non-exportable key in a dedicated keychain, `~/Library/Keychains/vociare-signing.keychain-db`;
- it stores that keychain's random password in your login keychain (item `vociare-signing`), so later installs sign without prompting;
- it adds the keychain to your keychain search list, which `codesign` needs to find the certificate.

The keychain is locked again right after signing. The trade-off of prompt-free signing: a program running as you could read the stored password and sign itself as Vociare, inheriting its Microphone and Accessibility permissions. A developer certificate that `codesign` may use without asking carries the same risk.

## Uninstall

```sh
./scripts/uninstall.sh
```

Removes the app and its login item, the signing keychain (with its search list entry and stored password), caches, the downloaded model and Vociare's privacy permissions. The model lives in FluidAudio's shared folder, so other apps built on FluidAudio would download it again.

## Development

```sh
swift build -c release --build-system native
```

`--build-system native` is needed when only the Command Line Tools are installed. A few flags work without the UI:

- `Vociare --download-model` downloads the model if missing and loads it once.
- `Vociare --transcribe <audio file>` runs the model on a file and prints the text with cold and warm timings.
- `Vociare --render-icon <dir>.iconset` renders the app icon, drawn in code in `VociareIcon.swift`.

## Credits

- [FluidAudio](https://github.com/FluidInference/FluidAudio) by FluidInference, Apache License 2.0.
- [Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) by NVIDIA, in the [Core ML conversion](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml) by FluidInference, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The model is downloaded from Hugging Face at install time and not redistributed here.

## License

[MIT](LICENSE)
