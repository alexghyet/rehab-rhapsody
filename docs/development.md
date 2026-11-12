# Development guide

Start with the [README quick start](../README.md#quick-start-on-windows-macos-or-linux).
This guide covers the development workflow and platform-specific details.

## Tools and dependencies

- Tested SDK: **Flutter 3.47.7 stable / Dart 3.13.5**. Get an exact release from
  the [Flutter archive](https://docs.flutter.dev/install/archive).
- `pubspec.yaml` accepts Flutter 3.47.0+ and Dart 3.13.4+, below Dart 4. Use the
  tested SDK when reproducing someone else's results.
- `pubspec.lock` records package versions. Run `flutter pub get --enforce-lockfile`
  after cloning or pulling; the flag rejects an inconsistent lockfile instead
  of silently changing dependencies.
- Python 3 is only needed for audio generation or serving a release build.
  Node.js and Playwright are only needed for optional browser smoke checks.
  Audio assets are already committed, so neither tool is required to run Flutter.

Check your environment:

```sh
git --version
flutter --version
flutter doctor -v
flutter devices
```

For browser work, resolve Flutter and Chrome issues. Xcode is needed for iOS;
an Android SDK or native Windows desktop toolchain is not needed for this
project's browser target.

## Editor setup

Open the repository root, containing `pubspec.yaml`. In VS Code, install the
recommended Flutter extension; it includes Dart support. Select **Rehab
Rhapsody (Browser preview)** in Run and Debug, then press F5. The shared launch
configuration also includes an iPhone entry; select the device on a Mac first.

Keep personal SDK paths in user settings or ignored `.vscode/settings.json`.
The terminal commands work with other editors too. From `flutter run`, use
`r` to reload, `R` to restart, and `q` to quit.

## iPhone

Follow [Flutter's iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup)
to install Xcode, its command-line tools, and an iOS Simulator runtime. Accept
Xcode's licenses locally. Use an Xcode version supported by the installed Flutter
SDK; the BLE plugin also needs the iOS 18 SDK/Xcode 16 or newer to compile.
The app itself targets iOS 15+.

The project uses Swift Package Manager for native Flutter plugins. Let Flutter
resolve the generated native dependencies. Do not copy a Windows-generated
`ios/Flutter/Generated.xcconfig` to another computer; `flutter pub get` and the
build regenerate local configuration.

For a physical iPhone, trust the Mac, enable **Settings > Privacy & Security >
Developer Mode**, and choose a signing team and unique bundle identifier in
`ios/Runner.xcworkspace`. Then:

```sh
flutter pub get --enforce-lockfile
flutter devices
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with the iPhone ID from `flutter devices`. A simulator needs
no signing team and is useful for layout checks:

```sh
flutter build ios --simulator
```

The Bluetooth permission explanation is in `ios/Runner/Info.plist`. Test actual
BLE, sound, permission denial, and interruptions on a physical device. Browser
tests with a simulated peripheral cannot validate a radio or native iOS plugins.

## Checks before sharing changes

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
```

Tests follow the feature layout under `test/features/`. They cover packet
decoding and ordering, connection cancellation, audio races, song scoring,
session lifecycle, and phone layouts at normal and enlarged text sizes.
Use `flutter test test/features/FEATURE/` for a focused iteration, then run
the full suite after changes that affect several features.

For real browser audio and simulated Bluetooth checks, follow
[scripts/README.md](../scripts/README.md). A physical acceptance checklist is
in the [demo guide](demo-guide.md#validation-and-remaining-work).

## Local release preview

Build with the renderer bundled, then serve **only the compiled web folder**:

```sh
flutter build web --no-web-resources-cdn
python -m http.server 7357 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:7357` in desktop Chrome. On macOS/Linux, use `python3` if
`python` is unavailable. Stop the server with Ctrl+C. This loopback address
serves the demo only on the computer running it; it is not an iPhone Wi-Fi link
or a public deployment. Initial dependency downloads and debug renderer loads
may still need internet.

## Code organization

| Feature | Responsibility |
| --- | --- |
| `baton` | BLE discovery, connection, notifications, and cancellation |
| `motion` | Wire-format validation, ordering, and motion-to-pitch mapping |
| `music` | MIDI note identity and display formatting |
| `audio` | Foreground samples, backing tracks, and audio interruptions |
| `songs` | Generated charts, deterministic scoring, song clock, and song UI |
| `demo` | Coordinates motion, audio, session state, and practice controls |
| `home` | Session preferences, fixed play workspace, and settings pages |

Use the existing transport/audio interfaces for hardware-independent tests.
Keep scoring independent of UI and platform plugins. When editing songs,
change the generator and regenerate the charts and audio together; see the
[script guide](../scripts/README.md). Preserve asset licenses and credits.

## Repository hygiene

- Keep the app source, platform projects, `.metadata`, assets/licenses,
  `pubspec.yaml`, and `pubspec.lock` in Git.
- Review dependency changes deliberately; commit `pubspec.yaml` and the updated
  lockfile together. Use the same SDK and Git commit when comparing results.
- `build/`, `.dart_tool/`, generated native files, personal editor settings,
  downloaded firmware libraries, and signing credentials stay local. The build
  and tools recreate their outputs; do not copy caches to set up another device.
- Use `flutter clean` only when troubleshooting stale generated state, then
  restore dependencies. It also removes optional tooling under `build/`.
- Check `git status` before sharing; ignore rules do not untrack files already
  committed. Never commit a personal signing identity or machine-specific SDK path.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `flutter` is not recognized | Add the SDK's `bin` to `PATH`, then restart the terminal/IDE. |
| Repository cannot be cloned | Check the URL and GitHub account's repository access. |
| SDK/lockfile mismatch | Check `flutter --version`, your branch, and the committed lockfile. |
| Chrome is missing | Install Chrome, run `flutter config --enable-web`, then `flutter doctor -v`. |
| IDE cannot find the project | Open the folder containing `pubspec.yaml` and select your Flutter SDK. |
| iPhone is missing | Check Xcode setup, unlock/trust the phone, enable Developer Mode, and run `flutter devices`. |
| No sound | Press Play or a note pad, check output volume/tab mute, and inspect **Baton settings** for audio errors. |
| Baton does not connect | Enable Bluetooth, power the BLE sketch, and disconnect LightBlue/other connected apps. |
| Generated configuration is stale | Stop the app, run `flutter clean`, restore dependencies, and restart. |
