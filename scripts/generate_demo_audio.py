"""Generate original demo instrument samples using only Python's standard library.

Run from the repository root: python scripts/generate_demo_audio.py
No recordings, soundfonts, external samples, or third-party synthesis code are used.
"""

from array import array
import math
from pathlib import Path
import random
import sys
import wave


SAMPLE_RATE = 44100
DURATION_SECONDS = 0.6
NOTES = (60, 62, 64, 65, 67, 69, 71, 72)
INSTRUMENTS = ("piano", "strings", "flute", "drums")
OUTPUT_DIRECTORY = Path(__file__).resolve().parents[1] / "assets" / "audio" / "demo"


def synthesize(instrument: str, midi_note: int) -> list[float]:
    frequency = 440 * 2 ** ((midi_note - 69) / 12)
    noise = random.Random(1937 + midi_note)
    samples = []
    count = round(SAMPLE_RATE * DURATION_SECONDS)
    for index in range(count):
        time = index / SAMPLE_RATE
        phase = 2 * math.pi * frequency * time
        end_fade = min(1.0, (count - 1 - index) / (SAMPLE_RATE * 0.04))
        if instrument == "piano":
            attack = min(1.0, time / 0.004)
            signal = sum(
                amplitude * math.sin(phase * harmonic) * math.exp(-decay * time)
                for harmonic, amplitude, decay in (
                    (1, 1.0, 4.2),
                    (2, 0.32, 7.0),
                    (3, 0.13, 10.0),
                    (4, 0.06, 13.0),
                )
            )
            signal *= attack
        elif instrument == "strings":
            envelope = min(1.0, time / 0.045) * math.exp(-1.7 * time)
            vibrato_phase = phase + 0.14 * math.sin(2 * math.pi * 5.1 * time)
            signal = envelope * sum(
                math.sin(vibrato_phase * harmonic) / harmonic**1.65
                for harmonic in range(1, 7)
            )
        elif instrument == "flute":
            envelope = min(1.0, time / 0.025) * math.exp(-1.2 * time)
            signal = envelope * (
                math.sin(phase + 0.045 * math.sin(2 * math.pi * 5 * time))
                + 0.09 * math.sin(2 * phase)
                + 0.012 * noise.uniform(-1, 1)
            )
        elif instrument == "drums":
            # A tuned tom-like sound. The dominant decaying sinusoid keeps the
            # displayed note meaningful, unlike an unpitched snare/kick label.
            envelope = min(1.0, time / 0.0025)
            signal = envelope * (
                math.sin(phase) * math.exp(-8.5 * time)
                + 0.25 * math.sin(1.59 * phase) * math.exp(-17 * time)
                + 0.09 * noise.uniform(-1, 1) * math.exp(-70 * time)
            )
        else:
            raise ValueError(instrument)
        samples.append(signal * max(0.0, end_fade))
    peak = max(abs(sample) for sample in samples)
    return [sample * 0.72 / peak for sample in samples]


def main() -> None:
    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    for instrument in INSTRUMENTS:
        for midi_note in NOTES:
            samples = synthesize(instrument, midi_note)
            # Pack directly into a contiguous buffer, without one temporary
            # bytes object per sample. WAV PCM is always little-endian.
            pcm = array("h", (round(sample * 32767) for sample in samples))
            if sys.byteorder != "little":
                pcm.byteswap()
            path = OUTPUT_DIRECTORY / f"{instrument}_{midi_note}.wav"
            with wave.open(str(path), "wb") as output:
                output.setnchannels(1)
                output.setsampwidth(2)
                output.setframerate(SAMPLE_RATE)
                output.writeframes(pcm.tobytes())
    print(f"Generated {len(INSTRUMENTS) * len(NOTES)} original WAV samples in {OUTPUT_DIRECTORY}")


if __name__ == "__main__":
    main()
