"""Generate matching playable charts and original song recordings.

The melody definitions below are the single timing source for both the Dart
catalog and each WAV. Run: python scripts/generate_song_tracks.py
Only Python's standard library is needed. No downloaded audio or soundfonts.
"""

from array import array
from functools import lru_cache
import json
import math
from pathlib import Path
import random
import sys
import wave


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "audio" / "songs"
CATALOG = ROOT / "lib" / "features" / "songs" / "song_catalog.dart"
RATE = 22050
COUNT_IN = 4
TAIL = 4
SCALE = (60, 62, 64, 65, 67, 69, 71, 72)


def phrase(pitches, lengths=None):
    if lengths is None:
        lengths = [1] * len(pitches)
    assert len(pitches) == len(lengths)
    return list(zip(pitches, lengths))


# Familiar melodies, arranged with steady beginner-friendly note onsets.
# Ode's two short cadences are straightened to quarter notes. Oh! Susanna is
# an instrumental verse/chorus excerpt with rhythm simplified to the beat.
ODE = (
    phrase([64, 64, 65, 67, 67, 65, 64, 62, 60, 60, 62, 64])
    + phrase([64, 62, 62], [1, 1, 2])
    + phrase([64, 64, 65, 67, 67, 65, 64, 62, 60, 60, 62, 64])
    + phrase([62, 60, 60], [1, 1, 2])
)
TWINKLE = (
    phrase([60, 60, 67, 67, 69, 69, 67], [1, 1, 1, 1, 1, 1, 2])
    + phrase([65, 65, 64, 64, 62, 62, 60], [1, 1, 1, 1, 1, 1, 2])
    + phrase([67, 67, 65, 65, 64, 64, 62], [1, 1, 1, 1, 1, 1, 2]) * 2
    + phrase([60, 60, 67, 67, 69, 69, 67], [1, 1, 1, 1, 1, 1, 2])
    + phrase([65, 65, 64, 64, 62, 62, 60], [1, 1, 1, 1, 1, 1, 2])
)
SUSANNA = (
    phrase([60, 62, 64, 67, 67, 69, 67, 64, 60, 62, 64, 64, 62, 60, 62])
    + phrase([60, 62, 64, 67, 67, 69, 67, 64, 60, 62, 64, 64, 62, 62, 60])
    + phrase([65, 65, 69, 69, 69, 67, 67, 64], [2, 2, 1, 1, 2, 2, 2, 2])
    + phrase([60, 62, 64, 64, 62, 62, 60], [1, 1, 1, 1, 1, 1, 4])
)
SONGS = [
    dict(id="ode_to_joy", title="Ode to Joy", subtitle="A bright classical anthem",
         composer="Ludwig van Beethoven", bpm=88, melody=ODE * 2),
    dict(id="twinkle_twinkle", title="Twinkle Twinkle", subtitle="A familiar, gentle start",
         composer="Traditional French melody", bpm=84, melody=TWINKLE),
    dict(id="oh_susanna", title="Oh! Susanna", subtitle="A cheerful folk instrumental",
         composer="Stephen Foster", bpm=84, melody=SUSANNA),
]


def seconds(beats, bpm):
    return beats * 60 / bpm


def micros(beats, bpm):
    return round(seconds(beats, bpm) * 1_000_000)


@lru_cache(maxsize=256)
def tone(midi, duration_ms, voice):
    frequency = 440 * 2 ** ((midi - 69) / 12)
    size = round(duration_ms / 1000 * RATE)
    output = array("f")
    for i in range(size):
        t = i / RATE
        phase = 2 * math.pi * frequency * t
        envelope = min(1, t / 0.008) * min(1, (size - i - 1) / (RATE * 0.06))
        if voice == "guide":
            signal = (math.sin(phase) + 0.18 * math.sin(2 * phase)) * math.exp(-2.2 * t)
        elif voice == "chord":
            signal = (math.sin(phase) + 0.12 * math.sin(3 * phase)) * math.exp(-2.8 * t)
        else:
            signal = math.sin(phase) * math.exp(-5 * t)
        output.append(signal * envelope)
    return output


@lru_cache(maxsize=8)
def percussion(kind):
    noise = random.Random(421)
    length = 0.16 if kind == "kick" else 0.06
    output = array("f")
    for i in range(round(RATE * length)):
        t = i / RATE
        if kind == "kick":
            # A low, soft pulse; no sharp transient or external drum recording.
            signal = math.sin(2 * math.pi * (63 * t + 2 * (1 - math.exp(-25 * t))))
            signal *= math.exp(-28 * t) * min(1, t / 0.004)
        elif kind == "count":
            signal = math.sin(2 * math.pi * 1100 * t) * math.exp(-90 * t)
        else:
            signal = noise.uniform(-1, 1) * math.exp(-100 * t)
        output.append(signal)
    return output


def add(buffer, sample, start, amplitude):
    offset = round(start * RATE)
    for i in range(min(len(sample), len(buffer) - offset)):
        buffer[offset + i] += sample[i] * amplitude


def build(song):
    bpm = song["bpm"]
    melody_beats = sum(length for _, length in song["melody"])
    total_beats = COUNT_IN + melody_beats + TAIL
    duration_us = micros(total_beats, bpm)
    frames = round(duration_us / 1_000_000 * RATE)
    buffer = array("f", [0]) * frames
    notes = []
    cursor = COUNT_IN
    for note_id, (midi, beats) in enumerate(song["melody"]):
        assert midi in SCALE
        notes.append(dict(id=note_id, midi=midi, lane=SCALE.index(midi) % 4,
                          at=micros(cursor, bpm), duration=micros(beats, bpm)))
        add(buffer, tone(midi, round(seconds(beats, bpm) * 900), "guide"),
            seconds(cursor, bpm), 0.24)
        cursor += beats
    for beat in range(COUNT_IN):
        add(buffer, percussion("count"), seconds(beat, bpm), 0.18 if beat == 0 else 0.12)
    chords = ((48, 52, 55), (53, 57, 60), (55, 59, 62))
    # Select a consonant chord for each bar from the actual melody pitches.
    for bar in range(0, math.ceil(melody_beats / 4)):
        start_beat = COUNT_IN + bar * 4
        bar_start = micros(start_beat, bpm)
        bar_end = micros(start_beat + 4, bpm)
        pitches = [n["midi"] % 12 for n in notes if bar_start <= n["at"] < bar_end]
        chord = max(chords, key=lambda c: sum(p in [n % 12 for n in c] for p in pitches))
        for chord_note in chord:
            for shift in (0, 2):
                add(buffer, tone(chord_note, round(seconds(2, bpm) * 900), "chord"),
                    seconds(start_beat + shift, bpm), 0.075)
        add(buffer, tone(chord[0] - 12, round(seconds(2, bpm) * 950), "bass"),
            seconds(start_beat, bpm), 0.15)
    for beat in range(COUNT_IN, COUNT_IN + melody_beats):
        add(buffer, percussion("kick"), seconds(beat, bpm), 0.09 if beat % 2 == 0 else 0.05)
        add(buffer, percussion("hat"), seconds(beat + 0.5, bpm), 0.035)
    # A tonic chord closes the song, followed by space for the score screen.
    for midi in (48, 52, 55, 60):
        add(buffer, tone(midi, round(seconds(TAIL, bpm) * 900), "chord"),
            seconds(COUNT_IN + melody_beats, bpm), 0.07)
    peak = max(abs(sample) for sample in buffer)
    assert peak < 0.95, peak
    # Keep PCM conversion bounded to a contiguous buffer. Building a bytes
    # object for each frame otherwise dominates memory for these longer tracks.
    pcm = array("h", (round(sample * 32767) for sample in buffer))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(OUTPUT / f"{song['id']}.wav"), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    return dict(**{k: v for k, v in song.items() if k != "melody"},
                duration_us=duration_us, sample_rate=RATE, frames=frames, notes=notes)


def dart_string(value):
    return json.dumps(value, ensure_ascii=True).replace("$", r"\$")


def write_catalog(tracks):
    lines = ["// Generated by scripts/generate_song_tracks.py. Do not edit chart timings.",
             "import 'song.dart';", "", "const demoSongs = <SongDefinition>["]
    for song in tracks:
        lines.append("  SongDefinition(")
        for field in ("id", "title", "subtitle", "composer"):
            lines.append(f"    {field}: {dart_string(song[field])},")
        lines.extend([f"    bpm: {song['bpm']},", f"    countInBeats: {COUNT_IN},",
                      f"    duration: Duration(microseconds: {song['duration_us']}),",
                      f"    backingAsset: 'audio/songs/{song['id']}.wav',",
                      "    notes: ["])
        for n in song["notes"]:
            lines.extend(["      SongNote(", f"        id: {n['id']},",
                          f"        midiNote: {n['midi']},", f"        lane: {n['lane']},",
                          f"        at: Duration(microseconds: {n['at']}),",
                          f"        duration: Duration(microseconds: {n['duration']}),", "      ),"])
        lines.extend(["    ],", "  ),"])
    lines.extend(["];", ""])
    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    CATALOG.write_text("\n".join(lines), encoding="utf-8")


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    tracks = [build(song) for song in SONGS]
    write_catalog(tracks)
    (OUTPUT / "manifest.json").write_text(json.dumps(tracks, indent=2) + "\n", encoding="utf-8")
    for track in tracks:
        print(f"{track['title']}: {len(track['notes'])} notes, {track['duration_us'] / 1e6:.2f}s")


if __name__ == "__main__":
    main()
