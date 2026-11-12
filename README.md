# Rehab Rhapsody

A Flutter music game that turns movement from a **Seeed Studio XIAO nRF52840
Sense** into musical notes. Follow familiar songs, adjust the target to a
comfortable angle, and hold inside the target zone to hit notes automatically.
You can also play with onscreen buttons, without a baton.

Includes three songs, four instruments, Free play, Guided, and Rhythm modes.
Music and fonts are bundled. No account, API key, or backend server is required.

## Quick start on Windows, macOS, or Linux

Install [Git](https://git-scm.com/downloads),
[Flutter](https://docs.flutter.dev/install), and Chrome. Use **Flutter 3.47.7
stable**, which includes Dart 3.13.5, to match this project's tested setup.
Add Flutter's `bin` folder to your `PATH` and restart your terminal.

```sh
git clone https://github.com/alexghyet/rehab-rhapsody.git
cd rehab-rhapsody
flutter pub get --enforce-lockfile
flutter run -d chrome
```

Run commands from the folder containing `pubspec.yaml`. The first setup needs
internet to download dependencies. If you already have the project, start with
`flutter pub get --enforce-lockfile` in that folder.

1. Press **Start song** and wait for the count-in.
2. Tap **Play note** when a note reaches the line. The app chooses the pitch.
3. Tap the song title to change songs, or **Settings** to change modes,
   instruments, volume, and tempo.

Opening settings pauses playback. Close settings and press Play to resume.
Press `q` in the terminal to stop the development app.

## Connect the baton

1. Upload [the BLE sketch](firmware/ble_motion/ble_motion.ino) using the
   [Arduino setup instructions](firmware/README.md). An already programmed
   board only needs power.
2. Disconnect the board from LightBlue or any other app.
3. In Rehab Rhapsody, open **Baton settings > Connect baton** and select
   **Rehab Rhapsody** in the browser's device chooser.
4. Open **Adjust target**. Set the target height, or hold the desired position
   and tap **Use current position**.
5. Return to the song, press Play, and hold inside the thin target zone.

Use desktop Chrome on localhost with Bluetooth enabled for the browser demo.
Browser/OS support varies; the [demo guide](docs/demo-guide.md) covers connection
behavior, troubleshooting, and physical-device checks.

## Run on an iPhone

The native app targets **iOS 15+** in portrait orientation. Building and
installing it requires a **Mac with Xcode**; Windows can run the browser demo.

1. Complete the [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup)
   on a Mac and restore this project's dependencies.
2. Connect and unlock the iPhone, trust the Mac, and enable Developer Mode.
3. Open `ios/Runner.xcworkspace` in Xcode. Under **Runner > Signing &
   Capabilities**, choose your team and a unique bundle identifier.
4. Run `flutter devices`, then `flutter run -d DEVICE_ID` using your iPhone's ID.

An iOS Simulator can preview the interface. Use a physical phone to test baton
Bluetooth and native audio. Safari's Web Bluetooth support does not provide
this app's baton connection. See [iPhone development](docs/development.md#iphone)
for tooling and troubleshooting.

## Verify changes

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
```

## Project map

| Path | Contents |
| --- | --- |
| `lib/features/` | Audio, Bluetooth, motion mapping, gameplay, and screens |
| `lib/theme/` | Shared styling and bundled fonts |
| `test/features/` | Logic, adapter, lifecycle, and phone layout tests |
| `firmware/` | Arduino sketches, hardware setup, and BLE protocol |
| `assets/` | Bundled audio, fonts, and credits/licenses |
| `ios/`, `web/` | Native iPhone and browser projects |
| `scripts/` | Optional audio generation and browser smoke checks |

- [Demo guide](docs/demo-guide.md): controls, modes, and device acceptance.
- [Development guide](docs/development.md): IDE setup, troubleshooting, and checks.
- [Architecture and roadmap](docs/backend-plan.md): implementation and next work.
- [Developer scripts](scripts/README.md): regenerate audio and check browser playback.

The repository includes iOS and web targets. Settings and results currently
stay in memory; saved sessions and patient-specific calibration remain future
work. Real iPhone Bluetooth/audio acceptance is still pending.
