# Parla

Menu-bar push-to-talk dictation app (Swift, SwiftPM, no Xcode project). See README for what it does.

- Build with `swift build -c release --build-system native`: the default Swift Build backend fails with only the Command Line Tools installed.
- Install with `./scripts/install.sh`; it signs with a stable self-signed identity so Microphone/Accessibility grants survive rebuilds. Never switch to ad-hoc signing.
- `./scripts/uninstall.sh` must undo everything `install.sh` and the app create; update both together.
- `Parla --transcribe <audio file>` exercises the model without the microphone; `Parla --render-icon <dir>.iconset` renders the icon.
- The README states the code is AI-assisted; keep that note.
- Todos are GitHub issues: `gh issue list`.
