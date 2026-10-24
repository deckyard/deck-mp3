<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# @deckyard/mp3

Reads and writes MP3 metadata and M3U playlists. An MP3 file is a stream of
MPEG audio frames with an optional ID3v2 tag in front and an optional ID3v1
tag in the last 128 bytes; the deck handles all three parts.

This deck is part of [Deckyard](https://github.com/deckyard), community decks for [Jennifer](https://jennifer-lang.dev/).

```jennifer
use io;
import "@deckyard/mp3/" as mp3;

def track as mp3.Track init mp3.open("song.mp3");
io.printf("%s\n", mp3.describe($track));

def tag as mp3.Tag init $track.tag;
$tag.genre = "Ambient";
mp3.save(mp3.withTag($track, $tag), "song.mp3");
```

The trailing slash in the import resolves to the entry module.

## Value semantics

Every function that changes a tag, a track or a playlist returns a fresh
value and leaves its argument unchanged, so the calling shape is
`$x = something($x, ...)`. A failed multi-step edit cannot leave a
half-written tag behind.

## Errors

Every error the deck raises is an `Error` with `kind` `"mp3"`
(`ERROR_KIND`). Filesystem errors from `open`, `save`, `writeFile`,
`openPlaylist` and `savePlaylist` (missing file, no permission) come from
`fs` unchanged, with its kind (`"runtime"`), not `"mp3"`.

```jennifer
try {
    mp3.save(mp3.withTag($track, $tag), $target);
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
```

The deck throws for:

- an ID3v2 version other than 2, 3 or 4, or negative padding, passed to a
  writer,
- a frame identifier that is not legal in the version being written (a
  four-character id in ID3v2.2, or one ID3v2.2 has no name for),
- a frame or a whole tag too long for its size field,
- no legal frame header at the offset given to `parseFrameHeader`,
- a text encoding outside 0-3 passed to `decodeText` or `encodeText`, and
  text ISO-8859-1 cannot spell passed to `encodeText` with `TEXT_LATIN1`,
- `save` on a track parsed from a buffer, which has no source file.

The readers (`parse`, `open`, `readId3v2`, `readId3v1`, `readAudio`,
`parsePlaylist`) do not throw on file content: bytes that are not an MP3 give
a `Track` with nothing present, a truncated tag yields the frames before the
damage, and text that does not decode in its declared encoding falls back to
ISO-8859-1. See [ID3v2](guide/id3v2.md#what-the-reader-tolerates) for the
full list.

## Contents

| Page | Covers |
|---|---|
| [Tags](guide/tags.md) | the unified `Tag`: fields, editing, pictures, genres, merging |
| [ID3v2](guide/id3v2.md) | the frame container, raw frames, the three versions |
| [ID3v1 and genres](guide/id3v1.md) | the 128-byte trailer, the genre table |
| [The audio stream](guide/audio.md) | frame headers, duration, VBR headers |
| [Reading and writing files](guide/files.md) | `open`, `write`, `save`, `strip` |
| [Playlists](guide/playlists.md) | M3U and M3U8 |
| [The ID3 formats on disk](reference/id3.md) | every byte offset |
| [The MPEG frame header](reference/mpeg.md) | header bits and tables |
| [Cheatsheet](reference/cheatsheet.md) | every export |

Runnable programs:
[`examples/`](https://github.com/deckyard/deck-mp3/tree/main/examples).
