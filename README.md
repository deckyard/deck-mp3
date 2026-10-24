# @deckyard/mp3

[![test](https://github.com/deckyard/deck-mp3/actions/workflows/test.yml/badge.svg)](https://github.com/deckyard/deck-mp3/actions/workflows/test.yml)
[![Documentation](https://img.shields.io/badge/docs-github%20pages-blue)](https://deckyard.github.io/deck-mp3/)
[![release](https://img.shields.io/github/v/release/deckyard/deck-mp3)](https://github.com/deckyard/deck-mp3/releases/latest)

A [Jennifer](https://jennifer-lang.dev/) deck that reads and writes MP3
metadata and M3U playlists, in pure Jennifer: ID3v2.2, 2.3 and 2.4 tags
(unsynchronisation, compressed frames, all four text encodings, artwork),
ID3v1 and ID3v1.1 with the 192-entry genre table, MPEG frame headers with
Xing, Info and VBRI stream headers, and M3U / M3U8 playlists. One `Tag`
struct covers every tag version, for reading and for writing.

## Install

```sh
jvc add @deckyard/mp3
```

jvc vendors the `src/` subtree to `vendor/deckyard/mp3/`. Without jvc, copy
`src/` (the entry module `mp3.j` and `topics/`) from a checkout or a
`deckyard-mp3-<version>.tar.gz` release archive into that directory.

Requires Jennifer 0.25.0 or newer, and runs on `jennifer-tiny`. No network,
subprocess or database; only `open`, `save`, `writeFile`, `openPlaylist` and
`savePlaylist` touch the disk, through `fs`.

## Example

```jennifer
use io;
import "@deckyard/mp3/" as mp3;

def track as mp3.Track init mp3.open("song.mp3");
io.printf("%s\n", mp3.describe($track));
# Maike Vandervaart - Ich war müde leer nicht mehr da  4:18  160 kbit/s VBR  44100 Hz  stereo

def tag as mp3.Tag init $track.tag;
$tag.genre = "Ambient";
mp3.save(mp3.withTag($track, $tag), "song.mp3");
```

## Documentation

[The book](https://deckyard.github.io/deck-mp3/): guides, the on-disk
formats, and a cheatsheet of every export. Runnable programs are in
[`examples/`](examples/).
Contributors: the gate is `tools/check-all.sh`.

## Licence

LGPL-3.0-only, see [LICENSE](LICENSE). Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.
