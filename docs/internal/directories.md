<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Directories

## The source tree

`src/mp3.j` is the only compilable unit. It `use`s the libraries and
`include`s every file under `src/topics/`, a textual splice, so a topic file
cannot be linted or tested on its own: its calls into sibling topics read as
undefined. Lint `src/mp3.j` and `src/mp3_test.j`.

`src/mp3_test.j` splices `src/topics/*_test.j` the same way, so the tests are
white-box and call unexported helpers directly.

Include order matters only for type declarations: `mpeg.j` precedes
`audio.j` because `AudioInfo` has `MpegVersion` and `Layer` fields, and
`tag.j` precedes `file.j` because `Track` has a `Tag` field. Functions
resolve late.

```
src/mp3.j             the module boundary and every export
src/mp3_test.j        the white-box overlay
src/topics/version.j      generated; VERSION
src/topics/core.j         errors, byte readers, synchsafe integers
src/topics/genres.j       the 192-entry ID3v1 genre table
src/topics/text.j         the four ID3v2 text encodings
src/topics/mpeg.j         the four-byte MPEG frame header
src/topics/audio.j        duration, bitrate, Xing and VBRI
src/topics/id3v1.j        the 128-byte trailer
src/topics/id3v2.j        the container, frames, unsynchronisation
src/topics/tag.j          the version-independent view
src/topics/file.j         whole files, reading and writing
src/topics/m3u.j          M3U and M3U8 playlists
```

Every topic has a `_test.j` beside it except the generated `version.j`,
which opts out with a `# ci-no-overlay` line. The MPEG fixtures the other
overlays build files from (`silentFrame`, `silentStream`, `silentStreamMs`)
are in `src/topics/mpeg_test.j`.

## The rest

```
docs/          the book; docs/SUMMARY.md is the outline
examples/      runnable programs, all run by CI
tools/         the CI helpers; fuzz.j and doc-claims.j are this deck's own
site/          the built book; not committed
```

Value semantics are asserted by `testWithTagLeavesTheOriginalAlone` and
`testMergeTagsFillsGapsWithoutOverwriting`.
