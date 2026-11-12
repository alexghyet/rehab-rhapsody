# Run the connected music demo

The app now includes Bluetooth reception, motion decoding, a live tilt chart,
musical gesture mapping, and bundled sound playback. Songs is the default mode:
follow a scrolling note highway with music, a count-in, and score/combo feedback.
Set the target height to suit the user's movement range, then hold the baton
inside the thin target zone to hit notes automatically. The Play note button
lets you try the music before connecting a baton. No cloud account,
server API, or API key is needed.

## Find controls on the iPhone layout

The play workspace fits inside the safe screen area without scrolling. Songs
keeps the title, score, feedback, note highway, target meter, Play note button,
and playback controls visible. Free play, Guided, and Rhythm show the current
note, live chart, eight pads, timer, and session controls together.

- Tap the current song title to choose a different song.
- **Choose play mode** opens Songs, Free play, Guided, and Rhythm.
- **Adjust target** opens Target height and Use current position.
- **Baton settings** in the toolbar opens the connection page.
- **Settings** opens buttons for Mode of play, Instrument, Target height,
  Volume, Tempo, Your baton, Arm motion, and How to play. Each opens its own
  screen rather than a long scrolling settings list.

Opening any panel pauses playback. Close returns to the play screen; Back
returns to the settings menu. Press Play to continue. The baton stays connected, so target setup can still
use live position readings. Playback icons have tooltips and accessible names
such as **Start song**, **Pause song**, **Resume song**, **Restart**,
**Start session**, and **Reset timer**.

## Try the music on Windows

From the repository root:

```sh
flutter pub get --enforce-lockfile
flutter run -d chrome
```

Use desktop Chrome or Edge on localhost for Web Bluetooth. Safari on iPhone
cannot run this Web Bluetooth connection path; use the native iOS build below.
[Universal BLE platform setup](https://pub.dev/packages/universal_ble/versions/3.2.0).

1. Tap the song title, choose **Ode to Joy**, **Twinkle Twinkle**, or
   **Oh! Susanna**, then press the play icon (**Start song**). Sound prepares
   once, then a four-beat count-in begins.
2. Without a baton, tap **Play note** when a colored note reaches the bright
   line. Every color uses this same button, and the app picks the target pitch
   automatically. Manual taps within 280 ms on either side of the note count,
   with a Perfect judgment within 110 ms. With a baton, staying inside the
   target zone plays each due note automatically. Missed notes leave the
   backing music playing so you can rejoin the melody.
3. **Pause song** freezes music and scoring; **Resume song** continues there.
   **Restart** stops and resets the song. The end screen keeps your result.
4. Open **Choose play mode** and select Free play, Guided, or Rhythm to use the
   note pads. In **Settings > Instrument**, select Piano, Strings, Flute, or
   Drums. All four play original synthesized
   samples; they are demo timbres rather than recordings of acoustic instruments.
   Drums are pitched/tuned percussion. The range is C4–C5 in C major.
5. **Settings > Volume** controls both backing music and played notes. Each
   song has a fixed tempo to preserve chart alignment; **Settings > Tempo**
   remains adjustable in Rhythm.

If the browser initially blocks sound, tap a note pad again. Confirm the tab
and computer are not muted and the desired speakers/headphones are selected.
Audio errors appear on the **Your baton** page. Sounds are bundled, not streamed from
the internet. The native playback loop works offline. For a self-contained
browser release, including a local rendering engine, use:

```sh
flutter build web --no-web-resources-cdn
python -m http.server 7357 --bind 127.0.0.1 --directory build/web
```

Then open `http://127.0.0.1:7357` in desktop Chrome. Development launches may
still need internet for the initial renderer load.

## Connect the physical baton

1. Keep the existing [ble_motion sketch](../firmware/ble_motion/ble_motion.ino)
   uploaded and the XIAO powered by USB. No new firmware upload is needed for
   this app revision.
2. Disconnect the board in LightBlue. The firmware accepts one central device
   at a time; merely closing the notification screen may leave it connected.
3. Open **Baton settings** in the toolbar, then tap **Connect baton**.
   On desktop Chrome, choose **Rehab Rhapsody**
   in the browser's chooser. On native iOS, allow Bluetooth and keep the intended
   baton nearby: the demo chooses the first peripheral advertising our service.
4. The connection page shows the linked baton and a readings-per-second count
   after validated samples arrive. A connection alone does not make sample data
   appear live. Close the page to return to play.
5. Open **Adjust target**, set **Target height** to a comfortable level, or hold
   the baton at the desired angle and tap **Use current position**. Watch the
   live gauge to move inside its thin band, then close the page. The meter
   beside the notes and the motion chart use this same target.
6. Tap **Start song** and stay in the target zone. Each note is hit automatically
   when it reaches the line, with the correct pitch. You can hold still in the
   zone across successive notes. Leaving it stops automatic hits; returning
   within 280 ms after a note reaches the line can still catch that note. In
   Free play, tilt about the board's X gravity axis to choose pitch, then rotate
   to play. The pads remain available.
7. Unplug the baton during a note. Connection loss or two seconds without fresh
   accepted readings should pause and stop playback. Reconnect explicitly and
   press Play again. Background/restore similarly leaves the session paused.

If Connect reports unavailable/denied Bluetooth, turn Bluetooth on and allow
access for the app/browser. If discovery fails, confirm firmware power and
disconnect any phone/other tab that already holds the board. Connect can be
cancelled; cancelling a chooser or leaving the app cannot activate a late
connection. This demo uses the project service UUID and no pairing PIN.

## What the modes do

| Mode | Demo behavior |
| --- | --- |
| Songs | Hold the baton inside the adjustable thin target zone. Each note automatically plays its target pitch when it reaches the line. Play note also accepts timed taps. Four colors visualize the melody. Count-in, score, combo and results are included. |
| Free play | Tilt chooses pitch. Rotation above the onset threshold triggers a short note; continued motion retriggers at most every 350 ms. |
| Guided | Follow the displayed target through a 14-note melody. A matching tilt/gesture or note pad advances the melody after audio accepts playback. Other pitches do not advance it. |
| Rhythm | While the baton is moving, play its current pitch once per beat. Tempo controls this beat; resting remains silent. Note pads play immediately. |

The 32 instrument samples are prepared before playback. Each hit reuses its
loaded player, avoiding a source reload on every note. Foreground voices are
monophonic and allowed their full 600 ms envelope, even after the baton comes
to rest. A newer hit or pause still stops the previous voice immediately.
The current-note label follows the accepted audio command,
not raw motion. It is app playback feedback, not microphone proof of audible
sound. Pause/reset, settings changes, stream loss, backgrounding, native audio
interruptions, and disposal invalidate pending voices. Interruptions never
automatically resume the session.
Rhythm and automatic song hits ignore movement samples older than 250 ms, even
before the two-second connection watchdog expires. Song target detection also
requires the latest acceleration magnitude to stay within the gravity-estimation
band of 0.5–1.5 g. An impact or invalid reading cannot reuse a previous in-zone
position. Resuming or reconnecting requires fresh position readings.

Song progress follows the backing player's real position, interpolating at most
350 ms between updates. If audio stops advancing for two seconds the song
pauses instead of letting the chart run ahead. Backgrounding, disconnection,
and audio interruptions pause both backing music and foreground notes.

Target height refers to filtered baton angle on the gauge. Its center starts at
65% and can move between 5% and 95%, while the band stays a narrow 10% wide.
That width corresponds to about 12 degrees in the demo's ±60-degree tilt mapping.
Use current position places the band around the current valid angle within that
adjustment range. The song gauge and motion chart share these limits. Target
settings remain in memory across song changes and resets.

Songs scores a due note once while the baton is inside the band. It requires
neither a minimum rotation speed nor a separate gesture between notes. The
timing path waits until the note reaches the line and allows 280 ms of late
entry; it cannot play future notes early or replay a queue of missed notes.
Free play and Guided retain gyro-speed hysteresis of 25 degrees/s onset and
12 degrees/s release. These are demo musical controls; patient-specific
calibration remains future work.

## Run on an iPhone

Use a Mac with Flutter, Xcode, and a physical iPhone. Follow the signing and
device setup in the [development guide](development.md#iphone).
The BLE dependency requires an iOS 18 SDK/Xcode 16 or newer to compile its source;
the app's runtime deployment target remains iOS 15. See its
[Darwin source](https://github.com/Navideck/universal_ble/tree/main/darwin).
Flutter itself may require a newer Xcode for the installed SDK version.

```sh
flutter pub get --enforce-lockfile
flutter devices
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with the physical iPhone ID. The project includes the
Bluetooth permission description. Its plugins support Swift Package Manager;
let Flutter/Xcode resolve generated native dependencies on the Mac. Bluetooth
and native audio need a physical-device check; an iPhone-sized browser viewport
does not validate either one.

## Validation and remaining work

- The real five-packet LightBlue capture is a decoder regression fixture.
- The Flutter tests cover decoding/wrap, mapping, BLE connection/cancellation,
  audio load/stop races, session lifecycle, and existing phone/accessibility UI.
- Flutter static analysis and the browser release build pass on Windows.
- The four modes and every settings page fit 320×568, 375×667, 393×852,
  and 430×932 layouts at normal and 200% text without scrolling. Tests check
  safe-area bounds and 44-point touch controls, following Apple's
  [button guidance](https://developer.apple.com/design/human-interface-guidelines/buttons)
  and [accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility).
- Automated tests cover song judgment, audio-clock synchronization, cancellation,
  cached samples, target adjustment, held-zone hits, stale position rejection,
  song selection, completion and phone layouts. Browser checks exercise
  actual audio playback for all four instruments, song backing tracks, timed
  automatic-pitch hits, score/combo, song completion, pause/resume and reset.
  Desktop and 320×568 cases pass. A separately labelled simulated Web Bluetooth peripheral
  exercises the browser adapter through connect, live motion, sound, release,
  disconnect and reconnect. Song checks hold a simulated baton in the target
  zone across note onsets and check that link loss stops both audio layers.
  This simulation does not validate the physical radio.
- Actual app-to-baton pairing/subscription, sound latency/quality, permission
  denial, range loss, and iPhone interruptions remain device acceptance checks.
- The original firmware capture delivered about 16.7 samples/s, below its 50 Hz
  send-loop target. The app accepts that cadence. It does not promise a 50 Hz
  radio stream or a measured end-to-end latency.
- Session history, patient-specific calibration, chords, and therapist/cloud
  features are outside this demo. Session data/settings remain in memory.

Demo audio is original and can be regenerated with
[scripts/generate_demo_audio.py](../scripts/generate_demo_audio.py). The
[audio README](../assets/audio/README.md) describes the synthesis and asset use.
The three existing melodies use our own instrumental recordings; see
[song credits and sources](../assets/audio/songs/README.md). Their charts and
recordings are generated together by
[generate_song_tracks.py](../scripts/generate_song_tracks.py).

To repeat browser checks with installed desktop Chrome, follow the
[script guide](../scripts/README.md). Reports and screenshots are written under
ignored `build/demo-smoke/`.
