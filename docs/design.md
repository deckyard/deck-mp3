<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Design

## Scope

The deck reads and edits MP3 metadata and builds M3U playlists, in pure
Jennifer:

- ID3v2.2, 2.3 and 2.4 tags, with unsynchronisation, compressed frames, all
  four text encodings and embedded artwork;
- ID3v1 and ID3v1.1 trailers, with the 192-entry genre table;
- MPEG audio frame headers and the Xing, Info and VBRI stream headers, for
  duration and bitrate;
- M3U and M3U8 playlists.

It is a binary file-format library: no network, no subprocess, no
capabilities. Only `open`, `save`, `writeFile`, `openPlaylist` and
`savePlaylist` touch the disk, through `fs`; everything else works on
`bytes` and strings.

Out of scope:

- **Decoding or encoding audio.** The deck reads frame headers to measure
  the stream, never the samples.
- **Other tag blocks.** APE, Lyrics3 and `TAG+` blocks are not recognised;
  they count as audio and are kept as they are.
- **Writing every ID3v2 feature.** The writer never unsynchronises,
  compresses, encrypts or groups frames (see Decisions).

## Decisions

- **One version-independent `Tag`.** `Tag` is a single struct for ID3v2.2,
  2.3, 2.4 and ID3v1, read and written; the frame ids are mapped across the
  versions. The raw ID3v2 frames stay reachable on `Track` (`readId3v2`,
  `frameText`) for anything `Tag` does not model. Reading merges the ID3v2
  and ID3v1 tags with `mergeTags`, ID3v2 first.
- **Readers are lenient about damage, writers are strict.** Real files are
  often slightly broken, and a tag editor that refuses them is of little use.
  Damage a reader can work around is not an error: a truncated tag yields
  the frames before the damage, an encoding byte outside 0-3 reads as
  ISO-8859-1, an encrypted frame is dropped, a grouped frame loses its group
  byte, and a compressed frame that fails the checks is kept compressed.
  Synchsafe integers mask the high bit instead of rejecting it, because real
  files set it, and an ID3v2.4 frame size written as a plain integer is
  detected. `decodeText` itself stays strict, and everything the deck writes
  is checked: an out-of-range major version, a negative padding or a value
  that does not fit its field is an error.
- **The writer writes plain tags.** It never unsynchronises, compresses,
  encrypts or groups, and frame flags are not carried over. Modern players do
  not need any of it, and each feature would be a writer path to get wrong.
  `unsynchronise` exists to test `deunsynchronise`.
- **Narrowest text encoding.** Text is written as ISO-8859-1 when it fits,
  else UTF-8 on ID3v2.4 and UTF-16 with a BOM on 2.2 and 2.3, which have no
  UTF-8.
- **Year by version.** The year goes to `TDRC` on ID3v2.4 (the full `date`
  when set) and to `TYER` on earlier versions.
- **Saving keeps the file's shape.** `defaultOptions()` writes ID3v2.4 with
  `DEFAULT_PADDING` (1024) bytes of padding and no ID3v1. `save` instead
  keeps the original ID3v2 major version and ID3v1 presence of the track it
  was given.
- **`Track` holds no audio bytes.** It holds the tag, the audio summary, the
  raw tags and the path. `save` re-reads the audio from `track.path`, so a
  `Track` from `parse` (no path) cannot be saved; `write` takes the bytes
  explicitly.
- **Atomic writes.** `writeFile` streams into a temporary file beside the
  target and renames it over the target. Beside the target because a rename
  cannot cross filesystems; the temporary name carries a random v4 UUID so
  nobody can pre-create it as a symlink. A symlinked target therefore becomes
  a regular file. A failed write removes the temporary file.
- **Duration without a full scan when possible.** A Xing or VBRI header
  gives the exact frame count. Without one and without a scan, the duration
  is estimated from the first frame's bitrate and `exact` is false; a full
  scan walks the frame chain with a table-driven frame-size lookup. CBR keeps
  the declared bitrate; only VBR gets an average.
- **Value semantics.** `withTag`, `mergeTags`, `addEntry` and the other
  changing functions return fresh values; the calling shape is
  `$x = something($x, ...)`.
- **Topics layout.** `src/mp3.j` is the module boundary and `include`s the
  topic files (core, genres, text, mpeg, audio, id3v1, id3v2, tag, file,
  m3u). Type declarations need their dependencies included first; functions
  resolve late.

## Errors

The deck throws `Error{kind: "mp3"}` (`ERROR_KIND`) for malformed input it
cannot work around and for invalid arguments to the writers. The message
names the frame, offset or field involved. The byte readers check bounds
first, so a short buffer is an `mp3` error naming the offset rather than an
interpreter index error.

File-system failures come from `fs` with the interpreter's own kind and are
passed on unchanged. The deck has no server, so it has no error struct.

## Security and limits

The deck assumes a file may be crafted:

- A compressed frame is expanded only when it states a decompressed length
  of at most 16 MiB, and the result is checked against that bound again, so
  a crafted frame cannot dictate a huge allocation. Otherwise the body is
  kept compressed.
- Every byte read is bounds-checked; sizes are validated against what is
  left of the tag before a frame is cut out.
- A leading number in a text field (track, disc, genre reference) saturates
  at a fixed maximum rather than overflowing.
- Whole files are read into memory with `fs.readBytes`; the deck sets no
  cap on file size, so a caller handling untrusted uploads bounds the size
  first.
- The temporary file of an atomic write has an unguessable name.

## Testing and validation

- Every topic has an overlay. Fixtures are built in memory (silent MPEG
  frames and streams of a chosen length), so there is no `testdata/`, and the
  overlays run from a bare copy of `src/`. Disk round trips use
  `fs.makeTempDir`.
- `tools/fuzz.j`, run by `tools/check-extra.sh`, throws truncated, bent,
  spliced and random inputs at every reader with a fixed seed and checks
  that nothing raises, that `strip` is idempotent and that rewriting at
  ID3v2.2, 2.3 and 2.4 preserves tag and audio byte for byte. It found two
  bugs (a corrupt encoding byte costing the whole read, an overflowing
  leading integer), both now regression tests.
- `tools/check-extra.sh` also checks that `src/` holds no stray files and
  that every export is covered.
- `tools/doc-claims.j` checks that every number and listing the guides show
  matches what the deck computes.
- The examples synthesise their own MP3s and run in the gate.

Not covered: files from real encoders and taggers are not part of the test
suite; the formats are tested against the specifications and the deck's own
writer.

## Known limitations and open questions

- `write` and `save` regenerate the ID3v2 tag from `Tag`, so frames `Tag`
  does not model are discarded. To keep them, render the frames from
  `readId3v2` with `renderId3v2`.
- ID3v1 is lossy: fields are cut to 30 bytes and a track number outside
  1-255 is dropped.
- APE, Lyrics3 and `TAG+` blocks are treated as audio.

## Dependencies on the interpreter

- Floor `>=0.28.0` for `jennifer` and `jennifer-tiny`: the `binary` integer
  writers (`binary.fromUint`, M29.54) arrived in 0.28.0, the UTF-8 codecs of
  `encoding.encode` / `decode` and `strings.replicate` in 0.27.0. The deck
  stays runnable on `jennifer-tiny`.
- The `binary` library's integer readers (`binary.readUint` and friends),
  first shipped in 0.26.0.
- `compress` (zlib for compressed frames), `encoding` (the text encodings),
  `uuid` (temporary names) and `fs`.
