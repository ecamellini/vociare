# Vociare

*Vociare* (Italian, /voˈtʃaːre/): to chatter, to talk loudly.

Local push-to-talk dictation for macOS. Hold **right Command**, speak, release: the text is pasted into the app you're typing in. Your voice and text never leave your Mac; the only download is the model.

> **AI-assisted code.** Vociare is a vibe-coded app: its code was written by an AI coding agent, directed, reviewed and tested by a human. Read it with that in mind before relying on it.

- Transcription runs on-device with NVIDIA's [Parakeet TDT 0.6B v3](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml) (25 European languages, detected automatically) through [FluidAudio](https://github.com/FluidInference/FluidAudio), on the Apple Neural Engine.
- The model loads when you start dictating and unloads after 10 idle minutes. Reloading takes about a second and overlaps with your speech. After a macOS update the first dictation can take half a minute, while Core ML prepares the model for the Neural Engine again.
- A quick tap, a Command+key shortcut or a Command+click works as usual: dictation starts only when right Command is held on its own for 250 ms.
- **Latin Alphabet Only** in the menu stops the model from writing in Cyrillic or Greek, which it occasionally does with Latin-script languages such as Italian. Leave it off if you dictate in Russian, Ukrainian or Bulgarian.
- Text is pasted through the clipboard, and your previous clipboard comes back half a second later, unless you copied something in the meantime. A password copied from a password manager is cleared rather than restored.
- If you switched apps while Vociare was transcribing, or no text field had focus, the text isn't lost: click into the field and pick **Paste Last Dictation** or **Recent** from the menu bar icon. The last 10 dictations are kept in memory only and are gone when Vociare quits.

## Requirements

- Apple Silicon Mac, macOS 14 or later.
- Xcode 16 or later, or its Command Line Tools (`xcode-select --install`).
- No prebuilt release: Vociare is built from source.

## Install

```sh
./scripts/install.sh
```

It builds Vociare, downloads the model (~470 MB, into `~/Library/Application Support/FluidAudio/Models`; skipped when already there), installs the app as `/Applications/Vociare.app` (replacing and relaunching any running copy) and starts it.

On first launch Vociare asks for two permissions: **Microphone**, to record while you hold the key, and **Accessibility**, to detect the key and paste with Cmd+V. Accept the microphone prompt, then turn Vociare on in System Settings → Privacy & Security → Accessibility; no relaunch needed. The first line of the menu bar menu names any missing permission, and reads "Hold right ⌘ to dictate" once everything is set.

### Why install.sh creates a keychain

macOS ties the Microphone and Accessibility permissions to the app's signature, so an unsigned rebuild would lose them. On the first run the script:

- creates a self-signed certificate with a non-exportable key in a dedicated keychain, `~/Library/Keychains/vociare-signing.keychain-db`;
- stores that keychain's random password in your login keychain (item `vociare-signing`), so later installs sign without prompting;
- adds the keychain to your keychain search list, which `codesign` needs to find the certificate.

The keychain locks again right after signing, and also after 5 minutes or when the Mac sleeps. The cost of signing without a prompt: any program running as you could read the stored password and sign itself as Vociare, inheriting its Microphone and Accessibility permissions. A developer certificate that `codesign` can use without asking carries the same risk.

## Update

```sh
git pull && ./scripts/install.sh
```

This rebuilds and reinstalls with the same signing identity, so the permissions you granted are kept.

Versions from October 2026 on download the model again (~470 MB) into `parakeet-tdt-0.6b-v3`. Earlier ones kept it in `parakeet-tdt-0.6b-v3-coreml`, in the same folder: delete that one if no other app uses it.

## Troubleshooting

- **Holding right Command does nothing**: open the menu bar icon; its first line names a missing permission.
- **The overlay shows but no text arrives**: look in **Recent**. If it's empty, watch the log while you dictate:
  ```sh
  /usr/bin/log stream --level info --predicate 'subsystem == "me.ecamel.vociare"'
  ```
- **No microphone connected**: Vociare doesn't start recording. Connect one or pick it in System Settings → Sound → Input.

## Uninstall

```sh
./scripts/uninstall.sh
```

Removes the app and its login item, the signing keychain (with its search list entry and stored password), caches, menu settings and Vociare's privacy permissions. It then asks whether to delete the downloaded model too: the model lives in FluidAudio's shared folder, where other apps built on FluidAudio may use it. Without a terminal to ask in, the model is kept.

## Development

```sh
swift build -c release --build-system native
```

`--build-system native` is needed when only the Command Line Tools are installed. A few flags work without the UI:

- `Vociare --download-model` downloads the model if missing and loads it once.
- `Vociare --transcribe <audio file>` runs the model on a file and prints the text with cold and warm timings.
- `Vociare --render-icon <dir>.iconset` renders the app icon, drawn in code in `VociareIcon.swift`.
- `Vociare --unregister-login-item` removes the login item; `uninstall.sh` runs it before deleting the app.

## Credits

- [FluidAudio](https://github.com/FluidInference/FluidAudio) by FluidInference, Apache License 2.0.
- [Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) by NVIDIA, in the [Core ML conversion](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml) by FluidInference, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The model is downloaded from Hugging Face at install time and not redistributed here.

## License

[MIT](LICENSE)
