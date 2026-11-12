# Playable songs

These are new instrumental recordings synthesized for Rehab Rhapsody from
historic melodies. No commercial recording, sample pack, soundfont, modern
arrangement, or lyrics is included. The quiet guide melody keeps the song
recognizable when the player misses a target; successful movements add the
selected foreground instrument.

| Track | Melody credit | Tempo | Length |
| --- | --- | --- | --- |
| Ode to Joy | Ludwig van Beethoven, Symphony No. 9 theme | 88 BPM | 49.09 s |
| Twinkle Twinkle | Traditional French melody, also used in Mozart's K.265 | 84 BPM | 40.00 s |
| Oh! Susanna | Stephen Foster | 84 BPM | 44.29 s |

Each track begins with four count-in clicks. These demo arrangements simplify
some rhythms to steady beats, repeat the Ode to Joy theme, and add new quiet
chords, bass, and percussion. All chart notes fit the app's C-major instrument
bank. Colored lanes visualize pitch; timing-only play chooses pitch for the user.

The source compositions are public domain in the United States. Historical
sources and the copyright-term reference checked for this demo:

- [Library of Congress: Beethoven's Symphony No. 9 manuscript](https://www.loc.gov/item/2021668114/)
  documents the 1822–1824 work and the finale's Ode to Joy theme.
- [International Mozarteum Foundation: New Mozart Edition introduction](https://dme.mozarteum.at/DME/objs/pdf/nma_189_-23_-3_eng.pdf)
  records publication of the variations on “Ah, vous dirai-je, Maman” K.265
  in 1785. This demo uses the traditional melody, not Mozart's variations or
  a modern edition's arrangement.
- [Library of Congress: Oh Susanna! (1848)](https://www.loc.gov/item/2023800745/)
  and [University of Pittsburgh's Stephen Foster archive](https://americanmusic.library.pitt.edu/content/oh-susanna)
  document the original song. Only the instrumental melody is used.
- [U.S. Copyright Office: What is Copyright?](https://www.copyright.gov/what-is-copyright/)
  explains expiration of protection for older published works. The historic
  composition and a modern sound recording have separate rights; this project
  generates its own recordings.

Run `python scripts/generate_song_tracks.py` from the repository to regenerate
the mono 22,050 Hz / 16-bit WAVs, `manifest.json`, and
`lib/features/songs/song_catalog.dart` together. The generator's melody events
are the single source of note onsets and durations for audio and gameplay.
Then run Dart formatting on the generated catalog. Audio sample rounding is
at most half a sample (about 23 microseconds); there is no intentional timing
offset between the chart and the guide melody.
