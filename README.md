# Rehab Rhapsody

A music-based rehabilitation app, built with [Flutter](https://flutter.dev).
Pages are designed in FlutterFlow and exported into this project.

## Setting up on your computer

### 1. Install the tools

| Tool | Why you need it | Get it |
|---|---|---|
| **Git** | Downloads this repo | [git-scm.com/downloads](https://git-scm.com/downloads) |
| **Flutter 3.47 or newer** | Builds and runs the app | [docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install) (choose your operating system) |
| **Google Chrome** | The quickest way to run the app | [google.com/chrome](https://www.google.com/chrome/) |
| **VS Code** (recommended) | Code editor | [code.visualstudio.com](https://code.visualstudio.com/) |

Optional, only if you want to run the app on a phone:

- **Android:** [Android Studio](https://developer.android.com/studio), which includes the Android SDK and an emulator.
- **iPhone:** [Xcode](https://developer.apple.com/xcode/). This requires a Mac.

To check what's installed and what's missing, run:

```sh
flutter doctor
```

Only the **Flutter** and **Chrome** lines need a ✓ to run the app in a browser.

### 2. Download the project

```sh
git clone https://github.com/alexghyet/rehab-rhapsody.git
cd rehab-rhapsody
flutter pub get
```

`flutter pub get` downloads the packages the app uses, such as charts, the
timer and fonts. Run it again whenever `pubspec.yaml` changes.

### 3. Run it

```sh
flutter run -d chrome
```

In VS Code, open the folder and accept the prompt to install the recommended
Flutter extensions. Then press **F5** and choose **Rehab Rhapsody (Chrome)**.

While the app is running, press `r` in the terminal to reload your changes
instantly, or `q` to quit.

### 4. Run the tests

```sh
flutter test
```

## Where things are

```
lib/                      ← the app's code (you'll work here almost all the time)
├── main.dart             ← starts the app and opens the home page
├── pages/                ← one folder per screen
│   └── home_page/
│       ├── home_page_widget.dart   ← what the screen looks like (FlutterFlow export)
│       └── home_page_model.dart    ← the screen's state: slider, dropdown and timer values
└── flutter_flow/         ← shared building blocks the pages use
    ├── flutter_flow_theme.dart       ← app colours and fonts (light and dark mode)
    ├── flutter_flow_widgets.dart     ← buttons
    ├── flutter_flow_drop_down.dart   ← dropdown menus
    ├── flutter_flow_timer.dart       ← session timer
    ├── flutter_flow_charts.dart      ← line charts
    ├── flutter_flow_model.dart       ← base class every page model extends
    ├── flutter_flow_util.dart        ← small helpers
    └── form_field_controller.dart    ← holds a form field's current value

test/                     ← automated checks (run with `flutter test`)

android/                  ← setup that turns the app into an Android app
ios/                      ← same for iPhone (building it needs a Mac)
web/                      ← same for the browser; also the app's browser icon and title

pubspec.yaml              ← app name, version and package list; edit this to add a package
pubspec.lock              ← exact package versions (generated; commit it, don't edit it)
analysis_options.yaml     ← settings for the code checker in your editor
.vscode/                  ← recommended VS Code extensions and run buttons
.metadata                 ← Flutter's own bookkeeping; leave it alone
```

You rarely need to touch `android/`, `ios/` or `web/`. You'd edit them for
things like the app icon, the name shown on the phone, or permissions such as
microphone access.

Folders like `build/` and `.dart_tool/` appear after you build or run the app.
They're generated caches, so they're kept out of git and safe to delete.

## Adding a new page from FlutterFlow

1. Create `lib/pages/<page_name>/` and put the exported `<page_name>_widget.dart`
   and `<page_name>_model.dart` files in it.
2. If the page imports something from `/flutter_flow/` that doesn't exist yet,
   copy that file in from the FlutterFlow export. Our `flutter_flow/` files are
   lightweight versions of FlutterFlow's, and the dropdown doesn't support the
   searchable or multi-select options yet.
3. If the page uses a new package, add it with `flutter pub add <package>`.
