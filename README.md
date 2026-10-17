# Rehab Rhapsody

A music-based rehabilitation app for iPhone, built with Flutter. The iOS target
supports iOS 15 and later in portrait orientation. A browser preview lets
colleagues develop on Windows, macOS, or Linux. The repository includes `ios/`
and `web/` targets; there are no Android or native desktop targets.

## Set up the project in your IDE

### 1. Install the tools

| Tool | Purpose | Installation |
| --- | --- | --- |
| Git | Clone the repository and share changes | [Git downloads](https://git-scm.com/downloads) |
| Flutter SDK | Includes Dart and the app's build/test tools | [Flutter installation](https://docs.flutter.dev/install/with-vs-code) |
| Google Chrome | Run the browser preview | [Chrome download](https://www.google.com/chrome/) |
| VS Code | Edit and debug the app | [VS Code download](https://code.visualstudio.com/) |

Use **Flutter 3.47.7 stable**, which bundles **Dart 3.13.5**, to match the current
development setup. That exact release is available in the
[Flutter SDK archive](https://docs.flutter.dev/install/archive); choose your OS
and CPU architecture. `pubspec.yaml` allows Flutter 3.47.0 or newer with Dart
3.13.4 or newer, below Dart 4.0.0, but matching the exact SDK across the team
reduces differences in dependencies and tooling. Dart comes with Flutter, so a
separate Dart installation is unnecessary.

Add Flutter's `bin` directory to your `PATH`, then restart your IDE and terminal.
Check the installation in PowerShell on Windows or a terminal on macOS/Linux:

```sh
git --version
flutter --version
flutter doctor -v
```

For browser development, resolve issues with Flutter and Chrome. Android SDK,
Windows desktop, and Xcode checks are only relevant to those platforms; Xcode
is required when building the iPhone app on a Mac.

### 2. Clone the repository

From the folder where you keep your projects, run:

```sh
git clone https://github.com/alexghyet/rehab-rhapsody.git
cd rehab-rhapsody
```

If GitHub requests authentication, sign in with an account that has access to
the repository. To reproduce a colleague's work, use the same branch and commit;
`git rev-parse HEAD` prints the current commit ID.

### 3. Open the project in VS Code

1. Run `code .` from the cloned `rehab-rhapsody` folder, or use **File > Open
   Folder** and select that folder. Open the root containing `pubspec.yaml`.
2. Open **Extensions** and install **Flutter** (`Dart-Code.flutter`). It also
   installs the Dart extension. The repository's `.vscode/extensions.json`
   includes both recommendations.
3. If asked to locate Flutter, select the SDK installed in step 1. Keep any
   machine-specific SDK path in your user settings or local workspace settings.
4. Open **Terminal > New Terminal**. Run the remaining commands from this project
   root, using the IDE's integrated terminal.

For another IDE, such as Android Studio or IntelliJ IDEA, install its Flutter/Dart
plugins, open the existing project root, and select the same Flutter SDK. The
terminal commands below work independently of your editor. See
[Flutter's VS Code guide](https://docs.flutter.dev/tools/vs-code) for editor help.

### 4. Restore the locked dependencies

```sh
flutter pub get --enforce-lockfile
```

This downloads the versions in the committed `pubspec.lock` and creates local
package configuration. The flag makes dependency or package-hash mismatches fail
instead of silently changing the resolution. See
[Dart's lockfile documentation](https://dart.dev/tools/pub/cmd/pub-get#--enforce-lockfile).
Internet access is needed on first setup to download packages and Flutter's
platform artifacts. Bundled fonts are already in `assets/fonts/`.

The current app needs no API keys, `.env` file, backend service, or connected
baton to run the preview and tests.

### 5. Run the browser preview

```sh
flutter devices
flutter run -d chrome
```

Chrome should be listed by `flutter devices` and open the Rehab Rhapsody screen.
In VS Code, you can instead open **Run and Debug**, select **Rehab Rhapsody
(Browser preview)**, and press **F5**. The shared configuration is in
`.vscode/launch.json`.

Keep the terminal running while editing Dart files. Press `r` to reload changes,
`R` to restart the app, or `q` to stop. When debugging through VS Code, use its
reload and stop controls.

To preview an iPhone-sized layout, open Chrome DevTools and enable the device
toolbar (on Windows: **F12**, then **Ctrl+Shift+M**). Choose an available iPhone
preset or set a narrow viewport. This previews the screen and local controls; iOS native
code, Bluetooth, audio, device permissions, and actual iPhone behavior still need
testing on iOS. The current app has no live baton connection or audio playback.

### 6. Verify the setup

Run the checks in [Verify changes](#verify-changes). You should have no analyzer
issues and all tests should pass before sharing changes.

## Run on an iPhone or iOS Simulator (Mac only)

1. Complete the IDE setup above on a Mac using the same Flutter version.
2. Install and configure Xcode, accept its licenses, and download an iOS Simulator
   runtime using [Flutter's iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup).
   Follow that guide for CocoaPods if adding plugins that require native iOS code;
   the current app has no third-party native plugins.
3. Start an iPhone simulator from Xcode, or connect and unlock a physical iPhone.
   On a physical phone, trust the Mac and enable **Settings > Privacy & Security >
   Developer Mode**.
4. For a physical phone, open `ios/Runner.xcworkspace` in Xcode and select your
   development team under **Runner > Signing & Capabilities**. Use your own bundle
   identifier for device signing and distribution. A simulator does not require
   a development team or signing certificate.
5. Check the toolchain and select the device:

```sh
flutter doctor -v
flutter devices
```

Copy the desired ID from `flutter devices`, then run `flutter run -d DEVICE_ID`,
replacing `DEVICE_ID` with that value. In VS Code, select the iPhone in the Flutter
device picker and launch **Rehab Rhapsody (iPhone)**.

Windows and Linux can edit Dart code, run the browser preview, and run the
analyzer and tests. Building or running the native iOS app requires macOS.

## Keep the team setup reproducible

- Share source code, assets and font licenses, `ios/`, `web/`, `.metadata`,
  `pubspec.yaml`, `pubspec.lock`, and the shared editor configurations through Git.
  Commit and push the intended changes so colleagues can clone or pull them.
- Use the same Git commit and Flutter SDK version when comparing results.
  `pubspec.lock` pins packages; it does not pin the Flutter/Dart SDK itself.
- After committing your local work, pull team updates and restore dependencies:

  ```sh
  git pull --ff-only
  flutter pub get --enforce-lockfile
  ```

- For intentional dependency changes, edit `pubspec.yaml`, run `flutter pub get`,
  run the checks below, and commit `pubspec.yaml` and `pubspec.lock` together.
  Review SDK upgrades with the team and update the version instructions here.
- `.gitignore` excludes generated caches/builds, personal IDE settings, local
  environment files, and signing credentials. Keep `.vscode/extensions.json`,
  `.vscode/launch.json`, and portable `.vscode/tasks.json` under version control.
  If environment configuration is added later, commit a placeholder-only
  `.env.example` to document required values; real values stay local.
- iOS-generated files are also covered by `ios/.gitignore`. If native dependency
  tooling later creates `ios/Podfile.lock` or `Package.resolved`, commit those
  lockfiles with the dependency change.

Ignore rules do not remove files already tracked by Git. Review `git status`
before committing, especially after changing local SDK paths or Xcode signing.

## Troubleshooting setup

| Problem | What to check |
| --- | --- |
| `flutter` or `git` is not recognized | Check `PATH`, then restart the IDE and open a new terminal. |
| VS Code cannot find Flutter or the project | Open the folder containing `pubspec.yaml`, enable the Flutter extension, and select the installed SDK. |
| Dependency resolution or SDK constraint error | Compare `flutter --version` with step 1 and confirm you have the team's intended Git commit and lockfile. |
| Chrome is missing from `flutter devices` | Install Chrome, run `flutter config --enable-web`, then run `flutter doctor -v` and `flutter devices` again. |
| Packages or generated configuration appear stale | Stop the app, run `flutter clean`, then `flutter pub get --enforce-lockfile`, and restart it. |
| iPhone or simulator is missing | Check Xcode setup with `flutter doctor -v`, start the simulator, or unlock and trust the connected phone. |
| GitHub reports the repository cannot be found | Check the clone URL and that your signed-in GitHub account has repository access. |

## Project map

```text
lib/
  main.dart                         App entry point and status-bar style
  app.dart                          Root app and theme wiring
  theme/
    app_theme.dart                  Shared colors, fonts, and iOS behavior
  features/
    home/
      home_screen.dart              Main page, safe areas, scrolling, lifecycle
      home_controller.dart          Session timer and selected settings
      home_options.dart             Instruments and play modes
      widgets/
        home_header.dart            App title and baton connection status
        session_card.dart           Session time and play/pause control
        motion_card.dart            Motion preview and target-range chart
        setup_card.dart             Instrument and mode selectors
        sliders_card.dart           Volume and tempo controls
  widgets/
    decorative_bubble.dart          Shared background decoration
    surface_card.dart               Shared white card surface
assets/fonts/                       Bundled Fredoka/Nunito fonts and OFL licenses
ios/                                iPhone native project, launch screen, icons
web/                                Browser preview for development
test/features/home/                 Session, layout, and interaction tests
pubspec.yaml                        App metadata, dependencies, and font assets
.vscode/                            Flutter extensions, browser and iPhone launches
```

Edit the relevant card in `features/home/widgets/` to change a section of the
page. Shared styling belongs in `theme/app_theme.dart`. There is no FlutterFlow
runtime or generated page-model layer.

## Current behavior

- Play starts the session timer; pause retains the elapsed time for resuming.
  Interrupting or backgrounding the app pauses the session. Returning to the app
  leaves it paused until play is tapped again.
- Instrument, play mode, volume, and tempo controls update local session state.
  Settings and elapsed time reset when the app is closed; they are not persisted.
- The baton starts **offline**. The motion card shows a **Preview** of sample data.
  Bluetooth, sensor streaming, and audio playback are not implemented in the
  supplied design or this project. The screen accepts connection status and
  motion samples for a future hardware integration; the controller holds the
  selected music settings.
- The layout scrolls on smaller iPhones, respects the notch and home indicator,
  and adapts its controls to larger accessibility text. VoiceOver labels identify
  actions, selections, and slider values. Fonts load from bundled assets offline.

## Verify changes

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

On a Mac, also build the iOS Simulator app and run it on an iPhone simulator:

```sh
flutter build ios --simulator
```

`pubspec.lock` records resolved package versions and should be committed with
dependency updates. `.dart_tool/`, `build/`, and generated Xcode configuration are
local caches; they are ignored by Git.
