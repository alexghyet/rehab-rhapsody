# Original demo sounds

The WAV files under `demo/` are original, generated demo assets produced by
`scripts/generate_demo_audio.py` using additive synthesis and deterministic noise.
They contain no sampled recordings or external soundfonts. They may be used,
modified, regenerated, and distributed with Rehab Rhapsody without attribution
or royalties.

The four timbres approximate piano, bowed strings, flute, and tuned drums; they
are demonstration sounds rather than recordings of acoustic instruments. The
drums are tuned tom-like sounds with a pitched fundamental, so their displayed
MIDI note remains meaningful.

Each instrument includes C-major notes from C4 through C5 (MIDI 60, 62, 64, 65,
67, 69, 71, 72). Files are 0.6 seconds of mono, 16-bit PCM at 44.1 kHz with
attack/release fades and peak amplitude limited to 72% of full scale. The app
may stop a sample earlier when the gesture/session ends. Regeneration uses only
Python's standard library:

```sh
python scripts/generate_demo_audio.py
```

Playback uses `audioplayers` and `audio_session`. A completed play command means
that the native/web player accepted the prepared sound; it does not verify
audible speaker output. Browser autoplay policy may require a tap on Play or
the sound-test control before sensor-driven playback. Native audio interruption
or headphone disconnection stops playback and emits an interruption event;
the coordinator must leave the session paused until the user presses Play.

The adapter does not guarantee instrument-grade latency. Measure gesture-to-
sound latency on the target iPhone before describing the demo as low latency.
