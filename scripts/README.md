# Development scripts

These tools are optional. The app already includes the generated audio and song
charts; running the app only needs the Flutter setup in the [main README](../README.md).
Run the commands below from the repository root.

## Regenerate audio

Use Python 3.10 or newer. Both generators use only the standard library and
deterministic synthesis; they do not download recordings or soundfonts.

```sh
python scripts/generate_demo_audio.py
python scripts/generate_song_tracks.py
dart format lib/features/songs/song_catalog.dart
```

On systems where Python is named `python3` or `py`, use that command instead.

| Script | Outputs |
| --- | --- |
| `generate_demo_audio.py` | 32 instrument samples in `assets/audio/demo/` |
| `generate_song_tracks.py` | Three backing WAVs, `assets/audio/songs/manifest.json`, and `lib/features/songs/song_catalog.dart` |

Edit song melodies and timings in `generate_song_tracks.py`, then regenerate
the WAVs and catalog together. Do not hand-edit the generated catalog or manifest.
Run `flutter test` afterward; the asset and song tests check audio format, sample
levels, and chart/recording agreement. Keep the audio credits and font licenses
with the assets.

## Browser integration checks

Requires installed Google Chrome, Node.js 20 or newer with npm, and Python 3.
Playwright controls the installed Chrome; it does not download another browser.

Build and install the test tool:

```sh
flutter build web
npm install --prefix build/demo-smoke --no-save playwright-core@1.65.0
```

Serve the compiled app locally in one terminal:

```sh
python -m http.server 7357 --bind 127.0.0.1 --directory build/web
```

In another terminal, run:

```sh
node scripts/demo_browser_smoke.cjs http://127.0.0.1:7357
```

The check covers desktop and small phone layouts, settings, playback, song
scoring, and connection/disconnection behavior. Audio playback is real browser
playback; Bluetooth is simulated. It does not validate the physical baton,
iPhone browser support, or native iOS behavior.

Reports and screenshots go to ignored `build/demo-smoke/`. Stop the local server
with **Ctrl+C**. `flutter clean` removes the report and downloaded test dependency;
rerun the npm command when needed. This server is accessible only on this PC.
