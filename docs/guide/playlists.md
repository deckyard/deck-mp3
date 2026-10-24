<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Playlists

A plain M3U is one path per line. The extended form opens with `#EXTM3U`
and puts `#EXT...` lines with a duration and a title before each path.

```jennifer
def pl as mp3.Playlist init mp3.openPlaylist("/music/set.m3u8");

$pl.title;            # the #PLAYLIST name
$pl.extended;         # true when the file has #EXTM3U or any #EXTINF
len($pl.entries);
```

## Entries

| Field | From | Notes |
|---|---|---|
| `path` | the non-`#` line | as written, relative or absolute |
| `title` | `#EXTINF` | everything after the first comma, trimmed |
| `duration` | `#EXTINF` | whole seconds, or `DURATION_UNKNOWN` (-1) |
| `group` | `#EXTGRP` | applies to every following entry until the next `#EXTGRP` |
| `album` | `#EXTALB` | the next entry only |
| `artist` | `#EXTART` | the next entry only |

```jennifer
for (def e in $pl.entries) {
    io.printf("%s  %s\n", mp3.formatDuration($e.duration * 1000), $e.path);
}
mp3.playlistDuration($pl);   # seconds; unknown durations count as nothing
```

## Parsing rules

`parsePlaylist(text)` and `openPlaylist(path)` never throw on content:

- unknown `#` lines are ignored;
- an `#EXTINF` with attributes before the comma (the IPTV form
  `#EXTINF:12 tvg-id="x",Channel`) keeps the leading duration and drops the
  attributes;
- only the first comma separates duration from title, so titles may contain
  commas;
- a fractional duration keeps its whole seconds (`12.5` reads as 12);
- a negative, empty or non-numeric duration becomes `DURATION_UNKNOWN`;
- a leading byte-order mark is dropped, `\r\n` line endings are accepted, and
  blank lines are skipped.

`parsePlaylist` appends with `addEntry`, so parsing is quadratic in the
number of entries (see [Long playlists](#long-playlists)).

## Building one

```jennifer
def pl as mp3.Playlist init mp3.newPlaylist();
$pl.title = "Evening";
$pl = mp3.addEntry($pl, mp3.playlistEntry("one.mp3", "First - one", 61));
$pl = mp3.addEntry($pl, mp3.entryFromTrack(mp3.open("/music/two.mp3")));

io.printf("%s", mp3.buildPlaylist($pl));
```

`entryFromTrack` sets `path` to `track.path` and copies `album` and
`artist` from the tag. The title is `artist - title` when the tag has both,
otherwise whichever one it has, otherwise the file's base name. The duration
is the stream's, rounded to the nearest second, or `DURATION_UNKNOWN` when
the track has no audio.

With `extended` false, `buildPlaylist` writes paths only.

## Long playlists

`addEntry` copies the entry list, so calling it once per track is quadratic:
2000 entries took 8558 ms that way against 14 ms for the form below. Past a
handful of entries, append to a local `list of PlaylistEntry` and assign the
field once:

```jennifer
def entries as list of mp3.PlaylistEntry init [];
for (def name in fs.list($dir)) {
    if (strings.endsWith($name, ".mp3")) {
        $entries[] = mp3.entryFromTrack(mp3.open(path.join($dir, $name)));
    }
}

def pl as mp3.Playlist init mp3.newPlaylist();
$pl.entries = $entries;
```

`addEntries($pl, $batch)` appends a list you already have with one copy.

## Relative paths

Paths in a playlist are normally relative to the playlist's directory.
`resolvePlaylist` joins every relative path onto a directory and cleans the
result; absolute paths, empty paths and `http://`, `https://` and `file://`
URLs (any case) are left as they are.

```jennifer
def pl as mp3.Playlist init mp3.openPlaylist($file);
$pl = mp3.resolvePlaylist($pl, path.dir($file));
```

`resolvePlaylist` does not confine paths. An untrusted playlist can name
`../../etc/passwd` or an absolute path and still does after resolving.
Filter the entries before opening them, for example against a root
directory:

```jennifer
def safe as list of mp3.PlaylistEntry init [];
for (def e in $pl.entries) {
    if (strings.startsWith($e.path, $root + "/")) {
        $safe[] = $e;
    }
}
$pl.entries = $safe;
```

## Encodings

`openPlaylist` decodes the file as UTF-8 when it is valid UTF-8 and as
ISO-8859-1 otherwise, whatever the extension.

`savePlaylist` writes `.m3u8` as UTF-8. Any other extension is written as
ISO-8859-1 when every character fits and as UTF-8 when one does not, so no
character is lost.

## What `buildPlaylist` writes

Three entries, the last in a group, with a playlist name:

```
#EXTM3U
#PLAYLIST:Evening
#EXTINF:61,First - one
one.mp3
#EXTINF:125,Second - two
two.mp3
#EXTGRP:Encore
#EXTINF:90,Third - three
three.mp3
```

`#PLAYLIST` is written only when `title` is set. `#EXTGRP` is written when
the group changes to a non-empty value; `#EXTALB` and `#EXTART` are not
written. Because a group carries forward on reading, an entry with no group
that follows a grouped one reads back in that group. Lines end in `\n`, and
the text ends with one. `tools/doc-claims.j` checks this listing against
`buildPlaylist`.
